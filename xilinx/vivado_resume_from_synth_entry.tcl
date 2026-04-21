set script_dir [file dirname [file normalize [info script]]]
source -notrace [file join $script_dir "daphne_vivado_flow.tcl"]

array set cfg [daphne_resolve_config $script_dir]
daphne_check_vivado_version cfg

set synth_dcp [file join $cfg(output_dir) "${cfg(bd_name)}_synth.dcp"]
if {![file exists $synth_dcp]} {
    error "ERROR: expected synth checkpoint at $synth_dcp"
}

puts "INFO: Resuming implementation from synth checkpoint $synth_dcp"
puts "INFO: Reusing output directory $cfg(output_dir)"
puts "INFO: Directives opt=$cfg(opt_directive) place=$cfg(place_directive) post_place_physopt=$cfg(post_place_physopt_directive) route=$cfg(route_directive) post_route_physopt=$cfg(post_route_physopt_directive)"

open_checkpoint $synth_dcp
daphne_run_impl cfg
daphne_write_bitstream_and_xsa cfg

puts "INFO: Resume-from-synth implementation completed."
puts "INFO: Generated bit/xsa under $cfg(output_dir)"
puts "INFO: Run the Windows DTBO wrapper separately if you need overlay artifacts."
exit
