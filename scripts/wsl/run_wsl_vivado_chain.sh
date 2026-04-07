#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
ETH_MODE="${DAPHNE_ETH_MODE:-create_ip}"
PLATFORM_TARGET="${DAPHNE_PLATFORM_TARGET:-}"
LOG_DIR="${DAPHNE_WSL_LOG_DIR:-$ROOT_DIR/build/wsl-vivado}"
RUN_ID="${DAPHNE_WSL_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
RUN_DIR="$LOG_DIR/$RUN_ID"
PACKAGE_DTBO="${DAPHNE_WSL_PACKAGE_DTBO:-1}"

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"

DEFAULT_CORE="$(daphne_board_manifest_value "$ROOT_DIR" "$BOARD" platform_core)"
DEFAULT_COMPOSABLE_CORE="$(daphne_board_manifest_value "$ROOT_DIR" "$BOARD" composable_platform_core)"
: "${DEFAULT_CORE:=dune-daq:daphne:k26c-platform:0.1.0}"
: "${DEFAULT_COMPOSABLE_CORE:=dune-daq:daphne:k26c-composable-platform:0.1.0}"
PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-$DEFAULT_CORE}"

. "$ROOT_DIR/scripts/wsl/setup_windows_xilinx.sh"

mkdir -p "$RUN_DIR"

branch_name="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
commit_sha="$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD)"

export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"
export DAPHNE_GIT_SHA="${DAPHNE_GIT_SHA:-$commit_sha}"
export DAPHNE_PLATFORM_CORE="$PLATFORM_CORE"

if [ -z "$PLATFORM_TARGET" ] && [ "$PLATFORM_CORE" = "$DEFAULT_COMPOSABLE_CORE" ]; then
  PLATFORM_TARGET="impl"
fi
if [ -n "$PLATFORM_TARGET" ]; then
  export DAPHNE_PLATFORM_TARGET="$PLATFORM_TARGET"
fi

FLOW_OWNED_LEGACY_IMPL=0
if [ "$PLATFORM_CORE" = "$DEFAULT_COMPOSABLE_CORE" ] && { [ "$PLATFORM_TARGET" = "impl_legacy_flow" ] || [ "$PLATFORM_TARGET" = "impl" ]; }; then
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
FLOW_WORK_DIR="$ROOT_DIR/build/$(daphne_platform_core_build_slug "$PLATFORM_CORE")/${PLATFORM_TARGET:-impl}"

{
  printf 'run_id=%s\n' "$RUN_ID"
  printf 'kernel=%s\n' "$(uname -r)"
  printf 'branch=%s\n' "$branch_name"
  printf 'commit=%s\n' "$commit_sha"
  printf 'board=%s\n' "$BOARD"
  printf 'eth_mode=%s\n' "$ETH_MODE"
  printf 'platform_core=%s\n' "$PLATFORM_CORE"
  printf 'platform_target=%s\n' "$PLATFORM_TARGET"
  printf 'flow_owned_legacy_impl=%s\n' "$FLOW_OWNED_LEGACY_IMPL"
  printf 'root_dir=%s\n' "$ROOT_DIR"
  printf 'log_dir=%s\n' "$RUN_DIR"
  printf 'output_dir=%s\n' "$OUTPUT_DIR"
  printf 'flow_work_dir=%s\n' "$FLOW_WORK_DIR"
  printf 'package_dtbo=%s\n' "$PACKAGE_DTBO"
  printf 'vivado=%s\n' "$(command -v vivado)"
  printf 'xsct=%s\n' "$(command -v xsct || true)"
  printf 'vivado_bat=%s\n' "$DAPHNE_WSL_VIVADO_BAT"
  printf 'xsct_bat=%s\n' "$DAPHNE_WSL_XSCT_BAT"
  printf 'XILINX_VITIS=%s\n' "${XILINX_VITIS-}"
} >"$RUN_DIR/run.env"

echo "INFO: WSL Vivado chain"
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

run_stage toolcheck "$RUN_DIR/toolcheck.log" ./scripts/wsl/check_windows_xilinx.sh

if [ "$FLOW_OWNED_LEGACY_IMPL" = "1" ]; then
  printf '%s\n' "INFO: Skipping standalone preflight; impl_legacy_flow performs legacy BD/IP preflight inside the Flow API project." | tee "$RUN_DIR/preflight.log"
else
  run_stage preflight "$RUN_DIR/preflight.log" ./scripts/fusesoc/preflight_vivado_build.sh
fi

run_stage build "$RUN_DIR/build.log" ./scripts/fusesoc/run_vivado_batch.sh

if [ "$PACKAGE_DTBO" = "1" ]; then
  run_stage package "$RUN_DIR/package.log" ./scripts/package/complete_dtbo_bundle.sh "$OUTPUT_DIR"
fi

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
if [ "$PACKAGE_DTBO" = "1" ]; then
  echo "INFO: Packaging log: $RUN_DIR/package.log"
fi
echo "INFO: Artifact listing: $RUN_DIR/artifacts.txt"
