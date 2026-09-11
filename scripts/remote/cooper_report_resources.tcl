# vivado -mode batch -source cooper_report_resources.tcl -tclargs CHECKPOINT NEW_REPORT_DIR
if {$argc != 2} {
    error "Usage: cooper_report_resources.tcl CHECKPOINT NEW_REPORT_DIR"
}
set checkpoint [file normalize [lindex $argv 0]]
set report_dir [file normalize [lindex $argv 1]]
if {![file isfile $checkpoint]} {
    error "Checkpoint does not exist: $checkpoint"
}
if {[file exists $report_dir]} {
    error "Use a new report directory: $report_dir"
}
file mkdir $report_dir
open_checkpoint $checkpoint
report_utilization -file [file join $report_dir utilization.rpt]
report_utilization -hierarchical -hierarchical_depth 12 -file [file join $report_dir hierarchical_utilization.rpt]
set primitive_file [open [file join $report_dir memory_primitives.tsv] w]
puts $primitive_file "primitive\tcell"
foreach cell [lsort [get_cells -hierarchical -filter {REF_NAME =~ RAMB* || REF_NAME =~ URAM*}]] {
    puts $primitive_file "[get_property REF_NAME $cell]\t$cell"
}
close $primitive_file
set source_file [open [file join $report_dir checkpoint.txt] w]
puts $source_file $checkpoint
puts $source_file [version -short]
close $source_file
close_design
