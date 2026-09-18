# The diagnostic frequency counter selects one divided PHY clock and samples
# its level in the IPbus domain. ipbus_freq_ctr marks t_in and t as ASYNC_REG;
# only the asynchronous first-stage D pin is excepted here. Its second stage,
# edge detector and counter remain timed. Payload and status CDC use XPM-owned
# constraints instead of broad clock-group exclusions.

# Each Ethernet lane recovers RX timing independently from its local TX clock.
# They have the same nominal frequency, but there is no deterministic phase
# relationship. Keep this exception lane-local: do not group RX/TX clocks
# across lanes or with unrelated domains. The Hermes XPM FIFOs and explicit
# synchronizers own the crossings within each pair.
for {set lane 0} {$lane < 2} {incr lane} {
    set rx_clock_name [format {rx_clk_array[%d]} $lane]
    set tx_clock_name [format {tx_clk_array[%d]} $lane]
    set rx_lane_clocks [get_clocks -quiet -filter "NAME == \"$rx_clock_name\""]
    set tx_lane_clocks [get_clocks -quiet -filter "NAME == \"$tx_clock_name\""]

    if {[llength $rx_lane_clocks] != 1 || [llength $tx_lane_clocks] != 1} {
        error "Expected one RX and TX clock for Hermes lane $lane; found [llength $rx_lane_clocks] RX and [llength $tx_lane_clocks] TX clocks"
    }

    set_clock_groups -asynchronous -group $rx_lane_clocks -group $tx_lane_clocks
}

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
if {[llength $hermes_source_reset_preset_pins] != 8} {
    error "Expected eight Hermes source-reset synchronizer PRE pins, found [llength $hermes_source_reset_preset_pins]"
}
set_false_path -to $hermes_source_reset_preset_pins

# The two PHY wrappers and the lane-local output synchronizers use the same
# asynchronous-assert, synchronous-release reset pattern. Only recovery and
# removal at their asynchronous preset pins are intentionally untimed; release
# shift paths and all functional D pins remain timed.
set hermes_phy_reset_preset_pins [get_pins -hier -quiet -filter {
    NAME =~ *pcs_pma/phy_gen*.tx_reset_sync_s_reg*/PRE ||
    NAME =~ *pcs_pma/phy_gen*.rx_reset_sync_s_reg*/PRE ||
    NAME =~ *pcs_pma/phy_gen*.phy_reset/tx_core_reset_sync_reg*/PRE ||
    NAME =~ *pcs_pma/phy_gen*.phy_reset/rx_core_reset_sync_reg*/PRE
}]
if {[llength $hermes_phy_reset_preset_pins] != 16} {
    error "Expected sixteen Hermes PHY reset synchronizer PRE pins, found [llength $hermes_phy_reset_preset_pins]"
}
set_false_path -to $hermes_phy_reset_preset_pins

# The generated XXV core contains three-stage ASYNC_REG synchronizers for the
# RX block-lock level and TX reset-done level entering the 100 MHz dclk domain.
# Routed report_cdc identifies these destinations as the first stage (depth 3).
# Cut only those four asynchronous D pins; the two settling stages remain
# fully timed and physically optimized.
set hermes_xxv_dclk_stage1_pins [get_pins -hier -quiet -filter {
    NAME =~ *phy_10gbe/inst/i_xxv_ethernet_0_core_cdc_sync_stat_rx_block_lock_dclk_0/s_out_d2_cdc_to_reg/D ||
    NAME =~ *phy_10gbe/inst/i_xxv_ethernet_0_core_cdc_sync_tx_resetdone_dclk_0/s_out_d2_cdc_to_reg/D
}]
if {[llength $hermes_xxv_dclk_stage1_pins] != 4} {
    error "Expected four XXV dclk synchronizer first-stage D pins, found [llength $hermes_xxv_dclk_stage1_pins]"
}
set_false_path -to $hermes_xxv_dclk_stage1_pins

# The XXV sys_reset input fans out to asynchronous reset structures in several
# internal GT and core clock domains, as confirmed by the routed recovery
# endpoints. Cut only the two core boundary pins so unrelated control-plane
# paths remain timed.
set hermes_xxv_sys_reset_pins [get_pins -hier -quiet -filter {
    NAME =~ *pcs_pma/phy_gen*.phy_10gbe/inst/sys_reset
}]
if {[llength $hermes_xxv_sys_reset_pins] != 2} {
    error "Expected two XXV sys_reset boundary pins, found [llength $hermes_xxv_sys_reset_pins]"
}
set_false_path -through $hermes_xxv_sys_reset_pins
