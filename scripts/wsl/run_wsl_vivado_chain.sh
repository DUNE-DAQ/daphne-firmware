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
  printf 'run_id=%s\n' "$RUN_ID"
  printf 'kernel=%s\n' "$(uname -r)"
  printf 'branch=%s\n' "$branch_name"
  printf 'commit=%s\n' "$commit_sha"
  printf 'board=%s\n' "$BOARD"
  printf 'eth_mode=%s\n' "$ETH_MODE"
  printf 'root_dir=%s\n' "$ROOT_DIR"
  printf 'log_dir=%s\n' "$RUN_DIR"
  printf 'vivado=%s\n' "$(command -v vivado)"
  printf 'xsct=%s\n' "$(command -v xsct || true)"
  printf 'vivado_bat=%s\n' "$DAPHNE_WSL_VIVADO_BAT"
  printf 'xsct_bat=%s\n' "$DAPHNE_WSL_XSCT_BAT"
  printf 'XILINX_VITIS=%s\n' "${XILINX_VITIS-}"
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
