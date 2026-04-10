# Shared helpers for selecting the DAPHNE board configuration at runtime.

proc daphne_get_env_or_default {name default_value} {
    if {[info exists ::env($name)]} {
        set value [string trim $::env($name)]
        if {$value ne ""} {
            return $value
        }
    }
    return $default_value
}

proc daphne_read_board_manifest_value {manifest_path key {default_value ""}} {
    set handle [open $manifest_path r]
    while {[gets $handle line] >= 0} {
        set trimmed_line [string trim $line]
        if {[string first "${key}:" $trimmed_line] == 0} {
            set value [string trim [string range $trimmed_line [string length "${key}:"] end]]
            regsub {[[:space:]]+#.*$} $value "" value
            close $handle
            return [string trim $value "\"' "]
        }
    }
    close $handle
    return $default_value
}

proc daphne_board_profile_value {board_profile key default_value} {
    if {[dict exists $board_profile $key]} {
        set value [string trim [dict get $board_profile $key]]
        if {$value ne ""} {
            return $value
        }
    }
    return $default_value
}

proc daphne_board_profile_value_with_fallback {board_profile preferred_key fallback_key default_value} {
    if {[dict exists $board_profile $preferred_key]} {
        set value [string trim [dict get $board_profile $preferred_key]]
        if {$value ne ""} {
            return $value
        }
    }
    return [daphne_board_profile_value $board_profile $fallback_key $default_value]
}

proc daphne_merge_legacy_board_profile {repo_root board_profile} {
    if {![dict exists $board_profile legacy_manifest]} {
        return $board_profile
    }

    set legacy_manifest_rel [string trim [dict get $board_profile legacy_manifest]]
    if {$legacy_manifest_rel eq ""} {
        return $board_profile
    }

    set legacy_manifest_path [daphne_resolve_repo_relative_path $repo_root $legacy_manifest_rel]
    if {![file exists $legacy_manifest_path]} {
        error "ERROR: expected legacy manifest at $legacy_manifest_path"
    }

    foreach field {
        legacy_user_ip_vlnv
        legacy_bd_name
        legacy_bd_wrapper_name
        legacy_bd_shell_tcl
        legacy_ip_cell_name
        legacy_ip_component_identifier
        legacy_ip_display_name
        legacy_ip_xgui_file
        legacy_ip_cell_bind_root
    } {
        set value [daphne_read_board_manifest_value $legacy_manifest_path $field ""]
        if {$value ne ""} {
            dict set board_profile $field $value
        }
    }

    return $board_profile
}

proc daphne_resolve_git_sha {} {
    set git_sha_override [daphne_get_env_or_default DAPHNE_GIT_SHA ""]
    if {$git_sha_override ne ""} {
        puts "INFO: Using git SHA override from DAPHNE_GIT_SHA=$git_sha_override"
        return $git_sha_override
    }
    if {[catch {exec git rev-parse --short=7 HEAD} git_sha]} {
        puts "WARNING: Could not resolve git HEAD. Falling back to git SHA 0000000."
        return "0000000"
    }
    return $git_sha
}

proc daphne_split_semicolon_list {raw_value} {
    set values {}
    foreach value [split $raw_value ";"] {
        set trimmed_value [string trim $value]
        if {$trimmed_value ne ""} {
            lappend values $trimmed_value
        }
    }
    return $values
}

proc daphne_require_resolved_paths {label repo_root required_raw_paths resolved_paths} {
    foreach required_entry [daphne_split_semicolon_list $required_raw_paths] {
        set required_path [daphne_resolve_repo_relative_path $repo_root $required_entry]
        if {[lsearch -exact $resolved_paths $required_path] < 0} {
            error "ERROR: $label requires path '$required_entry' to be present in the resolved path list."
        }
    }
}

proc daphne_resolve_board_profile {repo_root {board_name ""}} {
    if {$board_name eq ""} {
        set board_name [daphne_get_env_or_default DAPHNE_BOARD "k26c"]
    }
    set manifest_path [file join $repo_root "boards" $board_name "board.yml"]

    if {![file exists $manifest_path]} {
        error "ERROR: unknown board '$board_name'. Expected board manifest at $manifest_path."
    }

    set supported [daphne_read_board_manifest_value $manifest_path "supported" ""]
    if {$supported ne "" && $supported ne "true"} {
        error "ERROR: board '$board_name' is scaffolded but not yet supported. Missing items are tracked in $manifest_path."
    }

    set profile [dict create board $board_name manifest_path $manifest_path]

    set parent_board [daphne_read_board_manifest_value $manifest_path "inherits" ""]
    if {$parent_board ne ""} {
        set profile [daphne_resolve_board_profile $repo_root $parent_board]
        dict set profile board $board_name
        dict set profile manifest_path $manifest_path
        dict set profile inherits $parent_board
    }

    foreach field {fpga_part board_part pfm_name constraint_file constraint_files required_constraint_files platform_core default_platform_target user_ip_vlnv bd_name bd_wrapper_name bd_shell_tcl legacy_manifest build_name_prefix overlay_name_prefix ip_top_hdl_file ip_top_module ip_cell_name ip_component_identifier ip_display_name ip_xgui_file ip_cell_bind_root public_top_hdl_file public_top_module timing_endpoint_path timing_plane_path timing_clock_source afe_capture_input_delay_enable afe_capture_virtual_launch_period_ns afe_capture_input_delay_min_ns afe_capture_input_delay_max_ns} {
        set value [daphne_read_board_manifest_value $manifest_path $field ""]
        if {$value ne ""} {
            dict set profile $field $value
        }
    }

    set profile [daphne_merge_legacy_board_profile $repo_root $profile]

    if {![dict exists $profile default_platform_target] || [string trim [dict get $profile default_platform_target]] eq ""} {
        dict set profile default_platform_target "impl"
    }

    foreach field {fpga_part board_part pfm_name constraint_file platform_core} {
        if {![dict exists $profile $field] || [string trim [dict get $profile $field]] eq ""} {
            error "ERROR: board '$board_name' is missing '$field' in $manifest_path."
        }
    }

    return $profile
}

proc daphne_resolve_artifact_profile {repo_root {board_profile ""}} {
    if {$board_profile eq ""} {
        set board_profile [daphne_resolve_board_profile $repo_root]
    }

    set build_name_prefix [daphne_get_env_or_default DAPHNE_BUILD_NAME_PREFIX [daphne_board_profile_value $board_profile build_name_prefix "daphne_selftrigger"]]
    set overlay_name_prefix [daphne_get_env_or_default DAPHNE_OVERLAY_NAME_PREFIX [daphne_board_profile_value $board_profile overlay_name_prefix "${build_name_prefix}_ol"]]
    set git_sha [daphne_resolve_git_sha]

    return [dict create \
        board_profile $board_profile \
        git_sha $git_sha \
        build_name_prefix $build_name_prefix \
        overlay_name_prefix $overlay_name_prefix \
        build_name "${build_name_prefix}_$git_sha" \
        overlay_name "${overlay_name_prefix}_$git_sha"]
}

proc daphne_resolve_board_config {script_dir} {
    set repo_root [file normalize [file join $script_dir ".."]]
    return [daphne_resolve_board_profile $repo_root]
}

proc daphne_read_path_manifest {manifest_path} {
    if {![file exists $manifest_path]} {
        error "ERROR: expected manifest at $manifest_path"
    }

    set handle [open $manifest_path r]
    set entries {}
    while {[gets $handle line] >= 0} {
        regsub {[[:space:]]+#.*$} $line "" line
        set trimmed_line [string trim $line]
        if {$trimmed_line ne ""} {
            lappend entries $trimmed_line
        }
    }
    close $handle
    return $entries
}

proc daphne_collect_matching_files {root pattern} {
    set results {}
    if {![file exists $root]} {
        return $results
    }

    foreach entry [glob -nocomplain -directory $root *] {
        if {[file isdirectory $entry]} {
            if {[file tail $entry] eq "validate"} {
                continue
            }
            set results [concat $results [daphne_collect_matching_files $entry $pattern]]
        } elseif {[string match $pattern [file tail $entry]]
                  && ![string match "*_validate_stub.vhd" [file tail $entry]]} {
            lappend results [file normalize $entry]
        }
    }

    return $results
}

proc daphne_resolve_legacy_support_sources {repo_root} {
    set manifest_path [file join $repo_root "xilinx" "legacy_flow_support_sources.txt"]
    set sources {}
    foreach rel_path [daphne_read_path_manifest $manifest_path] {
        set resolved_path [daphne_resolve_repo_relative_path $repo_root $rel_path]
        if {[file isdirectory $resolved_path]} {
            set sources [concat $sources [daphne_collect_matching_files $resolved_path "*.vhd"]]
        } elseif {[file exists $resolved_path]} {
            lappend sources $resolved_path
        } else {
            error "ERROR: missing legacy support entry at $resolved_path"
        }
    }
    return [lsort -unique $sources]
}

proc daphne_get_board_env_or_default {cfg_name env_name key {default_value ""}} {
    upvar 1 $cfg_name cfg

    if {[info exists ::env($env_name)]} {
        set value [string trim $::env($env_name)]
        if {$value ne ""} {
            return $value
        }
    }

    if {[info exists cfg($key)]} {
        set value [string trim $cfg($key)]
        if {$value ne ""} {
            return $value
        }
    }

    return $default_value
}

proc daphne_resolve_repo_relative_path {repo_root path_value} {
    if {[file pathtype $path_value] eq "absolute"} {
        return [file normalize $path_value]
    }
    return [file normalize [file join $repo_root $path_value]]
}

proc daphne_find_staged_repo_relative_path {search_root rel_path} {
    if {![file isdirectory $search_root]} {
        return ""
    }

    set trimmed_rel_path [string trim $rel_path "/"]
    if {$trimmed_rel_path eq ""} {
        return ""
    }

    foreach match_type {f d} {
        set matches [glob -nocomplain -directory $search_root -types $match_type -path */$trimmed_rel_path]
        if {[llength $matches] > 0} {
            return [file normalize [lindex $matches 0]]
        }
    }

    return ""
}

proc daphne_seed_env_from_board_profile {board_profile env_name key} {
    if {[info exists ::env($env_name)] && [string trim $::env($env_name)] ne ""} {
        return
    }
    if {![dict exists $board_profile $key]} {
        return
    }
    set value [string trim [dict get $board_profile $key]]
    if {$value ne ""} {
        set ::env($env_name) $value
    }
}
