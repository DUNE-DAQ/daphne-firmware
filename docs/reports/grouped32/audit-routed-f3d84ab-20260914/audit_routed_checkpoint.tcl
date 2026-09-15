# Usage: vivado -mode batch -source audit_routed_checkpoint.tcl \
#          -tclargs ROUTED_CHECKPOINT NEW_REPORT_DIRECTORY
# Diagnostic evidence only: reports must be reviewed against the source clocks,
# interfaces and CDC implementations before declaring the firmware qualified.
if {$argc != 2} {
    error "Expected ROUTED_CHECKPOINT NEW_REPORT_DIRECTORY"
}
set checkpoint [file normalize [lindex $argv 0]]
set report_dir [file normalize [lindex $argv 1]]
if {![file isfile $checkpoint]} { error "Checkpoint does not exist: $checkpoint" }
if {[file exists $report_dir]} { error "Use a new report directory: $report_dir" }
file mkdir $report_dir
set_param general.maxThreads 1
# The grouped design has more than 100,000 reported CDC paths on some clock
# pairs. Do not accept a silently truncated routed CDC report.
set_param cdc.reportClockPairsThreshold 1000000
open_checkpoint $checkpoint
set provenance [open [file join $report_dir provenance.txt] w]
puts $provenance "checkpoint=$checkpoint"
puts $provenance "vivado=[version -short]"
puts $provenance "utc=[clock format [clock seconds] -gmt true -format {%Y-%m-%dT%H:%M:%SZ}]"
close $provenance
report_route_status -file [file join $report_dir route_status.rpt]
report_clocks -file [file join $report_dir clocks.rpt]
check_timing -verbose -file [file join $report_dir check_timing.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_exceptions -coverage -file [file join $report_dir exceptions_coverage.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_timing_summary -report_unconstrained -file [file join $report_dir timing_summary.rpt]
report_bus_skew -file [file join $report_dir bus_skew.rpt]
report_drc -file [file join $report_dir drc.rpt]

# Earlier synthesis reports named eight PS8 EMIO peripheral outputs as
# no_clock. Record their routed endpoint fanout so dormant PS pins cannot be
# mistaken for unreviewed fabric clocks, or vice versa.
set ps_emio_file [open [file join $report_dir ps_emio_clock_fanout.tsv] w]
puts $ps_emio_file "pin\tstatus\tendpoint_count\tendpoints"
set ps_prefix "daphne_selftrigger_bd_i/zynq_ultra_ps_e_0/U0/PS8_i"
foreach emio_name {
    EMIOENET0MDIOMDC EMIOENET1MDIOMDC EMIOENET2MDIOMDC EMIOENET3MDIOMDC
    EMIOSDIO0CLKOUT EMIOSDIO1CLKOUT EMIOSPI0SCLKO EMIOSPI1SCLKO
} {
    set pin_name "$ps_prefix/$emio_name"
    set pin [get_pins -quiet $pin_name]
    if {[llength $pin] != 1} {
        puts $ps_emio_file "$pin_name\tmissing_or_ambiguous\t0\t"
        continue
    }
    if {[catch {set endpoints [lsort -unique [all_fanout -flat -endpoints_only -from $pin]]} detail]} {
        puts $ps_emio_file "$pin_name\tquery_error\t0\t$detail"
        continue
    }
    puts $ps_emio_file "$pin_name\tok\t[llength $endpoints]\t[join $endpoints {;}]"
}
close $ps_emio_file

set complete [open [file join $report_dir reports_complete.txt] w]
puts $complete "Reports generated; this is not an automatic timing/CDC qualification result."
close $complete
exit
