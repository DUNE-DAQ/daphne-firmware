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
