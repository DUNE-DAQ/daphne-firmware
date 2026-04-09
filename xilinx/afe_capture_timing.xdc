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

if {![info exists ::env(DAPHNE_TIMING_PLANE_PATH)] || [string trim $::env(DAPHNE_TIMING_PLANE_PATH)] eq ""} {
    error "ERROR: DAPHNE_TIMING_PLANE_PATH must be set for afe_capture_timing.xdc"
}
set timing_plane_path [string trim $::env(DAPHNE_TIMING_PLANE_PATH)]

proc daphne_require_single_object {object_kind root_candidates relative_path purpose} {
    set resolved_objects {}
    foreach root_candidate [split $root_candidates ";"] {
        set trimmed_root [string trim $root_candidate]
        if {$trimmed_root eq ""} {
            continue
        }

        if {$relative_path eq ""} {
            set object_path $trimmed_root
        } else {
            set object_path "${trimmed_root}/${relative_path}"
        }

        if {$object_kind eq "net"} {
            foreach resolved_net [get_nets -quiet $object_path] {
                lappend resolved_objects $resolved_net
            }
        } elseif {$object_kind eq "pin"} {
            foreach resolved_pin [get_pins -quiet $object_path] {
                lappend resolved_objects $resolved_pin
            }
        } else {
            error "ERROR: unsupported object kind '$object_kind' for $purpose"
        }
    }

    set resolved_objects [lsort -unique $resolved_objects]
    if {[llength $resolved_objects] != 1} {
        error "ERROR: expected exactly one $object_kind for $purpose from candidates '$root_candidates' and suffix '$relative_path', found [llength $resolved_objects]"
    }
    return [lindex $resolved_objects 0]
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

proc daphne_get_trimmed_env {name} {
    if {[info exists ::env($name)]} {
        return [string trim $::env($name)]
    }
    return ""
}

proc daphne_env_true {name} {
    set raw_value [string tolower [daphne_get_trimmed_env $name]]
    expr {$raw_value in {"1" "true" "yes" "on"}}
}

proc daphne_require_env_value {name purpose} {
    set value [daphne_get_trimmed_env $name]
    if {$value eq ""} {
        error "ERROR: $name must be set for $purpose"
    }
    return $value
}

set frontend_word_clk_ep_pin [daphne_require_single_object pin $endpoint_path "pdts_endpoint_inst/pdts_endpoint_inst/rxcdr/mmcm/CLKOUT0" "frontend endpoint word-clock source"]
set frontend_word_clk_local_pin [daphne_require_single_object pin $endpoint_path "mmcm0_inst/CLKOUT0" "frontend local word-clock source"]
set frontend_bit_clk_pin [daphne_require_single_object pin $timing_plane_path "clk500_o" "frontend bit-clock board seam"]
set frontend_byte_clk_pin [daphne_require_single_object pin $timing_plane_path "clk125_o" "frontend byte-clock board seam"]
set endpoint_bclk_net [daphne_require_single_object net $endpoint_path "pdts_endpoint_inst/pdts_endpoint_inst/rxcdr/bclk" "timing endpoint recovered bit clock"]
set endpoint_clku_net [daphne_require_single_object net $endpoint_path "pdts_endpoint_inst/pdts_endpoint_inst/rxcdr/clku" "timing endpoint recovered user clock"]

create_generated_clock -name frontend_word_clk_ep     $frontend_word_clk_ep_pin
create_generated_clock -name frontend_word_clk_local  $frontend_word_clk_local_pin
create_generated_clock -name frontend_bit_clk_ep           -master_clock frontend_word_clk_ep       $frontend_bit_clk_pin
create_generated_clock -name frontend_byte_clk_ep          -master_clock frontend_word_clk_ep       $frontend_byte_clk_pin
create_generated_clock -add -name frontend_bit_clk_local   -master_clock frontend_word_clk_local    $frontend_bit_clk_pin
create_generated_clock -add -name frontend_byte_clk_local  -master_clock frontend_word_clk_local    $frontend_byte_clk_pin

set_clock_groups -physically_exclusive \
  -group {frontend_word_clk_ep frontend_bit_clk_ep frontend_byte_clk_ep} \
  -group {frontend_word_clk_local frontend_bit_clk_local frontend_byte_clk_local}

set_property CLOCK_DEDICATED_ROUTE BACKBONE $endpoint_bclk_net
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN $endpoint_clku_net

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

if {[daphne_env_true DAPHNE_AFE_CAPTURE_INPUT_DELAY_ENABLE]} {
    set afe_launch_clk_period [daphne_require_env_value DAPHNE_AFE_CAPTURE_VIRTUAL_LAUNCH_PERIOD_NS "AFE virtual launch clock period"]
    set afe_input_delay_min [daphne_require_env_value DAPHNE_AFE_CAPTURE_INPUT_DELAY_MIN_NS "AFE input-delay min bound"]
    set afe_input_delay_max [daphne_require_env_value DAPHNE_AFE_CAPTURE_INPUT_DELAY_MAX_NS "AFE input-delay max bound"]

    create_clock -name afe_launch_clk_virtual -period $afe_launch_clk_period

    set afe_data_ports {}
    foreach afe_port_pattern {
        {afe0_p[*]}
        {afe1_p[*]}
        {afe2_p[*]}
        {afe3_p[*]}
        {afe4_p[*]}
    } {
        foreach afe_port [get_ports -quiet $afe_port_pattern] {
            lappend afe_data_ports $afe_port
        }
    }

    if {[llength $afe_data_ports] == 0} {
        error "ERROR: DAPHNE_AFE_CAPTURE_INPUT_DELAY_ENABLE requested, but no AFE positive-lane ports were resolved"
    }

    set_input_delay -clock afe_launch_clk_virtual -max $afe_input_delay_max $afe_data_ports
    set_input_delay -clock afe_launch_clk_virtual -min $afe_input_delay_min $afe_data_ports
    set_input_delay -clock afe_launch_clk_virtual -clock_fall -add_delay -max $afe_input_delay_max $afe_data_ports
    set_input_delay -clock afe_launch_clk_virtual -clock_fall -add_delay -min $afe_input_delay_min $afe_data_ports
}
