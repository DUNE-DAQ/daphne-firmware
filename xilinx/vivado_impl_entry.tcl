set script_dir [file dirname [file normalize [info script]]]
source -notrace [file join $script_dir "daphne_vivado_flow.tcl"]
daphne_run_full_build $script_dir
