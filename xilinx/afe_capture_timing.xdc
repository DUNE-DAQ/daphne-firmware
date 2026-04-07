# Active AFE capture timing constraints
#
# Split out of xilinx/daphne_selftrigger_pin_map.xdc so the frontend
# source-synchronous receive family can be reviewed independently from board
# pin/package constraints.
#
# The primary sysclk definition remains in xilinx/daphne_selftrigger_pin_map.xdc.

if {![info exists ::env(DAPHNE_TIMING_ENDPOINT_PATH)] || [string trim $::env(DAPHNE_TIMING_ENDPOINT_PATH)] eq ""} {
    error "ERROR: DAPHNE_TIMING_ENDPOINT_PATH must be set for afe_capture_timing.xdc"
}
set endpoint_path [string trim $::env(DAPHNE_TIMING_ENDPOINT_PATH)]

proc daphne_require_single_net {net_name purpose} {
    set resolved_nets [get_nets -quiet $net_name]
    if {[llength $resolved_nets] != 1} {
        error "ERROR: expected exactly one net for $purpose at '$net_name', found [llength $resolved_nets]"
    }
    return [lindex $resolved_nets 0]
}

proc daphne_set_async_clock_groups_if_present {group_a group_b} {
    set clocks_a {}
    set clocks_b {}

    foreach clock_name $group_a {
        foreach resolved_clock [get_clocks -quiet $clock_name] {
            lappend clocks_a $resolved_clock
        }
    }
    foreach clock_name $group_b {
        foreach resolved_clock [get_clocks -quiet $clock_name] {
            lappend clocks_b $resolved_clock
        }
    }

    if {[llength $clocks_a] > 0 && [llength $clocks_b] > 0} {
        set_clock_groups -asynchronous -group $clocks_a -group $clocks_b
    }
}

set frontend_word_clk_ep_net [daphne_require_single_net ${endpoint_path}/ep_clk62p5 "frontend endpoint word-clock source"]
set frontend_word_clk_local_net [daphne_require_single_net ${endpoint_path}/local_clk62p5 "frontend local word-clock source"]
set frontend_bit_clk_net [daphne_require_single_net ${endpoint_path}/clk500 "frontend bit-clock source"]
set frontend_byte_clk_net [daphne_require_single_net ${endpoint_path}/clk125 "frontend byte-clock source"]
set endpoint_bclk_net [daphne_require_single_net ${endpoint_path}/pdts_endpoint_inst/pdts_endpoint_inst/rxcdr/bclk "timing endpoint recovered bit clock"]

create_generated_clock -name frontend_word_clk_ep     $frontend_word_clk_ep_net
create_generated_clock -name frontend_word_clk_local  $frontend_word_clk_local_net
create_generated_clock -name frontend_bit_clk_ep      -master_clock frontend_word_clk_ep    $frontend_bit_clk_net
create_generated_clock -name frontend_byte_clk_ep     -master_clock frontend_word_clk_ep    $frontend_byte_clk_net
create_generated_clock -add -name frontend_bit_clk_local   -master_clock frontend_word_clk_local  $frontend_bit_clk_net
create_generated_clock -add -name frontend_byte_clk_local  -master_clock frontend_word_clk_local  $frontend_byte_clk_net

set_clock_groups -physically_exclusive \
  -group {frontend_word_clk_ep frontend_bit_clk_ep frontend_byte_clk_ep} \
  -group {frontend_word_clk_local frontend_bit_clk_local frontend_byte_clk_local}

set_property CLOCK_DEDICATED_ROUTE BACKBONE $endpoint_bclk_net

set frontend_clock_family {
    frontend_word_clk_ep
    frontend_bit_clk_ep
    frontend_byte_clk_ep
    frontend_word_clk_local
    frontend_bit_clk_local
    frontend_byte_clk_local
}

daphne_set_async_clock_groups_if_present {clk_pl_0} $frontend_clock_family
daphne_set_async_clock_groups_if_present {clk_pl_2} $frontend_clock_family
