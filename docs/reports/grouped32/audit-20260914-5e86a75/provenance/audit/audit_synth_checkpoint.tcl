# vivado -mode batch -source audit_synth_checkpoint.tcl \
#   -tclargs SYNTH_CHECKPOINT NEW_REPORT_DIRECTORY
# Generate diagnostic evidence; a complete report set is not timing signoff.
if {$argc != 2} { error "Expected SYNTH_CHECKPOINT NEW_REPORT_DIRECTORY" }
set checkpoint [file normalize [lindex $argv 0]]
set report_dir [file normalize [lindex $argv 1]]
if {![file isfile $checkpoint]} { error "Checkpoint does not exist: $checkpoint" }
if {[file exists $report_dir]} { error "Use a new report directory: $report_dir" }
file mkdir $report_dir
set_param general.maxThreads 8
# Avoid silently truncating large configuration/reset crossings in this design.
set_param cdc.reportClockPairsThreshold 1000000
open_checkpoint $checkpoint
set provenance [open [file join $report_dir provenance.txt] w]
puts $provenance "checkpoint=$checkpoint"
puts $provenance "vivado=[version -short]"
puts $provenance "utc=[clock format [clock seconds] -gmt true -format {%Y-%m-%dT%H:%M:%SZ}]"
close $provenance

set failures {}
foreach {name command} {
    utilization {report_utilization}
    hierarchical_utilization {report_utilization -hierarchical -hierarchical_depth 16}
    clocks {report_clocks}
    check_timing {check_timing -verbose}
    clock_interaction {report_clock_interaction}
    cdc {report_cdc -details}
    exceptions_coverage {report_exceptions -coverage}
    methodology {report_methodology}
    timing_summary {report_timing_summary -report_unconstrained}
    bus_skew {report_bus_skew}
    drc {report_drc}
} {
    if {[catch {{*}$command -file [file join $report_dir ${name}.rpt]} detail]} {
        lappend failures $name
        set error_file [open [file join $report_dir ${name}.error.txt] w]
        puts $error_file $detail
        close $error_file
        puts "WARNING: Diagnostic report $name failed: $detail"
    }
}

set cells_file [open [file join $report_dir hierarchy.tsv] w]
puts $cells_file "cell\tref_name\torig_ref_name"
foreach cell [lsort [get_cells -hierarchical -filter {IS_PRIMITIVE == 0}]] {
    puts $cells_file "$cell\t[get_property REF_NAME $cell]\t[get_property ORIG_REF_NAME $cell]"
}
close $cells_file

set memory_file [open [file join $report_dir memory_clocks.tsv] w]
puts $memory_file "cell\tprimitive\tclock_pin\tclock_net\tclocks"
foreach cell [lsort [get_cells -hierarchical -filter {REF_NAME =~ RAMB* || REF_NAME =~ URAM*}]] {
    foreach pin [get_pins -of_objects $cell -filter {IS_CLOCK == 1}] {
        puts $memory_file "$cell\t[get_property REF_NAME $cell]\t$pin\t[get_nets -quiet -of_objects $pin]\t[get_clocks -quiet -of_objects $pin]"
    }
}
close $memory_file

set complete [open [file join $report_dir report_status.txt] w]
puts $complete "failed_reports=$failures"
puts $complete "Review the reports against source and interface contracts before qualification."
close $complete
if {[llength $failures]} { error "Diagnostic reports failed: $failures" }
puts "DAPHNE_SYNTH_AUDIT_COMPLETE"
close_design
exit
