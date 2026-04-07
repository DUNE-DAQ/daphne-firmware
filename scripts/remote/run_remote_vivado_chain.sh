#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
ETH_MODE="${DAPHNE_ETH_MODE:-create_ip}"
PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-dune-daq:daphne:k26c-platform:0.1.0}"
PLATFORM_TARGET="${DAPHNE_PLATFORM_TARGET:-}"
LOG_DIR="${DAPHNE_REMOTE_LOG_DIR:-$ROOT_DIR/build/remote-vivado}"
RUN_ID="${DAPHNE_REMOTE_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
RUN_DIR="$LOG_DIR/$RUN_ID"

mkdir -p "$RUN_DIR"

if [ -n "${XILINX_SETTINGS_SH-}" ]; then
  # shellcheck disable=SC1090
  . "$XILINX_SETTINGS_SH"
fi

if [ -n "${XILINX_VITIS_SETTINGS_SH-}" ]; then
  # shellcheck disable=SC1090
  . "$XILINX_VITIS_SETTINGS_SH"
fi

if ! command -v vivado >/dev/null 2>&1; then
  echo "ERROR: vivado is not installed or not on PATH." >&2
  echo "Set XILINX_SETTINGS_SH or source the Vivado environment before running this script." >&2
  exit 2
fi

if ! command -v xsct >/dev/null 2>&1; then
  echo "WARNING: xsct is not on PATH. The build may succeed, but dtbo generation will fail later." >&2
fi

branch_name="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
commit_sha="$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD)"

export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"
export DAPHNE_GIT_SHA="${DAPHNE_GIT_SHA:-$commit_sha}"
export DAPHNE_PLATFORM_CORE="$PLATFORM_CORE"

if [ -z "$PLATFORM_TARGET" ] && [ "$PLATFORM_CORE" = "dune-daq:daphne:k26c-composable-platform:0.1.0" ]; then
  PLATFORM_TARGET="impl_legacy_flow"
fi
if [ -n "$PLATFORM_TARGET" ]; then
  export DAPHNE_PLATFORM_TARGET="$PLATFORM_TARGET"
fi

FLOW_OWNED_LEGACY_IMPL=0
if [ "$PLATFORM_CORE" = "dune-daq:daphne:k26c-composable-platform:0.1.0" ] && [ "$PLATFORM_TARGET" = "impl_legacy_flow" ]; then
  FLOW_OWNED_LEGACY_IMPL=1
fi

{
  echo "run_id=$RUN_ID"
  echo "hostname=$(hostname)"
  echo "branch=$branch_name"
  echo "commit=$commit_sha"
  echo "board=$BOARD"
  echo "eth_mode=$ETH_MODE"
  echo "platform_core=$PLATFORM_CORE"
  echo "platform_target=$PLATFORM_TARGET"
  echo "flow_owned_legacy_impl=$FLOW_OWNED_LEGACY_IMPL"
  echo "root_dir=$ROOT_DIR"
  echo "log_dir=$RUN_DIR"
  echo "vivado=$(command -v vivado)"
  echo "xsct=$(command -v xsct || true)"
} >"$RUN_DIR/run.env"

echo "INFO: Remote Vivado chain"
echo "INFO: branch=$branch_name commit=$commit_sha board=$BOARD eth_mode=$ETH_MODE"
echo "INFO: platform_core=$PLATFORM_CORE platform_target=${PLATFORM_TARGET:-<default>}"
echo "INFO: logs will be written under $RUN_DIR"

if [ "$FLOW_OWNED_LEGACY_IMPL" = "1" ]; then
  printf '%s\n' "INFO: Skipping standalone preflight; impl_legacy_flow performs legacy BD/IP preflight inside the Flow API project." | tee "$RUN_DIR/preflight.log"
else
  (
    cd "$ROOT_DIR"
    ./scripts/fusesoc/preflight_vivado_build.sh
  ) 2>&1 | tee "$RUN_DIR/preflight.log"
fi

(
  cd "$ROOT_DIR"
  ./scripts/fusesoc/run_vivado_batch.sh
) 2>&1 | tee "$RUN_DIR/build.log"

if [ "$FLOW_OWNED_LEGACY_IMPL" = "1" ]; then
  OUTPUT_DIR="$ROOT_DIR/build/dune-daq_daphne_k26c-composable-platform_0.1.0/impl_legacy_flow"
else
  OUTPUT_DIR="${DAPHNE_OUTPUT_DIR:-$ROOT_DIR/xilinx/output}"
fi
{
  echo "output_dir=$OUTPUT_DIR"
  if [ -d "$OUTPUT_DIR" ]; then
    find "$OUTPUT_DIR" -maxdepth 2 -type f | sort
  fi
} >"$RUN_DIR/artifacts.txt"

echo "INFO: Remote Vivado chain completed."
echo "INFO: Preflight log: $RUN_DIR/preflight.log"
echo "INFO: Build log: $RUN_DIR/build.log"
echo "INFO: Artifact listing: $RUN_DIR/artifacts.txt"
