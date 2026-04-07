# AFE capture timing scaffold
#
# This file is documentation plus a future constraint split point.
# It is intentionally NOT sourced by the current build.
#
# The live build still uses xilinx/daphne_selftrigger_pin_map.xdc. Promote only
# reviewed pieces from this scaffold once they have been checked against the
# synthesized hierarchy and, for input delays, real device/board timing data.

#
# Current timing intent
# ---------------------
# - Treat the frontend receive path as one synchronous family:
#   - word clock  : clock
#   - bit clock   : clk500
#   - byte clock  : clk125
# - Do not cut async paths inside that family.
# - Keep AXI/control CDC constraints separate from the source-synchronous AFE
#   capture timing model.
# - If one bitstream supports both endpoint- and local-clock modes, model those
#   source families as physically exclusive, not asynchronous.

#
# Hierarchy guide for the current legacy build
# --------------------------------------------
# The live datapath still enters through:
#   daphne_selftrigger_bd_i/daphne_selftrigger_top/U0/endpoint_inst
#   daphne_selftrigger_bd_i/daphne_selftrigger_top/U0/front_end_inst
#
# The refactor keeps the frontend timing ownership conceptually aligned with:
#   rtl/isolated/subsystems/frontend/frontend_common.vhd
# but that shell is not yet the synthesized owner of the full receive path.

#
# Clock-family scaffold
# ---------------------
# Endpoint-driven family
#
# set endpoint_path "daphne_selftrigger_bd_i/daphne_selftrigger_top/U0/endpoint_inst"
# create_generated_clock -name frontend_word_clk_ep  [get_nets ${endpoint_path}/ep_clk62p5]
# create_generated_clock -name frontend_bit_clk_ep   -master_clock frontend_word_clk_ep [get_nets ${endpoint_path}/clk500]
# create_generated_clock -name frontend_byte_clk_ep  -master_clock frontend_word_clk_ep [get_nets ${endpoint_path}/clk125]
#
# Local-clock-driven family
#
# create_generated_clock -name frontend_word_clk_local [get_nets ${endpoint_path}/local_clk62p5]
# create_generated_clock -name frontend_bit_clk_local  -master_clock frontend_word_clk_local [get_nets ${endpoint_path}/clk500]
# create_generated_clock -name frontend_byte_clk_local -master_clock frontend_word_clk_local [get_nets ${endpoint_path}/clk125]
#
# If both source families remain in one build, prefer physically exclusive
# grouping instead of async cuts:
#
# set_clock_groups -physically_exclusive \
#   -group {frontend_word_clk_ep frontend_bit_clk_ep frontend_byte_clk_ep} \
#   -group {frontend_word_clk_local frontend_bit_clk_local frontend_byte_clk_local}

#
# Source-synchronous AFE launch model scaffold
# --------------------------------------------
# The current XDC has electrical/package constraints for the LVDS inputs but no
# measured input-delay model. Add these only when AFE serializer timing and
# board skew numbers are available.
#
# Example placeholder shape. The board manifest now carries the same intent via:
# - afe_capture_input_delay_enable
# - afe_capture_virtual_launch_period_ns
# - afe_capture_input_delay_min_ns
# - afe_capture_input_delay_max_ns
# The live XDC only applies the model when that board-owned enable is true.
#
# create_clock -name afe_launch_clk_virtual -period 2.000
#
# set afe_data_ports [list \
#   [get_ports {afe0_p[*]}] \
#   [get_ports {afe1_p[*]}] \
#   [get_ports {afe2_p[*]}] \
#   [get_ports {afe3_p[*]}] \
#   [get_ports {afe4_p[*]}] \
# ]
#
# set_input_delay -clock afe_launch_clk_virtual -max <MEASURED_MAX_NS> $afe_data_ports
# set_input_delay -clock afe_launch_clk_virtual -min <MEASURED_MIN_NS> $afe_data_ports
# set_input_delay -clock afe_launch_clk_virtual -clock_fall -add_delay -max <MEASURED_MAX_NS> $afe_data_ports
# set_input_delay -clock afe_launch_clk_virtual -clock_fall -add_delay -min <MEASURED_MIN_NS> $afe_data_ports

#
# AXI/control CDC reminder
# ------------------------
# fe_axi-originated control strobes and resets should be constrained/reviewed as
# CDC paths independently from the receive clock family above. Do not use broad
# frontend async cuts as a substitute for explicit CDC cleanup.
