proc daphne_export_require_arg {index label} {
    if {[llength $::argv] <= $index} {
        error "ERROR: missing $label argument"
    }
    return [file normalize [lindex $::argv $index]]
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set project_path [daphne_export_require_arg 0 "project path"]
set output_dir [daphne_export_require_arg 1 "output directory"]

source -notrace [file join $script_dir "daphne_board_env.tcl"]

set artifact_profile [daphne_resolve_artifact_profile $repo_root]
set build_name [dict get $artifact_profile build_name]

file mkdir $output_dir

puts "INFO: Opening Flow API Vivado project $project_path"
open_project $project_path

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "ERROR: impl_1 is not complete; build the Flow API project before exporting handoff artifacts."
}

open_run impl_1

puts "INFO: Exporting Flow API handoff artifacts into $output_dir"
puts "INFO: build_name=$build_name"

write_bitstream -force -bin_file [file join $output_dir "${build_name}.bit"]
write_hw_platform -fixed -force -include_bit -file [file join $output_dir "${build_name}.xsa"]

puts "INFO: Exported [file join $output_dir "${build_name}.bit"]"
puts "INFO: Exported [file join $output_dir "${build_name}.bin"]"
puts "INFO: Exported [file join $output_dir "${build_name}.xsa"]"

close_project
exit
