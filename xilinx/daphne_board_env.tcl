# Shared helpers for selecting the Kria board configuration at runtime.

proc daphne_get_env_or_default {name default_value} {
    if {[info exists ::env($name)]} {
        set value [string trim $::env($name)]
        if {$value ne ""} {
            return $value
        }
    }
    return $default_value
}
