#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
ETH_MODE="${DAPHNE_ETH_MODE:-create_ip}"
LOG_DIR="${DAPHNE_WSL_LOG_DIR:-$ROOT_DIR/build/wsl-vivado}"
RUN_ID="${DAPHNE_WSL_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
RUN_DIR="$LOG_DIR/$RUN_ID"

. "$ROOT_DIR/scripts/wsl/setup_windows_xilinx.sh"

mkdir -p "$RUN_DIR"

branch_name="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
commit_sha="$(git -C "$ROOT_DIR" rev-parse --short HEAD)"

export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"

{
  echo "run_id=$RUN_ID"
  echo "kernel=$(uname -r)"
  echo "branch=$branch_name"
  echo "commit=$commit_sha"
  echo "board=$BOARD"
  echo "eth_mode=$ETH_MODE"
  echo "root_dir=$ROOT_DIR"
  echo "log_dir=$RUN_DIR"
  echo "vivado=$(command -v vivado)"
  echo "xsct=$(command -v xsct || true)"
  echo "vivado_bat=$DAPHNE_WSL_VIVADO_BAT"
  echo "xsct_bat=$DAPHNE_WSL_XSCT_BAT"
  echo "XILINX_VITIS=${XILINX_VITIS-}"
} >"$RUN_DIR/run.env"

echo "INFO: WSL Vivado chain"
echo "INFO: branch=$branch_name commit=$commit_sha board=$BOARD eth_mode=$ETH_MODE"
echo "INFO: logs will be written under $RUN_DIR"

(
  cd "$ROOT_DIR"
  ./scripts/wsl/check_windows_xilinx.sh
) 2>&1 | tee "$RUN_DIR/toolcheck.log"

(
  cd "$ROOT_DIR"
  ./scripts/fusesoc/preflight_vivado_build.sh
) 2>&1 | tee "$RUN_DIR/preflight.log"

(
  cd "$ROOT_DIR"
  ./scripts/fusesoc/run_vivado_batch.sh
) 2>&1 | tee "$RUN_DIR/build.log"

OUTPUT_DIR="${DAPHNE_OUTPUT_DIR:-$ROOT_DIR/xilinx/output}"
{
  echo "output_dir=$OUTPUT_DIR"
  if [ -d "$OUTPUT_DIR" ]; then
    find "$OUTPUT_DIR" -maxdepth 2 -type f | sort
  fi
} >"$RUN_DIR/artifacts.txt"

echo "INFO: WSL Vivado chain completed."
echo "INFO: Tool check log: $RUN_DIR/toolcheck.log"
echo "INFO: Preflight log: $RUN_DIR/preflight.log"
echo "INFO: Build log: $RUN_DIR/build.log"
echo "INFO: Artifact listing: $RUN_DIR/artifacts.txt"
