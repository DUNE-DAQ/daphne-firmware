proc daphne_append_unique_path {current candidate} {
    if {$candidate eq ""} {
        return $current
    }
    foreach existing [split $current ";"] {
        if {$existing eq $candidate} {
            return $current
        }
    }
    if {$current eq ""} {
        return $candidate
    }
    return "${current};${candidate}"
}

proc daphne_find_first_file_dir {search_root leaf} {
    if {![file isdirectory $search_root]} {
        return ""
    }
    set matches [glob -nocomplain -directory $search_root -types f -tails -path */$leaf]
    if {[llength $matches] == 0} {
        return ""
    }
    return [file dirname [file join $search_root [lindex $matches 0]]]
}

proc daphne_configure_fusesoc_export_env {script_dir} {
    set work_root [file normalize [file join $script_dir ".." ".."]]
    set src_root [file join $work_root "src"]

    if {![info exists ::env(DAPHNE_BOARD)] || $::env(DAPHNE_BOARD) eq ""} {
        set ::env(DAPHNE_BOARD) "k26c"
    }
    if {![info exists ::env(DAPHNE_ETH_MODE)] || $::env(DAPHNE_ETH_MODE) eq ""} {
        set ::env(DAPHNE_ETH_MODE) "create_ip"
    }

    if {(![info exists ::env(DAPHNE_IP_REPO_ROOT)] || $::env(DAPHNE_IP_REPO_ROOT) eq "") && [file isdirectory $src_root]} {
        set matches [glob -nocomplain -directory $src_root -types d */ip_repo/daphne_ip]
        if {[llength $matches] > 0} {
            set ::env(DAPHNE_IP_REPO_ROOT) [file normalize [lindex $matches 0]]
        }
    }

    if {[info exists ::env(DAPHNE_IP_REPO_ROOT)] && $::env(DAPHNE_IP_REPO_ROOT) ne "" && (![info exists ::env(DAPHNE_USER_IP_REPO_PARENT)] || $::env(DAPHNE_USER_IP_REPO_PARENT) eq "")} {
        set ::env(DAPHNE_USER_IP_REPO_PARENT) [file dirname $::env(DAPHNE_IP_REPO_ROOT)]
    }

    if {![info exists ::env(DAPHNE_IP_EXTRA_SOURCE_ROOTS)] || $::env(DAPHNE_IP_EXTRA_SOURCE_ROOTS) eq ""} {
        set extra_roots ""
        foreach required_leaf {
            daphne_subsystem_pkg.vhd
            configurable_delay_line.vhd
            fixed_delay_line.vhd
            sync_fifo_fwft.vhd
            legacy_selftrigger_register_bank.vhd
            legacy_stuff_selftrigger_register_bank.vhd
            legacy_trigger_control_adapter.vhd
            legacy_selftrigger_inputs_bridge.vhd
            legacy_selftrigger_fabric_bridge.vhd
            frontend_common.vhd
            afe_capture_slice.vhd
            frontend_capture_bank.vhd
            frontend_register_slice.vhd
            frontend_register_bank.vhd
            frontend_island.vhd
            afe_capture_to_trigger_bank.vhd
            frontend_to_selftrigger_adapter.vhd
            legacy_core_readout_bridge.vhd
            legacy_deimos_readout_bridge.vhd
            legacy_selftrigger_plane_bridge.vhd
            legacy_two_lane_readout_mux.vhd
            legacy_timing_subsystem_bridge.vhd
            self_trigger_xcorr_channel.vhd
            peak_descriptor_channel.vhd
            afe_trigger_bank.vhd
            legacy_selftrigger_datapath.vhd
            afe_selftrigger_island.vhd
            selftrigger_fabric.vhd
            stc3_record_builder.vhd
        } {
            set found_dir [daphne_find_first_file_dir $src_root $required_leaf]
            set extra_roots [daphne_append_unique_path $extra_roots $found_dir]
        }
        if {$extra_roots ne ""} {
            set ::env(DAPHNE_IP_EXTRA_SOURCE_ROOTS) $extra_roots
        }
    }
}

set script_dir [file dirname [file normalize [info script]]]
daphne_configure_fusesoc_export_env $script_dir

source -notrace [file join $script_dir "daphne_vivado_flow.tcl"]

array set cfg [daphne_resolve_config $script_dir]
daphne_check_vivado_version cfg

set_param general.maxThreads $cfg(max_threads)
set_property BOARD_PART $cfg(board_part) [current_project]
set_property TARGET_LANGUAGE VHDL [current_project]
set_property DEFAULT_LIB work [current_project]
set ::env(DAPHNE_PFM_NAME) $cfg(pfm_name)

daphne_create_block_design cfg
