#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
ETH_MODE="${DAPHNE_ETH_MODE:-create_ip}"

case "$BOARD" in
  k26c)
    : "${DAPHNE_FPGA_PART:=xck26-sfvc784-2LV-c}"
    : "${DAPHNE_BOARD_PART:=xilinx.com:k26c:part0:1.4}"
    : "${DAPHNE_PFM_NAME:=xilinx:k26c:name:0.0}"
    ;;
  kr260)
    echo "ERROR: board '$BOARD' is scaffolded but not yet supported." >&2
    exit 2
    ;;
  *)
    echo "ERROR: unknown board '$BOARD'." >&2
    exit 2
    ;;
esac

if ! command -v vivado >/dev/null 2>&1; then
  echo "ERROR: vivado is not installed or not on PATH." >&2
  exit 2
fi

if [ "$ETH_MODE" = "vendored_hdl" ]; then
  echo "ERROR: DAPHNE_ETH_MODE=vendored_hdl is not qualified for full implementation yet." >&2
  echo "Use DAPHNE_ETH_MODE=create_ip for the current WSL/Windows Vivado flow." >&2
  exit 2
fi

export DAPHNE_FPGA_PART
export DAPHNE_BOARD_PART
export DAPHNE_PFM_NAME
export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"

cd "$ROOT_DIR/xilinx"

shim_tcl=".daphne-vivado-preflight.$$.tcl"
trap 'rm -f "$shim_tcl"' EXIT INT TERM HUP

append_env_tcl() {
  var_name="$1"
  eval "var_value=\${$var_name-}"
  [ -n "$var_value" ] || return 0
  escaped_value=$(printf '%s' "$var_value" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf 'set ::env(%s) "%s"\n' "$var_name" "$escaped_value" >>"$shim_tcl"
}

: >"$shim_tcl"
printf 'create_project -in_memory -part "%s"\n' "$DAPHNE_FPGA_PART" >>"$shim_tcl"
append_env_tcl DAPHNE_FPGA_PART
append_env_tcl DAPHNE_BOARD_PART
append_env_tcl DAPHNE_PFM_NAME
append_env_tcl DAPHNE_BOARD
append_env_tcl DAPHNE_ETH_MODE
append_env_tcl DAPHNE_GIT_SHA
append_env_tcl DAPHNE_OUTPUT_DIR
printf 'set script_dir [file dirname [file normalize [info script]]]\n' >>"$shim_tcl"
printf 'source -notrace [file join $script_dir "daphne_ip_gen.tcl"]\n' >>"$shim_tcl"
printf 'exit\n' >>"$shim_tcl"

echo "INFO: Running packaging preflight for board=$BOARD eth_mode=$ETH_MODE."
vivado -mode batch -source "$shim_tcl"

component_xml="$ROOT_DIR/ip_repo/daphne_ip/component.xml"
eth_xci="$ROOT_DIR/ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src/xxv_ethernet_0/xxv_ethernet_0.xci"
eth_binding='CELL_NAME_core_inst/legacy_deimos_readout_bridge_inst/daphne_top_inst/mux/pcs_pma/phy_gen[0].phy_10gbe'
bram_binding='CELL_NAME_core_inst/legacy_deimos_readout_bridge_inst/daphne_top_inst/ipb_ctrl/ipbus_transport_axil/axi_bram_ctrl'
eth_xci_ref='src/dune.daq_user_hermes_daphne_1.0/src/xxv_ethernet_0/xxv_ethernet_0.xci'

if [ ! -f "$component_xml" ]; then
  echo "ERROR: Expected packaged component.xml at $component_xml" >&2
  exit 2
fi

if [ ! -f "$eth_xci" ]; then
  echo "ERROR: Expected Ethernet XCI at $eth_xci" >&2
  exit 2
fi

if ! grep -Fq "$eth_xci_ref" "$component_xml"; then
  echo "ERROR: component.xml is missing Ethernet XCI reference: $eth_xci_ref" >&2
  exit 2
fi

if ! grep -Fq "$eth_binding" "$component_xml"; then
  echo "ERROR: component.xml is missing Ethernet cell binding: $eth_binding" >&2
  exit 2
fi

if ! grep -Fq "$bram_binding" "$component_xml"; then
  echo "ERROR: component.xml is missing AXI BRAM cell binding: $bram_binding" >&2
  exit 2
fi

for support_leaf in \
  legacy_analog_control_plane_bridge.vhd \
  legacy_selftrigger_register_bank.vhd \
  legacy_stuff_selftrigger_register_bank.vhd \
  legacy_trigger_control_adapter.vhd \
  legacy_selftrigger_inputs_bridge.vhd \
  legacy_selftrigger_fabric_bridge.vhd \
  afe_capture_to_trigger_bank.vhd \
  frontend_to_selftrigger_adapter.vhd \
  legacy_core_readout_bridge.vhd \
  legacy_selftrigger_plane_bridge.vhd \
  legacy_selftrigger_datapath.vhd \
  legacy_two_lane_readout_mux.vhd \
  legacy_spy_capture_bridge.vhd \
  afe_trigger_bank.vhd \
  afe_selftrigger_island.vhd \
  selftrigger_fabric.vhd \
  legacy_deimos_readout_bridge.vhd \
  legacy_timing_subsystem_bridge.vhd
do
  if ! grep -Fq "$support_leaf" "$component_xml"; then
    echo "ERROR: component.xml is missing packaged support source: $support_leaf" >&2
    exit 2
  fi
done

echo "INFO: Preflight passed."
echo "INFO: Ethernet XCI, legacy transport/BRAM bindings, and extracted support sources are present in component.xml."
