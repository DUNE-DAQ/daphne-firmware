# Fast area comparison; this is not a board implementation/timing qualification.
# vivado -mode batch -source cooper_ooc_synth.tcl -tclargs SOURCE NEW_OUTPUT [builder|descriptor|registers|both|all]
if {$argc < 2 || $argc > 3} {
    error "Usage: cooper_ooc_synth.tcl SOURCE_ROOT NEW_OUTPUT_DIRECTORY ?builder|descriptor|registers|both|all?"
}
set source_root [file normalize [lindex $argv 0]]
set output_root [file normalize [lindex $argv 1]]
set selection both
if {$argc == 3} { set selection [lindex $argv 2] }
switch -- $selection {
    builder { set targets {stc3_record_builder} }
    descriptor { set targets {fragment_peak_descriptors} }
    registers { set targets {selftrigger_register_bank} }
    both { set targets {fragment_peak_descriptors stc3_record_builder} }
    all { set targets {fragment_peak_descriptors stc3_record_builder selftrigger_register_bank} }
    default { error "Unknown target selection: $selection" }
}
if {[file exists $output_root]} { error "Use a new output directory: $output_root" }
file mkdir $output_root
set part xck26-sfvc784-2LV-c
set directive PerformanceOptimized
set_param general.maxThreads 2
set packages [list \
    ip_repo/daphne_ip/rtl/daphne_package.vhd \
    rtl/isolated/common/daphne_subsystem_pkg.vhd]
set descriptor rtl/isolated/subsystems/trigger/fragment_peak_descriptors.vhd
set builder_sources [list \
    rtl/isolated/common/primitives/sample_ring_buffer.vhd \
    rtl/isolated/common/primitives/packet_frame_store.vhd \
    rtl/isolated/subsystems/trigger/stc3_record_builder.vhd]
set xpm_root [file join $::env(XILINX_VIVADO) data ip xpm]
set summary [open [file join $output_root run-configuration.txt] w]
puts $summary "source_root=$source_root"
puts $summary "vivado=[version -short]"
puts $summary "part=$part"
puts $summary "synth_directive=$directive"
puts $summary "clock_period_ns=16.000"
puts $summary "selection=$selection"
puts $summary "All top-level inputs and outputs retained; no board-level constant propagation/shared logic."
close $summary

foreach top $targets {
    set target_dir [file join $output_root $top]
    file mkdir $target_dir
    create_project -in_memory -part $part
    set_property target_language VHDL [current_project]
    set_property default_lib work [current_project]
    foreach source $packages {
        read_vhdl -vhdl2008 -library work [file join $source_root $source]
    }
    if {$top eq "selftrigger_register_bank"} {
        read_vhdl -vhdl2008 -library work [file join $source_root rtl/isolated/subsystems/control/selftrigger_register_bank.vhd]
    } else {
        read_vhdl -vhdl2008 -library work [file join $source_root $descriptor]
    }
    if {$top eq "stc3_record_builder"} {
        # Compile the installed vendor models, not the local GHDL substitutes.
        read_vhdl -library xpm [file join $xpm_root xpm_VCOMP.vhd]
        read_verilog -sv -library xpm [file join $xpm_root xpm_cdc hdl xpm_cdc.sv]
        read_verilog -sv -library xpm [file join $xpm_root xpm_memory hdl xpm_memory.sv]
        foreach source $builder_sources {
            read_vhdl -vhdl2008 -library work [file join $source_root $source]
        }
    }
    set clock_file [file join $target_dir clock.xdc]
    set clock_handle [open $clock_file w]
    if {$top eq "selftrigger_register_bank"} {
        puts $clock_handle {set ooc_clock_ports [get_ports -quiet -filter {DIRECTION == IN && (NAME =~ *ACLK* || NAME =~ *aclk*)}]}
        puts $clock_handle {if {[llength $ooc_clock_ports] != 1} {error "Expected one flattened AXI_IN.ACLK port"}}
        puts $clock_handle {create_clock -name sample_clock -period 16.000 $ooc_clock_ports}
    } else {
        puts $clock_handle {create_clock -name sample_clock -period 16.000 [get_ports clock_i]}
    }
    close $clock_handle
    read_xdc $clock_file
    synth_design -top $top -part $part -mode out_of_context \
        -flatten_hierarchy rebuilt -directive $directive
    report_utilization -file [file join $target_dir utilization.rpt]
    report_utilization -hierarchical -hierarchical_depth 8 \
        -file [file join $target_dir hierarchical_utilization.rpt]
    report_timing_summary -file [file join $target_dir timing_summary.rpt]
    report_clocks -file [file join $target_dir clocks.rpt]
    write_checkpoint [file join $target_dir synthesized.dcp]
    close_project
}
puts "DAPHNE_OOC_SYNTH_PASS: $selection"
