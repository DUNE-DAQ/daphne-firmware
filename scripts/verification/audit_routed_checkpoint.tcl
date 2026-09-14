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
set complete [open [file join $report_dir reports_complete.txt] w]
puts $complete "Reports generated; this is not an automatic timing/CDC qualification result."
close $complete
exit
