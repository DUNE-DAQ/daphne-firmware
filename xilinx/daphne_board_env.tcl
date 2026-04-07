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

    foreach field {fpga_part board_part pfm_name constraint_file constraint_files required_constraint_files platform_core modular_platform_core composable_platform_core default_platform_core user_ip_vlnv bd_name bd_wrapper_name bd_shell_tcl build_name_prefix overlay_name_prefix ip_top_hdl_file ip_top_module ip_cell_name ip_component_identifier ip_display_name ip_xgui_file ip_cell_bind_root public_top_hdl_file public_top_module timing_endpoint_path} {
        set value [daphne_read_board_manifest_value $manifest_path $field ""]
        if {$value ne ""} {
            dict set profile $field $value
        }
    }

    if {![dict exists $profile default_platform_core] || [string trim [dict get $profile default_platform_core]] eq ""} {
        if {[dict exists $profile composable_platform_core] && [string trim [dict get $profile composable_platform_core]] ne ""} {
            dict set profile default_platform_core [dict get $profile composable_platform_core]
        } elseif {[dict exists $profile platform_core] && [string trim [dict get $profile platform_core]] ne ""} {
            dict set profile default_platform_core [dict get $profile platform_core]
        }
    }

    foreach field {fpga_part board_part pfm_name constraint_file} {
        if {![dict exists $profile $field] || [string trim [dict get $profile $field]] eq ""} {
            error "ERROR: board '$board_name' is missing '$field' in $manifest_path."
        }
    }

    return $profile
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
                  && ![string match "*_validate_stub.vhd" [file tail $entry]]
                  && ![string match "legacy_public_top_bridge.vhd" [file tail $entry]]} {
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
