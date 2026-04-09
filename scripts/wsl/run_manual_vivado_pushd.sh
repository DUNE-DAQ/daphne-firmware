#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
usage: run_manual_vivado_pushd.sh [preflight|build|all]

Runs the stable WSL-to-Windows Vivado path for this host by:
1. resolving the current repo git SHA;
2. writing xilinx/.manual-preflight.tcl and xilinx/.manual-build.tcl;
3. launching Vivado through cmd.exe /c "pushd ... && vivado.bat ...".

Environment overrides:
  DAPHNE_BOARD                         default: k26c
  DAPHNE_ETH_MODE                      default: create_ip
  DAPHNE_GIT_SHA                       default: git rev-parse --short=7 HEAD
  DAPHNE_OUTPUT_DIR                    default: ./output-$DAPHNE_GIT_SHA
  DAPHNE_MAX_THREADS                   default: 12
  DAPHNE_SKIP_POST_SYNTH_REPORTS       default: 1
  DAPHNE_SKIP_POST_SYNTH_CHECKPOINT    default: 1
  DAPHNE_SKIP_POST_PLACE_CHECKPOINT    default: 0
  DAPHNE_STOP_AFTER_SYNTH              default: 0
  DAPHNE_DUMP_POST_SYNTH_DEBUG         default: DAPHNE_STOP_AFTER_SYNTH
  DAPHNE_PRE_PLACE_POWER_OPT           default: 0
  DAPHNE_POST_PLACE_POWER_OPT          default: 0
  DAPHNE_DTG_GIT_BRANCH                default: xlnx_rel_v$DAPHNE_VITIS_VERSION
  DAPHNE_WINDOWS_XILINX_ROOT           default: /mnt/c/Xilinx
  DAPHNE_VIVADO_VERSION                default: 2024.1
  DAPHNE_VITIS_VERSION                 default: DAPHNE_VIVADO_VERSION
  DAPHNE_WSL_WINDOWS_CMD_CWD           default: /mnt/c/Windows/System32
EOF
}

MODE="${1:-all}"
case "$MODE" in
  preflight|build|all) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
XILINX_DIR="$ROOT_DIR/xilinx"
PRE_TCL="$XILINX_DIR/.manual-preflight.tcl"
BUILD_TCL="$XILINX_DIR/.manual-build.tcl"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 2
  fi
}

require_path() {
  if [ ! -e "$1" ]; then
    echo "ERROR: required path not found: $1" >&2
    exit 2
  fi
}

tcl_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

require_cmd cmd.exe
require_cmd git
require_cmd sed
require_cmd wslpath

: "${DAPHNE_BOARD:=k26c}"
: "${DAPHNE_ETH_MODE:=create_ip}"

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$DAPHNE_BOARD"

if [ "$DAPHNE_ETH_MODE" != "create_ip" ]; then
  echo "ERROR: DAPHNE_ETH_MODE must be create_ip for the current WSL/Windows Vivado path." >&2
  exit 2
fi

: "${DAPHNE_WINDOWS_XILINX_ROOT:=/mnt/c/Xilinx}"
: "${DAPHNE_VIVADO_VERSION:=2024.1}"
: "${DAPHNE_VITIS_VERSION:=$DAPHNE_VIVADO_VERSION}"
: "${DAPHNE_MAX_THREADS:=12}"
: "${DAPHNE_SKIP_POST_SYNTH_REPORTS:=1}"
: "${DAPHNE_SKIP_POST_SYNTH_CHECKPOINT:=1}"
: "${DAPHNE_SKIP_POST_PLACE_CHECKPOINT:=0}"
: "${DAPHNE_STOP_AFTER_SYNTH:=0}"
: "${DAPHNE_DUMP_POST_SYNTH_DEBUG:=$DAPHNE_STOP_AFTER_SYNTH}"
: "${DAPHNE_PRE_PLACE_POWER_OPT:=0}"
: "${DAPHNE_POST_PLACE_POWER_OPT:=0}"
: "${DAPHNE_DTG_GIT_BRANCH:=xlnx_rel_v$DAPHNE_VITIS_VERSION}"
: "${DAPHNE_WSL_WINDOWS_CMD_CWD:=/mnt/c/Windows/System32}"

if [ -z "${DAPHNE_GIT_SHA-}" ]; then
  DAPHNE_GIT_SHA="$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD)"
fi
export DAPHNE_GIT_SHA

: "${DAPHNE_OUTPUT_DIR:=./output-$DAPHNE_GIT_SHA}"

VIVADO_BAT_WSL="$DAPHNE_WINDOWS_XILINX_ROOT/Vivado/$DAPHNE_VIVADO_VERSION/bin/vivado.bat"
VITIS_ROOT_WSL="$DAPHNE_WINDOWS_XILINX_ROOT/Vitis/$DAPHNE_VITIS_VERSION"

require_path "$ROOT_DIR/.git"
require_path "$XILINX_DIR"
require_path "$VIVADO_BAT_WSL"
require_path "$VITIS_ROOT_WSL"
require_path "$DAPHNE_WSL_WINDOWS_CMD_CWD"

XILINX_DIR_WIN="$(wslpath -w "$XILINX_DIR")"
VIVADO_BAT_WIN="$(wslpath -w "$VIVADO_BAT_WSL")"
VITIS_ROOT_WIN="$(wslpath -w "$VITIS_ROOT_WSL")"

SCRIPT_DIR_TCL="$(tcl_escape "$XILINX_DIR_WIN")"
FPGA_PART_TCL="$(tcl_escape "$DAPHNE_FPGA_PART")"
BOARD_PART_TCL="$(tcl_escape "$DAPHNE_BOARD_PART")"
PFM_NAME_TCL="$(tcl_escape "$DAPHNE_PFM_NAME")"
CONSTRAINT_FILE_TCL="$(tcl_escape "$DAPHNE_CONSTRAINT_FILE")"
CONSTRAINT_FILES_TCL="$(tcl_escape "${DAPHNE_CONSTRAINT_FILES:-$DAPHNE_CONSTRAINT_FILE}")"
TIMING_ENDPOINT_PATH_TCL="$(tcl_escape "${DAPHNE_TIMING_ENDPOINT_PATH-}")"
TIMING_PLANE_PATH_TCL="$(tcl_escape "${DAPHNE_TIMING_PLANE_PATH-}")"
BOARD_TCL="$(tcl_escape "$DAPHNE_BOARD")"
ETH_MODE_TCL="$(tcl_escape "$DAPHNE_ETH_MODE")"
GIT_SHA_TCL="$(tcl_escape "$DAPHNE_GIT_SHA")"
OUTPUT_DIR_TCL="$(tcl_escape "$DAPHNE_OUTPUT_DIR")"
MAX_THREADS_TCL="$(tcl_escape "$DAPHNE_MAX_THREADS")"
SKIP_REPORTS_TCL="$(tcl_escape "$DAPHNE_SKIP_POST_SYNTH_REPORTS")"
SKIP_CHECKPOINT_TCL="$(tcl_escape "$DAPHNE_SKIP_POST_SYNTH_CHECKPOINT")"
SKIP_POST_PLACE_CHECKPOINT_TCL="$(tcl_escape "$DAPHNE_SKIP_POST_PLACE_CHECKPOINT")"
STOP_AFTER_SYNTH_TCL="$(tcl_escape "$DAPHNE_STOP_AFTER_SYNTH")"
DUMP_POST_SYNTH_DEBUG_TCL="$(tcl_escape "$DAPHNE_DUMP_POST_SYNTH_DEBUG")"
PRE_PLACE_POWER_OPT_TCL="$(tcl_escape "$DAPHNE_PRE_PLACE_POWER_OPT")"
POST_PLACE_POWER_OPT_TCL="$(tcl_escape "$DAPHNE_POST_PLACE_POWER_OPT")"
DTG_GIT_BRANCH_TCL="$(tcl_escape "$DAPHNE_DTG_GIT_BRANCH")"
VITIS_ROOT_TCL="$(tcl_escape "$VITIS_ROOT_WIN")"

write_preflight_tcl() {
  cat >"$PRE_TCL" <<EOF
set script_dir "$SCRIPT_DIR_TCL"
create_project -in_memory -part "$FPGA_PART_TCL"
set ::env(DAPHNE_FPGA_PART) "$FPGA_PART_TCL"
set ::env(DAPHNE_BOARD_PART) "$BOARD_PART_TCL"
set ::env(DAPHNE_PFM_NAME) "$PFM_NAME_TCL"
set ::env(DAPHNE_CONSTRAINT_FILE) "$CONSTRAINT_FILE_TCL"
set ::env(DAPHNE_CONSTRAINT_FILES) "$CONSTRAINT_FILES_TCL"
set ::env(DAPHNE_TIMING_ENDPOINT_PATH) "$TIMING_ENDPOINT_PATH_TCL"
set ::env(DAPHNE_TIMING_PLANE_PATH) "$TIMING_PLANE_PATH_TCL"
set ::env(DAPHNE_BOARD) "$BOARD_TCL"
set ::env(DAPHNE_ETH_MODE) "$ETH_MODE_TCL"
set ::env(DAPHNE_GIT_SHA) "$GIT_SHA_TCL"
source -notrace [file join \$script_dir "daphne_ip_gen.tcl"]
exit
EOF
}

write_build_tcl() {
  cat >"$BUILD_TCL" <<EOF
set script_dir "$SCRIPT_DIR_TCL"
set ::env(DAPHNE_FPGA_PART) "$FPGA_PART_TCL"
set ::env(DAPHNE_BOARD_PART) "$BOARD_PART_TCL"
set ::env(DAPHNE_PFM_NAME) "$PFM_NAME_TCL"
set ::env(DAPHNE_CONSTRAINT_FILE) "$CONSTRAINT_FILE_TCL"
set ::env(DAPHNE_CONSTRAINT_FILES) "$CONSTRAINT_FILES_TCL"
set ::env(DAPHNE_TIMING_ENDPOINT_PATH) "$TIMING_ENDPOINT_PATH_TCL"
set ::env(DAPHNE_TIMING_PLANE_PATH) "$TIMING_PLANE_PATH_TCL"
set ::env(DAPHNE_BOARD) "$BOARD_TCL"
set ::env(DAPHNE_ETH_MODE) "$ETH_MODE_TCL"
set ::env(DAPHNE_GIT_SHA) "$GIT_SHA_TCL"
set ::env(DAPHNE_OUTPUT_DIR) "$OUTPUT_DIR_TCL"
set ::env(DAPHNE_MAX_THREADS) "$MAX_THREADS_TCL"
set ::env(DAPHNE_SKIP_POST_SYNTH_REPORTS) "$SKIP_REPORTS_TCL"
set ::env(DAPHNE_SKIP_POST_SYNTH_CHECKPOINT) "$SKIP_CHECKPOINT_TCL"
set ::env(DAPHNE_SKIP_POST_PLACE_CHECKPOINT) "$SKIP_POST_PLACE_CHECKPOINT_TCL"
set ::env(DAPHNE_STOP_AFTER_SYNTH) "$STOP_AFTER_SYNTH_TCL"
set ::env(DAPHNE_DUMP_POST_SYNTH_DEBUG) "$DUMP_POST_SYNTH_DEBUG_TCL"
set ::env(DAPHNE_PRE_PLACE_POWER_OPT) "$PRE_PLACE_POWER_OPT_TCL"
set ::env(DAPHNE_POST_PLACE_POWER_OPT) "$POST_PLACE_POWER_OPT_TCL"
set ::env(DAPHNE_VITIS_VERSION) "$DAPHNE_VITIS_VERSION"
set ::env(DAPHNE_DTG_GIT_BRANCH) "$DTG_GIT_BRANCH_TCL"
set ::env(XILINX_VITIS) "$VITIS_ROOT_TCL"
source -notrace [file join \$script_dir "vivado_batch.tcl"]
EOF
}

run_vivado_tcl() {
  tcl_name="$1"
  echo "INFO: Launching $tcl_name through cmd.exe /c pushd..."
  (
    cd "$DAPHNE_WSL_WINDOWS_CMD_CWD"
    cmd.exe /c "pushd $XILINX_DIR_WIN && $VIVADO_BAT_WIN -mode batch -source $tcl_name && popd"
  )
}

confirm_preflight_outputs() {
  ip_repo_root="$(daphne_resolve_ip_repo_root "$ROOT_DIR")" || {
    echo "ERROR: could not resolve DAPHNE IP repo root." >&2
    exit 2
  }
  component_xml="$ip_repo_root/component.xml"
  eth_xci="$ip_repo_root/src/dune.daq_user_hermes_daphne_1.0/src/xxv_ethernet_0/xxv_ethernet_0.xci"
  bram_xci="$ip_repo_root/src/dune.daq_user_hermes_daphne_1.0/src/axi4_lite_bram_ctrl_0/axi4_lite_bram_ctrl_0.xci"

  if [ ! -f "$component_xml" ]; then
    echo "ERROR: expected packaged component.xml at $component_xml" >&2
    exit 2
  fi

  if [ ! -f "$eth_xci" ]; then
    echo "ERROR: expected Ethernet XCI at $eth_xci" >&2
    exit 2
  fi

  if [ ! -f "$bram_xci" ]; then
    echo "ERROR: expected AXI BRAM XCI at $bram_xci" >&2
    exit 2
  fi

  echo "INFO: Preflight outputs present:"
  ls -l "$component_xml"
  ls -l "$eth_xci"
  ls -l "$bram_xci"
}

write_preflight_tcl
write_build_tcl

echo "INFO: repo_root=$ROOT_DIR"
echo "INFO: git_sha=$DAPHNE_GIT_SHA"
echo "INFO: output_dir=$DAPHNE_OUTPUT_DIR"
echo "INFO: xilinx_dir_win=$XILINX_DIR_WIN"
echo "INFO: vivado_bat=$VIVADO_BAT_WIN"

case "$MODE" in
  preflight)
    run_vivado_tcl ".manual-preflight.tcl"
    confirm_preflight_outputs
    ;;
  build)
    run_vivado_tcl ".manual-build.tcl"
    ;;
  all)
    run_vivado_tcl ".manual-preflight.tcl"
    confirm_preflight_outputs
    run_vivado_tcl ".manual-build.tcl"
    ;;
esac
