# The external trigger input is asynchronous to the AXI control clock.
# Exclude only its arrival at the first synchronizer D pin. The second
# synchronizer stage and the downstream pulse stretcher remain timed.
set external_trigger_first_stage [get_pins -hier -quiet -filter {
    NAME =~ *trig_in_meta_reg/D
}]
if {[llength $external_trigger_first_stage] != 1} {
    error "Expected one external trigger first-stage D pin, found [llength $external_trigger_first_stage]"
}
set_false_path -to $external_trigger_first_stage
