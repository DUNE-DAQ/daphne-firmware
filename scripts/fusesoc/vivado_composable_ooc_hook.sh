#!/bin/sh
set -eu

WORK_ROOT="${PWD}"
BOARD="${DAPHNE_BOARD:-k26c}"

case "$BOARD" in
  k26c)
    : "${DAPHNE_FPGA_PART:=xck26-sfvc784-2LV-c}"
    : "${DAPHNE_BOARD_PART:=xilinx.com:k26c:part0:1.4}"
    ;;
  *)
    echo "ERROR: unsupported board '$BOARD' for composable OOC synthesis." >&2
    exit 2
    ;;
esac

if ! command -v vivado >/dev/null 2>&1; then
  echo "ERROR: vivado is not installed or not on PATH." >&2
  exit 2
fi

cd "$WORK_ROOT"

shim_tcl=".daphne-composable-ooc-shim.$$.tcl"
trap 'rm -f "$shim_tcl"' EXIT INT TERM HUP

append_env_tcl() {
  var_name="$1"
  eval "var_value=\${$var_name-}"
  [ -n "$var_value" ] || return 0
  escaped_value=$(printf '%s' "$var_value" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf 'set ::env(%s) "%s"\n' "$var_name" "$escaped_value" >>"$shim_tcl"
}

: >"$shim_tcl"
append_env_tcl DAPHNE_BOARD
append_env_tcl DAPHNE_FPGA_PART
append_env_tcl DAPHNE_BOARD_PART
append_env_tcl DAPHNE_GIT_SHA
append_env_tcl DAPHNE_MAX_THREADS
append_env_tcl DAPHNE_OUTPUT_DIR
printf 'set script_dir [file dirname [file normalize [info script]]]\n' >>"$shim_tcl"
printf 'source -notrace [file join $script_dir "xilinx" "daphne_composable_ooc_entry.tcl"]\n' >>"$shim_tcl"

exec vivado -mode batch -source "$shim_tcl"
