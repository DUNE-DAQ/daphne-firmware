# Frontend control CDC constraints Tcl
#
# Keep AXI-originated frontend control/state crossings separate from the
# source-synchronous AFE capture clock family in afe_capture_timing.tcl.
#
# These nets are intentionally not timed as synchronous data paths:
# - idelayctrl_reset crosses into clk500 via explicit two-stage sync in
#   frontend_common
# - idelay_load crosses into clk125 via explicit two-stage sync in
#   frontend_common
# - software and external trigger pulses cross into clock via explicit
#   two-stage synchronizers in frontend_common
# - spy trigger source/inhibit cross as a persistent bundled control word;
#   frontend_common synchronizes each bit and publishes only stable samples
# - idelay_tap/idelay_en_vtc/iserdes_reset/iserdes_bitslip still drive
#   IDELAY/ISERDES control pins or fabric alignment state outside the AXI
#   clock domain

proc daphne_collect_optional_hier_nets {patterns} {
    set matches {}
    foreach pattern $patterns {
        foreach resolved_net [get_nets -hier -quiet -filter "NAME =~ $pattern"] {
            lappend matches $resolved_net
        }
    }
    return [lsort -unique $matches]
}

proc daphne_collect_optional_hier_pins {patterns} {
    set matches {}
    foreach pattern $patterns {
        foreach resolved_pin [get_pins -hier -quiet -filter "NAME =~ $pattern"] {
            lappend matches $resolved_pin
        }
    }
    return [lsort -unique $matches]
}

# Cut only the asynchronous input to each first-stage synchronizer.  Binding
# to the stage-one D pins survives hierarchy/net renaming across Vivado
# versions while preserving timing between the two synchronizer stages.
set frontend_sync_stage1_pins [daphne_collect_optional_hier_pins {
    *frontend_common_inst/idelayctrl_reset_500_meta_reg/D
    *frontend_common_inst/idelay_load_clk125_meta_reg*/D
    *frontend_common_inst/software_trig_meta_reg/D
    *frontend_common_inst/external_trig_meta_reg/D
    *frontend_common_inst/spy_trigger_control_meta_reg*/D
}]

if {[llength $frontend_sync_stage1_pins] > 0} {
    set_false_path -to $frontend_sync_stage1_pins
}

set frontend_async_control_nets [daphne_collect_optional_hier_nets {
    *frontend_island_inst/idelay_tap*
    *frontend_island_inst/idelay_en_vtc
    *frontend_island_inst/iserdes_reset
    *frontend_island_inst/iserdes_bitslip*
}]

if {[llength $frontend_async_control_nets] > 0} {
    set_false_path -through $frontend_async_control_nets
}

# Frame-monitor four-phase handshake: three control stages, two data stages.
set frame_control_first [get_pins -hier -quiet -regexp {.*frame_monitor[./](request_sync_reg|acknowledge_sync_reg)\[0\]/D}]
if {[llength $frame_control_first] > 0} {
    set_false_path -to $frame_control_first
    set frame_data_first [get_pins -hier -quiet -regexp {.*frame_monitor[./]data_meta_reg\[[0-9]+\]/D}]
    if {[llength $frame_control_first] != 2 || [llength $frame_data_first] != 160} {
        error "Incomplete frame-monitor CDC constraints"
    }
    # Bound bundled-data flight to one destination period, ahead of ACK.
    set frame_data_clocks [get_clocks -of_objects [get_pins -of_objects [get_cells -of_objects $frame_data_first] -filter {REF_PIN_NAME == C}]]
    if {[llength $frame_data_clocks] != 1} { error "Ambiguous frame-monitor AXI clock" }
    set_max_delay -datapath_only [get_property PERIOD $frame_data_clocks] -to $frame_data_first
}
