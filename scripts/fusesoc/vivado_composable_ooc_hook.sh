#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLATFORM_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
BOARD="${DAPHNE_BOARD:-k26c}"

. "$PLATFORM_ROOT/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$PLATFORM_ROOT" "$BOARD"

if ! command -v vivado >/dev/null 2>&1; then
  echo "ERROR: vivado is not installed or not on PATH." >&2
  exit 2
fi

cd "$PLATFORM_ROOT"

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
append_env_tcl DAPHNE_CONSTRAINT_FILE
append_env_tcl DAPHNE_CONSTRAINT_FILES
append_env_tcl DAPHNE_TIMING_ENDPOINT_PATH
append_env_tcl DAPHNE_PUBLIC_TOP_HDL_FILE
append_env_tcl DAPHNE_PUBLIC_TOP_MODULE
append_env_tcl DAPHNE_IP_TOP_HDL_FILE
append_env_tcl DAPHNE_IP_TOP_MODULE
append_env_tcl DAPHNE_GIT_SHA
append_env_tcl DAPHNE_MAX_THREADS
append_env_tcl DAPHNE_OUTPUT_DIR
printf 'set script_dir [file dirname [file normalize [info script]]]\n' >>"$shim_tcl"
printf 'source -notrace [file join $script_dir "xilinx" "daphne_composable_ooc_entry.tcl"]\n' >>"$shim_tcl"

exec vivado -mode batch -source "$shim_tcl"
