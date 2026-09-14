# The diagnostic frequency counter selects one divided PHY clock and samples
# its level in the IPbus domain. ipbus_freq_ctr marks t_in and t as ASYNC_REG;
# only the asynchronous first-stage D pin is excepted here. Its second stage,
# edge detector and counter remain timed. Payload and status CDC use XPM-owned
# constraints instead of broad clock-group exclusions.
set hermes_frequency_stage1 [get_pins -hier -quiet -filter {
    NAME =~ *pcs_pma/freq/t_in_reg/D
}]
if {[llength $hermes_frequency_stage1] != 1} {
    error "Expected one Hermes frequency-counter synchronizer first stage, found [llength $hermes_frequency_stage1]"
}
set_false_path -to $hermes_frequency_stage1

# The acquisition restart asynchronously presets each four-stage TX reset
# synchronizer so the stream aborts even if its PHY clock stops. Release is
# shifted through the TX clock; only the asynchronous PRE arrivals are
# excepted. Clock-to-Q and D timing along all release stages remain checked.
set hermes_source_reset_preset_pins [get_pins -hier -quiet -filter {
    NAME =~ *source_reset_sync_inst/reset_pipe_s_reg*/PRE
}]
if {[llength $hermes_source_reset_preset_pins] != 16} {
    error "Expected sixteen Hermes source-reset synchronizer PRE pins, found [llength $hermes_source_reset_preset_pins]"
}
set_false_path -to $hermes_source_reset_preset_pins
