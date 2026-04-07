# Frontend control CDC constraints
#
# Keep AXI-originated frontend control/state crossings separate from the
# source-synchronous AFE capture clock family in afe_capture_timing.xdc.
#
# These nets are intentionally not timed as synchronous data paths:
# - idelayctrl_reset crosses into clk500 via frontend_common
# - idelay_load crosses into clk125 via frontend_common
# - trig_axi crosses into clock via frontend_common
# - idelay_tap/idelay_en_vtc/iserdes_reset/iserdes_bitslip drive IDELAY/ISERDES
#   control pins or fabric alignment state outside the AXI clock domain

proc daphne_collect_optional_hier_nets {patterns} {
    set matches {}
    foreach pattern $patterns {
        foreach resolved_net [get_nets -hier -quiet -filter "NAME =~ $pattern"] {
            lappend matches $resolved_net
        }
    }
    return [lsort -unique $matches]
}

set frontend_control_cdc_nets [daphne_collect_optional_hier_nets {
    *frontend_island_inst/idelayctrl_reset
    *frontend_island_inst/idelay_load*
    *frontend_island_inst/idelay_tap*
    *frontend_island_inst/idelay_en_vtc
    *frontend_island_inst/iserdes_reset
    *frontend_island_inst/iserdes_bitslip*
    *frontend_island_inst/trig_axi
}]

if {[llength $frontend_control_cdc_nets] > 0} {
    set_false_path -through $frontend_control_cdc_nets
}
