#!/bin/sh
set -eu

WORK_ROOT="${PWD}"
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

export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"
export DAPHNE_FPGA_PART
export DAPHNE_BOARD_PART
export DAPHNE_PFM_NAME
export DAPHNE_GIT_SHA
export DAPHNE_OUTPUT_DIR

cd "$WORK_ROOT/xilinx"

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
