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

    if {[file isdirectory $src_root]} {
        set staged_ip_repo_root [daphne_find_staged_repo_relative_path $src_root "ip_repo/daphne_ip"]
        if {$staged_ip_repo_root ne "" && (![info exists ::env(DAPHNE_IP_REPO_ROOT)] || $::env(DAPHNE_IP_REPO_ROOT) eq "")} {
            set ::env(DAPHNE_IP_REPO_ROOT) $staged_ip_repo_root
        }

        set staged_board_profile [daphne_resolve_board_profile $work_root]
        if {dict exists $staged_board_profile ip_top_hdl_file} {
            set staged_top_path [daphne_find_staged_repo_relative_path $src_root [dict get $staged_board_profile ip_top_hdl_file]]
            if {$staged_top_path ne "" && (![info exists ::env(DAPHNE_IP_TOP_HDL_FILE)] || $::env(DAPHNE_IP_TOP_HDL_FILE) eq "")} {
                set ::env(DAPHNE_IP_TOP_HDL_FILE) $staged_top_path
            }
        }
    }

    if {[info exists ::env(DAPHNE_IP_REPO_ROOT)] && $::env(DAPHNE_IP_REPO_ROOT) ne "" && (![info exists ::env(DAPHNE_USER_IP_REPO_PARENT)] || $::env(DAPHNE_USER_IP_REPO_PARENT) eq "")} {
        set ::env(DAPHNE_USER_IP_REPO_PARENT) [file dirname $::env(DAPHNE_IP_REPO_ROOT)]
    }

    if {![info exists ::env(DAPHNE_IP_EXTRA_SOURCE_ROOTS)] || $::env(DAPHNE_IP_EXTRA_SOURCE_ROOTS) eq ""} {
        set extra_roots ""
        set support_manifest [file join $work_root "xilinx" "legacy_flow_support_sources.txt"]
        if {[file exists $support_manifest] && [file isdirectory $src_root]} {
            foreach support_rel [daphne_read_path_manifest $support_manifest] {
                set staged_support_path [daphne_find_staged_repo_relative_path $src_root $support_rel]
                if {$staged_support_path ne ""} {
                    set extra_roots [daphne_append_unique_path $extra_roots [file dirname $staged_support_path]]
                }
            }
        }
        if {$extra_roots ne ""} {
            set ::env(DAPHNE_IP_EXTRA_SOURCE_ROOTS) $extra_roots
        }
    }
}

set script_dir [file dirname [file normalize [info script]]]
source -notrace [file join $script_dir "daphne_board_env.tcl"]
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
