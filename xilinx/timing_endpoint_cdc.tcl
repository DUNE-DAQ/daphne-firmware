# Timing endpoint CDC constraints Tcl
#
# The PDTS endpoint mixes a free-running 100 MHz sys_clk domain with the
# recovered frontend timing domain. The explicit synchronizer stages should not
# be timed as ordinary synchronous paths, and the raw recovered input pin is not
# a valid hold path against the internal 4x sampling clock.

proc daphne_collect_optional_endpoint_pins {root_candidates relative_patterns} {
    set matches {}
    foreach root_candidate [split $root_candidates ";"] {
        set trimmed_root [string trim $root_candidate]
        if {$trimmed_root eq ""} {
            continue
        }
        foreach relative_pattern $relative_patterns {
            set query_pattern "${trimmed_root}/${relative_pattern}"
            foreach resolved_pin [get_pins -hier -quiet -filter "NAME =~ $query_pattern"] {
                lappend matches $resolved_pin
            }
            foreach resolved_pin [get_pins -quiet $query_pattern] {
                lappend matches $resolved_pin
            }
        }
    }
    return [lsort -unique $matches]
}

if {![info exists ::env(DAPHNE_TIMING_ENDPOINT_PATH)] || [string trim $::env(DAPHNE_TIMING_ENDPOINT_PATH)] eq ""} {
    error "ERROR: DAPHNE_TIMING_ENDPOINT_PATH must be set for timing_endpoint_cdc.tcl"
}
set endpoint_path [string trim $::env(DAPHNE_TIMING_ENDPOINT_PATH)]

set endpoint_sync_stage1_pins [daphne_collect_optional_endpoint_pins $endpoint_path {
    */sync_sys_clk/db_reg[*]/D
    */sync_sys_clk_p/s1/db_reg[*]/D
    */sync_sys_clk_p/s2/db_reg[*]/D
    */sync_t/db_reg[*]/D
    */sync_clk/db_reg[*]/D
    */sync_stat/db_reg[*]/D
}]

if {[llength $endpoint_sync_stage1_pins] > 0} {
    set_false_path -to $endpoint_sync_stage1_pins
}

set endpoint_raw_rx_sample_pins [daphne_collect_optional_endpoint_pins $endpoint_path {
    */rxcdr/sm/iff/D
}]

set rx_tmg_port [get_ports -quiet rx0_tmg_p]
if {[llength $rx_tmg_port] == 1 && [llength $endpoint_raw_rx_sample_pins] > 0} {
    set_false_path -from $rx_tmg_port -to $endpoint_raw_rx_sample_pins
}

# The PDTS register file raises addr_done/deskew_done in the recovered frontend
# clock domain, while the endpoint state machine consumes them on sys_clk.
# Treat these completion flags as asynchronous handoff signals rather than
# synchronous timing requirements between frontend_word_clk and mmcm0_clkout2.
set endpoint_regfile_done_source_pins [daphne_collect_optional_endpoint_pins $endpoint_path {
    */ep/regfile/adone_reg/Q
    */ep/regfile/ddone_reg/Q
}]

set endpoint_state_machine_pins [daphne_collect_optional_endpoint_pins $endpoint_path {
    */ep/sm/state_reg[*]/D
}]

if {[llength $endpoint_regfile_done_source_pins] > 0 && [llength $endpoint_state_machine_pins] > 0} {
    set_false_path -from $endpoint_regfile_done_source_pins -to $endpoint_state_machine_pins
}
