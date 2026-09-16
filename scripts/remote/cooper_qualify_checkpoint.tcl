# Read-only report extraction from an immutable routed checkpoint.
# vivado -mode batch -source cooper_qualify_checkpoint.tcl -tclargs DCP NEW_DIR
if {$argc != 2} { error "Usage: cooper_qualify_checkpoint.tcl DCP NEW_DIR" }
set checkpoint [file normalize [lindex $argv 0]]
set report_dir [file normalize [lindex $argv 1]]
if {![file isfile $checkpoint]} { error "Missing checkpoint: $checkpoint" }
if {[file exists $report_dir]} { error "Report directory already exists: $report_dir" }
file mkdir $report_dir
set provenance [open [file join $report_dir checkpoint.txt] w]
puts $provenance $checkpoint
puts $provenance [version -short]
close $provenance
open_checkpoint $checkpoint
# Fail on unavailable reports: absence is not a successful qualification.
report_timing_summary -report_unconstrained -check_timing_verbose \
    -file [file join $report_dir timing_summary.rpt]
report_bus_skew -file [file join $report_dir bus_skew.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_clock_interaction -file [file join $report_dir clock_interaction.rpt]
report_exceptions -coverage -file [file join $report_dir exception_coverage.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_utilization -hierarchical -hierarchical_depth 12 \
    -file [file join $report_dir hierarchical_utilization.rpt]
close_design
# This marker proves extraction only. Report review decides qualification.
set marker [open [file join $report_dir reports.complete] w]
puts $marker "Reports extracted; engineering review required."
close $marker
