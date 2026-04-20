# TCL script to build daphne_selftrigger_top vivado design
# Daniel Avila Gomez <daniel.avila@eia.edu.co - daniel.avila.gomez@cern.ch> and Jamieson Olsen <jamieson@fnal.gov>
#
# run: vivado -mode tcl -source vivado_batch.tcl

set script_dir [file dirname [file normalize [info script]]]
if {[info exists ::env(DAPHNE_VIVADO_FLOW_SCRIPT)] && $::env(DAPHNE_VIVADO_FLOW_SCRIPT) ne ""} {
    set vivado_flow_script $::env(DAPHNE_VIVADO_FLOW_SCRIPT)
} else {
    set vivado_flow_script "daphne_vivado_flow.tcl"
}
if {[info exists ::env(DAPHNE_VIVADO_ENTRY_PROC)] && $::env(DAPHNE_VIVADO_ENTRY_PROC) ne ""} {
    set vivado_entry_proc $::env(DAPHNE_VIVADO_ENTRY_PROC)
} else {
    set vivado_entry_proc "daphne_run_full_build"
}
source -notrace [file join $script_dir $vivado_flow_script]
$vivado_entry_proc $script_dir
