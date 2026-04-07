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
PACKAGE_DTBO="${DAPHNE_REMOTE_PACKAGE_DTBO:-0}"

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

resolve_output_dir() {
  output_dir_value="${DAPHNE_OUTPUT_DIR-}"
  if [ -z "$output_dir_value" ]; then
    if [ "$FLOW_OWNED_LEGACY_IMPL" = "1" ]; then
      printf '%s\n' "$ROOT_DIR/xilinx/output-$DAPHNE_GIT_SHA"
    else
      printf '%s\n' "$ROOT_DIR/xilinx/output"
    fi
    return 0
  fi

  case "$output_dir_value" in
    /*)
      printf '%s\n' "$output_dir_value"
      ;;
    ./*)
      printf '%s\n' "$ROOT_DIR/xilinx/${output_dir_value#./}"
      ;;
    *)
      printf '%s\n' "$ROOT_DIR/xilinx/$output_dir_value"
      ;;
  esac
}

OUTPUT_DIR="$(resolve_output_dir)"
FLOW_WORK_DIR="$ROOT_DIR/build/dune-daq_daphne_k26c-composable-platform_0.1.0/impl_legacy_flow"

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
  echo "output_dir=$OUTPUT_DIR"
  echo "flow_work_dir=$FLOW_WORK_DIR"
  echo "package_dtbo=$PACKAGE_DTBO"
  echo "vivado=$(command -v vivado)"
  echo "xsct=$(command -v xsct || true)"
} >"$RUN_DIR/run.env"

echo "INFO: Remote Vivado chain"
echo "INFO: branch=$branch_name commit=$commit_sha board=$BOARD eth_mode=$ETH_MODE"
echo "INFO: platform_core=$PLATFORM_CORE platform_target=${PLATFORM_TARGET:-<default>}"
echo "INFO: logs will be written under $RUN_DIR"

run_stage() {
  stage_name="$1"
  log_path="$2"
  shift 2

  (
    cd "$ROOT_DIR"
    "$@"
  ) 2>&1 | tee "$log_path"
}

if [ "$FLOW_OWNED_LEGACY_IMPL" = "1" ]; then
  printf '%s\n' "INFO: Skipping standalone preflight; impl_legacy_flow performs legacy BD/IP preflight inside the Flow API project." | tee "$RUN_DIR/preflight.log"
else
  run_stage preflight "$RUN_DIR/preflight.log" ./scripts/fusesoc/preflight_vivado_build.sh
fi

run_stage build "$RUN_DIR/build.log" ./scripts/fusesoc/run_vivado_batch.sh

if [ "$FLOW_OWNED_LEGACY_IMPL" = "1" ]; then
  run_stage export "$RUN_DIR/export.log" ./scripts/package/export_impl_legacy_flow_bundle.sh "$FLOW_WORK_DIR" "$OUTPUT_DIR"
fi

if [ "$PACKAGE_DTBO" = "1" ]; then
  run_stage package "$RUN_DIR/package.log" ./scripts/package/complete_dtbo_bundle.sh "$OUTPUT_DIR"
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
if [ "$FLOW_OWNED_LEGACY_IMPL" = "1" ]; then
  echo "INFO: Export log: $RUN_DIR/export.log"
fi
if [ "$PACKAGE_DTBO" = "1" ]; then
  echo "INFO: Packaging log: $RUN_DIR/package.log"
fi
echo "INFO: Artifact listing: $RUN_DIR/artifacts.txt"
