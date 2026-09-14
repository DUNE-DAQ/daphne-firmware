set_param general.maxThreads 4
set run_root [file dirname [file normalize [info script]]]
foreach variant {native pipeline} {
  create_project -in_memory -part xck26-sfvc784-2LV-c
  set_property target_language VHDL [current_project]
  set_property default_lib work [current_project]
  read_vhdl -vhdl2008 -library work [file join $run_root ${variant}.vhd]
  set clock_file [file join $run_root clock.xdc]
  set f [open $clock_file w]
  puts $f {create_clock -name builder_clock -period 3.200 [get_ports clock_i]}
  close $f
  read_xdc $clock_file
  set generics {}
  if {$variant eq "pipeline"} {set generics [list -generic PIPELINE_INPUT_G=true]}
  synth_design -top fragment_peak_descriptors_banked -part xck26-sfvc784-2LV-c -mode out_of_context -flatten_hierarchy rebuilt -directive PerformanceOptimized {*}$generics
  report_timing_summary -file [file join $run_root ${variant}_timing_summary.rpt]
  report_timing -max_paths 30 -nworst 3 -file [file join $run_root ${variant}_timing_paths.rpt]
  report_utilization -file [file join $run_root ${variant}_util.rpt]
  write_checkpoint [file join $run_root ${variant}_synth.dcp]
  close_project
}
puts "DESCRIPTOR_PIPELINE_OOC_PASS"
