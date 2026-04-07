proc daphne_export_require_arg {index label} {
    if {[llength $::argv] <= $index} {
        error "ERROR: missing $label argument"
    }
    return [file normalize [lindex $::argv $index]]
}

proc daphne_export_first_existing {candidates} {
    foreach candidate $candidates {
        if {$candidate ne "" && [file exists $candidate]} {
            return [file normalize $candidate]
        }
    }
    return ""
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set project_path [daphne_export_require_arg 0 "project path"]
set output_dir [daphne_export_require_arg 1 "output directory"]

source [file join $script_dir "daphne_board_env.tcl"]

set artifact_profile [daphne_resolve_artifact_profile $repo_root]
set build_name [dict get $artifact_profile build_name]

file mkdir $output_dir

puts "INFO: Opening Flow API Vivado project $project_path"
open_project $project_path

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "ERROR: impl_1 is not complete; build the Flow API project before exporting handoff artifacts."
}

open_run impl_1

set impl_run [get_runs impl_1]
set run_dir [file normalize [get_property DIRECTORY $impl_run]]
set project_root [file dirname $project_path]
set project_name [current_project]
set top_name [get_property top [current_fileset]]

set existing_bit [daphne_export_first_existing [concat \
    [list [file join $project_root "${project_name}.bit"]] \
    [glob -nocomplain -path $run_dir "${top_name}*.bit"]]]
set existing_bin [daphne_export_first_existing [concat \
    [list [file join $project_root "${project_name}.bin"]] \
    [glob -nocomplain -path $run_dir "${top_name}*.bin"]]]

puts "INFO: Exporting Flow API handoff artifacts into $output_dir"
puts "INFO: build_name=$build_name"

if {$existing_bit ne "" && $existing_bin ne ""} {
    puts "INFO: Reusing flow-generated bit/bin artifacts from the native impl run."
    file copy -force $existing_bit [file join $output_dir "${build_name}.bit"]
    file copy -force $existing_bin [file join $output_dir "${build_name}.bin"]
} else {
    puts "INFO: Native impl run did not leave reusable bit/bin artifacts; generating named handoff bit/bin in $output_dir."
    write_bitstream -force -bin_file [file join $output_dir "${build_name}.bit"]
}

write_hw_platform -fixed -force -include_bit -file [file join $output_dir "${build_name}.xsa"]

puts "INFO: Exported [file join $output_dir "${build_name}.bit"]"
puts "INFO: Exported [file join $output_dir "${build_name}.bin"]"
puts "INFO: Exported [file join $output_dir "${build_name}.xsa"]"

close_project
exit
