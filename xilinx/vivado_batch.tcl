# TCL script to build daphne_selftrigger_top vivado design
# Daniel Avila Gomez <daniel.avila@eia.edu.co - daniel.avila.gomez@cern.ch> and Jamieson Olsen <jamieson@fnal.gov>
#
# run: vivado -mode tcl -source vivado_batch.tcl

set script_dir [file dirname [file normalize [info script]]]
source -notrace [file join $script_dir "daphne_vivado_flow.tcl"]
daphne_run_full_build $script_dir
