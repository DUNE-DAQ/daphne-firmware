proc daphne_export_require_arg {index label} {
    if {[llength $::argv] <= $index} {
        error "ERROR: missing $label argument"
    }
    return [file normalize [lindex $::argv $index]]
}

set script_dir [file dirname [file normalize [info script]]]
set project_path [daphne_export_require_arg 0 "project path"]
set output_dir [daphne_export_require_arg 1 "output directory"]

source -notrace [file join $script_dir "daphne_vivado_flow.tcl"]

array set cfg [daphne_resolve_config $script_dir]
set cfg(output_dir) $output_dir

file mkdir $cfg(output_dir)

puts "INFO: Opening Flow API Vivado project $project_path"
open_project $project_path

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "ERROR: impl_1 is not complete; build the Flow API project before exporting handoff artifacts."
}

open_run impl_1

puts "INFO: Exporting legacy handoff artifacts into $cfg(output_dir)"
puts "INFO: build_name=$cfg(build_name)"

write_bitstream -force -bin_file [file join $cfg(output_dir) "${cfg(build_name)}.bit"]
write_hw_platform -fixed -force -include_bit -file [file join $cfg(output_dir) "${cfg(build_name)}.xsa"]

puts "INFO: Exported [file join $cfg(output_dir) "${cfg(build_name)}.bit"]"
puts "INFO: Exported [file join $cfg(output_dir) "${cfg(build_name)}.bin"]"
puts "INFO: Exported [file join $cfg(output_dir) "${cfg(build_name)}.xsa"]"

close_project
exit
