# Frontend control CDC constraints Tcl
#
# Keep AXI-originated frontend control/state crossings separate from the
# source-synchronous AFE capture clock family in afe_capture_timing.tcl.
#
# These paths are intentionally not timed as synchronous data paths:
# - idelayctrl_reset crosses into clk500 via explicit two-stage sync in
#   frontend_common
# - idelay_load crosses into clk125 via explicit two-stage sync in
#   frontend_common
# - trig_axi crosses into clock via explicit two-stage sync in frontend_common
# - idelay_tap/idelay_en_vtc/iserdes_reset/iserdes_bitslip still drive
#   IDELAY/ISERDES control pins or fabric alignment state outside the AXI
#   clock domain

proc daphne_collect_optional_hier_pins {patterns} {
    set matches {}
    foreach pattern $patterns {
        foreach resolved_pin [get_pins -hier -quiet -filter "NAME =~ $pattern"] {
            lappend matches $resolved_pin
        }
        foreach resolved_pin [get_pins -quiet $pattern] {
            lappend matches $resolved_pin
        }
    }
    return [lsort -unique $matches]
}

proc daphne_collect_optional_hier_nets {patterns} {
    set matches {}
    foreach pattern $patterns {
        foreach resolved_net [get_nets -hier -quiet -filter "NAME =~ $pattern"] {
            lappend matches $resolved_net
        }
    }
    return [lsort -unique $matches]
}

set frontend_sync_stage1_pins [daphne_collect_optional_hier_pins {
    *frontend_common_inst/idelayctrl_reset_500_meta_reg/D
    *frontend_common_inst/idelay_load_clk125_meta_reg[*]/D
    *frontend_common_inst/trig_meta_reg/D
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
