proc daphne_ooc_get_env_or_default {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default
}

proc daphne_ooc_collect_files {root pattern} {
    set files [glob -nocomplain -directory $root -types f -tails -recursive $pattern]
    set resolved {}
    foreach item $files {
        lappend resolved [file normalize [file join $root $item]]
    }
    return [lsort -dictionary $resolved]
}

set work_root [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $work_root ".."]]
source -notrace [file join $work_root "daphne_board_env.tcl"]
set daphne_board_profile [daphne_resolve_board_profile $repo_root]
set src_root [file join $work_root "src"]
set output_dir [daphne_ooc_get_env_or_default DAPHNE_OUTPUT_DIR "./output-composable-ooc"]
set fpga_part [daphne_ooc_get_env_or_default DAPHNE_FPGA_PART [dict get $daphne_board_profile fpga_part]]
set board_part [daphne_ooc_get_env_or_default DAPHNE_BOARD_PART [dict get $daphne_board_profile board_part]]
set max_threads [daphne_ooc_get_env_or_default DAPHNE_MAX_THREADS "8"]
set public_top_module_default [expr {[dict exists $daphne_board_profile public_top_module] ? [dict get $daphne_board_profile public_top_module] : "daphne_composable_top"}]
set ip_top_module_default [expr {[dict exists $daphne_board_profile ip_top_module] ? [dict get $daphne_board_profile ip_top_module] : $public_top_module_default}]
set top_name [daphne_ooc_get_env_or_default DAPHNE_COMPOSABLE_OOC_TOP [daphne_ooc_get_env_or_default DAPHNE_PUBLIC_TOP_MODULE [daphne_ooc_get_env_or_default DAPHNE_IP_TOP_MODULE $ip_top_module_default]]]

if {![file isdirectory $src_root]} {
    error "ERROR: expected FuseSoC-staged source tree at $src_root"
}

if {[file pathtype $output_dir] ne "absolute"} {
    set output_dir [file normalize [file join $work_root $output_dir]]
}

if {[file exists $output_dir]} {
    file delete -force $output_dir
}
file mkdir $output_dir

create_project -in_memory -part $fpga_part
set_param general.maxThreads $max_threads
set_property BOARD_PART $board_part [current_project]
set_property TARGET_LANGUAGE VHDL [current_project]
set_property DEFAULT_LIB work [current_project]

set vhdl_files [daphne_ooc_collect_files $src_root "*.vhd"]
set verilog_files [daphne_ooc_collect_files $src_root "*.v"]
set systemverilog_files [daphne_ooc_collect_files $src_root "*.sv"]

puts "INFO: Composable OOC synth from FuseSoC-staged sources in $src_root"
puts "INFO: Top=$top_name part=$fpga_part board_part=$board_part"
puts "INFO: Found [llength $vhdl_files] VHDL, [llength $verilog_files] Verilog, [llength $systemverilog_files] SystemVerilog files."

if {[llength $vhdl_files] == 0} {
    error "ERROR: no VHDL sources found under $src_root"
}

foreach file $vhdl_files {
    read_vhdl -vhdl2008 $file
}
foreach file $verilog_files {
    read_verilog $file
}
foreach file $systemverilog_files {
    read_verilog -sv $file
}

synth_design -mode out_of_context -top $top_name -part $fpga_part

report_utilization -file [file join $output_dir "composable_ooc_util.rpt"]
report_timing_summary -file [file join $output_dir "composable_ooc_timing_summary.rpt"]
write_checkpoint -force [file join $output_dir "composable_ooc_synth.dcp"]

puts "INFO: Composable OOC synthesis completed. Outputs in $output_dir"
exit
