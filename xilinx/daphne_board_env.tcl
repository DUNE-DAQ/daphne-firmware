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

    foreach field {fpga_part board_part pfm_name constraint_file user_ip_vlnv bd_name build_name_prefix ip_cell_bind_root timing_endpoint_path} {
        set value [daphne_read_board_manifest_value $manifest_path $field ""]
        if {$value ne ""} {
            dict set profile $field $value
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

proc daphne_resolve_legacy_support_sources {repo_root} {
    set manifest_path [file join $repo_root "xilinx" "legacy_flow_support_sources.txt"]
    set sources {}
    foreach rel_path [daphne_read_path_manifest $manifest_path] {
        lappend sources [daphne_resolve_repo_relative_path $repo_root $rel_path]
    }
    return $sources
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
