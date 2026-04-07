#!/bin/sh
set -eu

WORK_ROOT="${PWD}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLATFORM_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
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
    echo "Missing items are tracked in boards/kr260/board.yml." >&2
    exit 2
    ;;
  *)
    echo "ERROR: unknown board '$BOARD'." >&2
    echo "Set DAPHNE_BOARD=k26c or provide explicit DAPHNE_FPGA_PART/DAPHNE_BOARD_PART/DAPHNE_PFM_NAME overrides." >&2
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

if [ -z "${DAPHNE_GIT_SHA-}" ]; then
  DAPHNE_GIT_SHA=0000000
  export DAPHNE_GIT_SHA
  echo "WARNING: DAPHNE_GIT_SHA not set. Falling back to $DAPHNE_GIT_SHA for artifact naming." >&2
fi

: "${DAPHNE_OUTPUT_DIR:=./output-$DAPHNE_GIT_SHA}"

append_unique_path() {
  current="$1"
  candidate="$2"
  [ -n "$candidate" ] || {
    printf '%s' "$current"
    return 0
  }
  case ";$current;" in
    *";$candidate;"*)
      printf '%s' "$current"
      ;;
    "")
      printf '%s' "$candidate"
      ;;
    *)
      printf '%s;%s' "$current" "$candidate"
      ;;
  esac
}

find_first_file_dir() {
  search_root="$1"
  leaf="$2"
  if [ ! -d "$search_root" ]; then
    return 0
  fi
  found_path=$(find "$search_root" -type f -name "$leaf" -print -quit 2>/dev/null || true)
  if [ -n "$found_path" ]; then
    dirname "$found_path"
  fi
}

if [ -z "${DAPHNE_IP_REPO_ROOT-}" ]; then
  if [ -d "$WORK_ROOT/ip_repo/daphne_ip" ]; then
    DAPHNE_IP_REPO_ROOT="$WORK_ROOT/ip_repo/daphne_ip"
  elif [ -d "$WORK_ROOT/src/dune-daq_daphne_daphne-ip_0.1.0/ip_repo/daphne_ip" ]; then
    DAPHNE_IP_REPO_ROOT="$WORK_ROOT/src/dune-daq_daphne_daphne-ip_0.1.0/ip_repo/daphne_ip"
  fi
fi

if [ -n "${DAPHNE_IP_REPO_ROOT-}" ] && [ -z "${DAPHNE_USER_IP_REPO_PARENT-}" ]; then
  DAPHNE_USER_IP_REPO_PARENT="$(dirname "$DAPHNE_IP_REPO_ROOT")"
fi

if [ -z "${DAPHNE_IP_EXTRA_SOURCE_ROOTS-}" ]; then
  auto_extra_roots=""
  for candidate_dir in \
    "$WORK_ROOT/rtl/isolated/common" \
    "$WORK_ROOT/rtl/isolated/common/primitives" \
    "$WORK_ROOT/rtl/isolated/subsystems/control" \
    "$WORK_ROOT/rtl/isolated/subsystems/frontend" \
    "$WORK_ROOT/rtl/isolated/subsystems/readout" \
    "$WORK_ROOT/rtl/isolated/subsystems/timing" \
    "$WORK_ROOT/rtl/isolated/subsystems/trigger"
  do
    if [ -d "$candidate_dir" ]; then
      auto_extra_roots="$(append_unique_path "$auto_extra_roots" "$candidate_dir")"
    fi
  done

  if [ -d "$WORK_ROOT/src" ]; then
    for required_leaf in \
      daphne_subsystem_pkg.vhd \
      configurable_delay_line.vhd \
      fixed_delay_line.vhd \
      sync_fifo_fwft.vhd \
      legacy_analog_control_plane_bridge.vhd \
      legacy_selftrigger_register_bank.vhd \
      legacy_stuff_selftrigger_register_bank.vhd \
      legacy_trigger_control_adapter.vhd \
      legacy_selftrigger_inputs_bridge.vhd \
      legacy_selftrigger_fabric_bridge.vhd \
      frontend_register_slice.vhd \
      frontend_register_bank.vhd \
      afe_capture_to_trigger_bank.vhd \
      frontend_to_selftrigger_adapter.vhd \
      legacy_core_readout_bridge.vhd \
      legacy_deimos_readout_bridge.vhd \
      legacy_selftrigger_plane_bridge.vhd \
      legacy_two_lane_readout_mux.vhd \
      legacy_timing_subsystem_bridge.vhd \
      self_trigger_xcorr_channel.vhd \
      peak_descriptor_channel.vhd \
      afe_trigger_bank.vhd \
      legacy_selftrigger_datapath.vhd \
      afe_selftrigger_island.vhd \
      selftrigger_fabric.vhd \
      stc3_record_builder.vhd
    do
      found_dir="$(find_first_file_dir "$WORK_ROOT/src" "$required_leaf")"
      auto_extra_roots="$(append_unique_path "$auto_extra_roots" "$found_dir")"
    done
  fi

  if [ -n "$auto_extra_roots" ]; then
    DAPHNE_IP_EXTRA_SOURCE_ROOTS="$auto_extra_roots"
  fi
fi

export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"
export DAPHNE_FPGA_PART
export DAPHNE_BOARD_PART
export DAPHNE_PFM_NAME
export DAPHNE_GIT_SHA
export DAPHNE_OUTPUT_DIR
if [ -n "${DAPHNE_IP_REPO_ROOT-}" ]; then
  export DAPHNE_IP_REPO_ROOT
fi
if [ -n "${DAPHNE_USER_IP_REPO_PARENT-}" ]; then
  export DAPHNE_USER_IP_REPO_PARENT
fi
if [ -n "${DAPHNE_IP_EXTRA_SOURCE_ROOTS-}" ]; then
  export DAPHNE_IP_EXTRA_SOURCE_ROOTS
fi

cd "$PLATFORM_ROOT/xilinx"

shim_tcl=".daphne-vivado-shim.$$.tcl"
trap 'rm -f "$shim_tcl"' EXIT INT TERM HUP

append_env_tcl() {
  var_name="$1"
  eval "var_value=\${$var_name-}"
  [ -n "$var_value" ] || return 0
  escaped_value=$(printf '%s' "$var_value" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf 'set ::env(%s) "%s"\n' "$var_name" "$escaped_value" >>"$shim_tcl"
}

: >"$shim_tcl"
append_env_tcl DAPHNE_FPGA_PART
append_env_tcl DAPHNE_BOARD_PART
append_env_tcl DAPHNE_PFM_NAME
append_env_tcl DAPHNE_BOARD
append_env_tcl DAPHNE_ETH_MODE
append_env_tcl DAPHNE_GIT_SHA
append_env_tcl DAPHNE_MAX_THREADS
append_env_tcl DAPHNE_OUTPUT_DIR
append_env_tcl DAPHNE_BD_NAME
append_env_tcl DAPHNE_BD_WRAPPER_NAME
append_env_tcl DAPHNE_BUILD_NAME_PREFIX
append_env_tcl DAPHNE_OVERLAY_NAME_PREFIX
append_env_tcl DAPHNE_USER_IP_VLNV
append_env_tcl DAPHNE_IP_TOP_HDL_FILE
append_env_tcl DAPHNE_IP_TOP_MODULE
append_env_tcl DAPHNE_IP_COMPONENT_IDENTIFIER
append_env_tcl DAPHNE_IP_DISPLAY_NAME
append_env_tcl DAPHNE_IP_XGUI_FILE
append_env_tcl DAPHNE_IP_EXTRA_SOURCE_ROOTS
append_env_tcl DAPHNE_IP_REPO_ROOT
append_env_tcl DAPHNE_USER_IP_REPO_PARENT
append_env_tcl DAPHNE_SKIP_POST_SYNTH_REPORTS
append_env_tcl DAPHNE_SKIP_POST_SYNTH_CHECKPOINT
append_env_tcl DAPHNE_SYNTH_DIRECTIVE
append_env_tcl DAPHNE_OPT_DIRECTIVE
append_env_tcl DAPHNE_PLACE_DIRECTIVE
append_env_tcl DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE
append_env_tcl DAPHNE_ROUTE_DIRECTIVE
append_env_tcl DAPHNE_POST_ROUTE_PHYSOPT_DIRECTIVE
append_env_tcl XILINX_VITIS
printf 'set script_dir [file dirname [file normalize [info script]]]\n' >>"$shim_tcl"
printf 'source -notrace [file join $script_dir "vivado_impl_entry.tcl"]\n' >>"$shim_tcl"

exec vivado -mode batch -source "$shim_tcl"
