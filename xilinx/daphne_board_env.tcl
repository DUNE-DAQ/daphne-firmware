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

proc daphne_resolve_board_profile {repo_root} {
    set board [daphne_get_env_or_default DAPHNE_BOARD "k26c"]
    set manifest_path [file join $repo_root "boards" $board "board.yml"]

    if {![file exists $manifest_path]} {
        error "ERROR: unknown board '$board'. Expected board manifest at $manifest_path."
    }

    set supported [daphne_read_board_manifest_value $manifest_path "supported" ""]
    if {$supported ne "true"} {
        error "ERROR: board '$board' is scaffolded but not yet supported. Missing items are tracked in $manifest_path."
    }

    set profile [dict create board $board manifest_path $manifest_path]

    foreach field {fpga_part board_part pfm_name constraint_file} {
        set value [daphne_read_board_manifest_value $manifest_path $field ""]
        if {$value eq ""} {
            error "ERROR: board '$board' is missing '$field' in $manifest_path."
        }
        dict set profile $field $value
    }

    return $profile
}

proc daphne_resolve_board_config {script_dir} {
    set repo_root [file normalize [file join $script_dir ".."]]
    return [daphne_resolve_board_profile $repo_root]
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
