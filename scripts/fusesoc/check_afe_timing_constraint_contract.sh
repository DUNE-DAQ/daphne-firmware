#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"

BOARD_MANIFEST="$ROOT_DIR/boards/$BOARD/board.yml"
FLOW_TCL="$ROOT_DIR/xilinx/daphne_vivado_flow.tcl"
TIMING_TCL="$ROOT_DIR/xilinx/afe_capture_timing.tcl"
CDC_TCL="$ROOT_DIR/xilinx/frontend_control_cdc.tcl"
ENDPOINT_RTL="$ROOT_DIR/ip_repo/daphne_ip/rtl/timing/endpoint.vhd"
BATCH_HOOK="$ROOT_DIR/scripts/fusesoc/vivado_batch_hook.sh"
MANUAL_RUNNER="$ROOT_DIR/scripts/wsl/run_manual_vivado_pushd.sh"

require_file() {
  file_path="$1"
  if [ ! -f "$file_path" ]; then
    echo "ERROR: required file not found: $file_path" >&2
    exit 2
  fi
}

require_fixed() {
  needle="$1"
  file_path="$2"
  description="$3"
  if ! rg -Fq "$needle" "$file_path"; then
    echo "ERROR: $description" >&2
    echo "INFO: missing literal: $needle" >&2
    echo "INFO: file: $file_path" >&2
    exit 1
  fi
}

require_regex() {
  pattern="$1"
  file_path="$2"
  description="$3"
  if ! rg -q "$pattern" "$file_path"; then
    echo "ERROR: $description" >&2
    echo "INFO: missing pattern: $pattern" >&2
    echo "INFO: file: $file_path" >&2
    exit 1
  fi
}

forbid_fixed() {
  needle="$1"
  file_path="$2"
  description="$3"
  if rg -Fq "$needle" "$file_path"; then
    echo "ERROR: $description" >&2
    echo "INFO: stale literal present: $needle" >&2
    echo "INFO: file: $file_path" >&2
    exit 1
  fi
}

require_file "$BOARD_MANIFEST"
require_file "$FLOW_TCL"
require_file "$TIMING_TCL"
require_file "$CDC_TCL"
require_file "$ENDPOINT_RTL"
require_file "$BATCH_HOOK"
require_file "$MANUAL_RUNNER"

require_fixed "constraint_files: xilinx/daphne_selftrigger_pin_map.xdc;xilinx/afe_capture_timing.tcl;xilinx/frontend_control_cdc.tcl" "$BOARD_MANIFEST" \
  "board manifest does not stage the Tcl-backed AFE timing constraints."
require_fixed "required_constraint_files: xilinx/afe_capture_timing.tcl;xilinx/frontend_control_cdc.tcl" "$BOARD_MANIFEST" \
  "board manifest does not require the Tcl-backed AFE timing constraints."
require_fixed "timing_clock_source: endpoint" "$BOARD_MANIFEST" \
  "board manifest does not select the endpoint clocking mode for AFE timing by default."

require_fixed "if {\$constraint_basename in {\"afe_capture_timing.tcl\" \"frontend_control_cdc.tcl\"}} {" "$FLOW_TCL" \
  "Vivado flow no longer classifies the Tcl-backed AFE timing files for post-synth loading."
require_fixed "read_xdc -unmanaged \$constraint_file" "$FLOW_TCL" \
  "Vivado flow no longer loads the Tcl-backed AFE timing files as unmanaged Tcl constraints."
require_fixed "DAPHNE_TIMING_CLOCK_SOURCE timing_clock_source" "$FLOW_TCL" \
  "Vivado flow no longer seeds DAPHNE_TIMING_CLOCK_SOURCE from the board profile."
require_fixed "append_env_tcl DAPHNE_TIMING_CLOCK_SOURCE" "$BATCH_HOOK" \
  "main Vivado batch hook no longer forwards DAPHNE_TIMING_CLOCK_SOURCE."
require_fixed "append_env_tcl DAPHNE_STOP_AFTER_SYNTH" "$BATCH_HOOK" \
  "main Vivado batch hook no longer forwards DAPHNE_STOP_AFTER_SYNTH."
require_fixed "append_env_tcl DAPHNE_DUMP_POST_SYNTH_DEBUG" "$BATCH_HOOK" \
  "main Vivado batch hook no longer forwards DAPHNE_DUMP_POST_SYNTH_DEBUG."
require_fixed "set ::env(DAPHNE_TIMING_CLOCK_SOURCE) \"\$TIMING_CLOCK_SOURCE_TCL\"" "$MANUAL_RUNNER" \
  "manual WSL launcher no longer forwards DAPHNE_TIMING_CLOCK_SOURCE."
require_fixed "set ::env(DAPHNE_STOP_AFTER_SYNTH) \"\$STOP_AFTER_SYNTH_TCL\"" "$MANUAL_RUNNER" \
  "manual WSL launcher no longer forwards DAPHNE_STOP_AFTER_SYNTH."
require_fixed "set ::env(DAPHNE_DUMP_POST_SYNTH_DEBUG) \"\$DUMP_POST_SYNTH_DEBUG_TCL\"" "$MANUAL_RUNNER" \
  "manual WSL launcher no longer forwards DAPHNE_DUMP_POST_SYNTH_DEBUG."

require_fixed "set frontend_byte_clk_pin [daphne_require_single_object pin \$endpoint_path \"mmcm1_clk2_inst/O\" \"frontend byte-clock source\"]" "$TIMING_TCL" \
  "AFE timing Tcl is no longer bound to the live BUFGCE_DIV byte-clock output."
require_fixed "set frontend_clock_pin [daphne_require_single_object pin \$endpoint_path \"mmcm1_clk1_inst/O\" \"frontend live master-clock source\"]" "$TIMING_TCL" \
  "AFE timing Tcl is no longer bound to the live frontend master-clock output."
require_fixed "set frontend_clock_select_pin [daphne_require_single_object pin \$endpoint_path \"mmcm1_inst/CLKINSEL\" \"frontend clock-source select pin\"]" "$TIMING_TCL" \
  "AFE timing Tcl no longer binds the MMCM1 clock-source selector."
require_fixed "set_case_analysis \$frontend_clock_select_value \$frontend_clock_select_pin" "$TIMING_TCL" \
  "AFE timing Tcl no longer constrains MMCM1 to a single selected timing source."
forbid_fixed "mmcm1_inst/CLKOUT2" "$TIMING_TCL" \
  "AFE timing Tcl still points at the old unused MMCM1 CLKOUT2 byte-clock path."
forbid_fixed "set_clock_groups -physically_exclusive" "$TIMING_TCL" \
  "AFE timing Tcl still carries the stale dual-family physically exclusive frontend clock model."
require_fixed "create_generated_clock -name frontend_clock -source \$frontend_word_clk_source_pin -divide_by 1 \$frontend_clock_pin" "$TIMING_TCL" \
  "AFE timing Tcl no longer defines a single selected frontend master clock."
require_fixed "create_generated_clock -name frontend_bit_clk -source \$frontend_word_clk_source_pin -multiply_by 8 \$frontend_bit_clk_pin" "$TIMING_TCL" \
  "AFE timing Tcl no longer defines a single selected frontend bit clock."
require_fixed "create_generated_clock -name frontend_byte_clk -source \$frontend_word_clk_source_pin -multiply_by 2 \$frontend_byte_clk_pin" "$TIMING_TCL" \
  "AFE timing Tcl no longer defines a single selected frontend byte clock."

require_regex "mmcm1_clk2_inst[[:space:]]*:[[:space:]]*BUFGCE_DIV" "$ENDPOINT_RTL" \
  "endpoint.vhd no longer generates clk125 from BUFGCE_DIV."
require_regex "CLKOUT2[[:space:]]*=>[[:space:]]*open, -- was 125 MHz \\(now unused\\)" "$ENDPOINT_RTL" \
  "endpoint.vhd no longer shows the MMCM1 CLKOUT2 path as unused."
require_regex "port map \\( I => mmcm1_clkout0, O => clk125, CE => '1', CLR => '0'\\);" "$ENDPOINT_RTL" \
  "endpoint.vhd no longer feeds clk125 from the 500 MHz MMCM1 output."
require_regex "mmcm1_clk1_inst:[[:space:]]*BUFG port map\\( I => mmcm1_clkout1, O => clock_i\\);" "$ENDPOINT_RTL" \
  "endpoint.vhd no longer exposes the live frontend master clock through mmcm1_clk1_inst."

echo "INFO: AFE timing constraint contract matches the live endpoint clocking and the Vivado 2024.1 unmanaged-Tcl flow."
