#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"

DEFAULT_PLATFORM_CORE="$(daphne_default_platform_core "$ROOT_DIR" "$BOARD")"
DEFAULT_PLATFORM_TARGET="$(daphne_default_platform_target "$ROOT_DIR" "$BOARD" "$DEFAULT_PLATFORM_CORE")"

: "${DEFAULT_PLATFORM_CORE:=dune-daq:daphne:k26c-composable-platform:0.1.0}"
: "${DEFAULT_PLATFORM_TARGET:=impl}"

DRY_RUN=0
PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-$DEFAULT_PLATFORM_CORE}"
BUILD_TARGET="${DAPHNE_PLATFORM_TARGET:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Build the DAPHNE firmware through the repo-local FuseSoC platform layer.

Options:
  --platform-core <VLNV>  Override the supported platform core (must stay $DEFAULT_PLATFORM_CORE)
  --target <name>         Use an explicit FuseSoC target for the selected platform core
  --dry-run               Resolve the platform core and print what would run
  -h, --help              Show this help text
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform-core)
      shift
      [ "$#" -gt 0 ] || {
        echo "ERROR: --platform-core requires a VLNV argument." >&2
        exit 2
      }
      PLATFORM_CORE="$1"
      ;;
    --target)
      shift
      [ "$#" -gt 0 ] || {
        echo "ERROR: --target requires a target name." >&2
        exit 2
      }
      BUILD_TARGET="$1"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument '$1'." >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

daphne_require_supported_platform_core "$ROOT_DIR" "$BOARD" "$PLATFORM_CORE"

if [ -z "$BUILD_TARGET" ]; then
  BUILD_TARGET="$(daphne_default_platform_target "$ROOT_DIR" "$BOARD" "$PLATFORM_CORE")"
fi

daphne_require_supported_platform_target "$ROOT_DIR" "$BOARD" "$PLATFORM_CORE" "$BUILD_TARGET"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/fusesoc/refresh_cores.sh" >/dev/null
"$ROOT_DIR/scripts/fusesoc/fusesoc.sh" core-info "$PLATFORM_CORE" >/dev/null

SYSTEM_NAME="${DAPHNE_SYSTEM_NAME:-$(daphne_platform_system_name "$PLATFORM_CORE")}"
FLOW_WORK_DIR="${DAPHNE_FUSESOC_WORK_ROOT:-$(daphne_platform_flow_work_dir "$ROOT_DIR" "$PLATFORM_CORE" "$BUILD_TARGET" "$SYSTEM_NAME")}"

echo "INFO: Selected FuseSoC platform core: $PLATFORM_CORE"
echo "INFO: Resolved board profile: $BOARD"
echo "INFO: Selected FuseSoC target: $BUILD_TARGET"
echo "INFO: Selected FuseSoC system name: $SYSTEM_NAME"
echo "INFO: Selected FuseSoC work root: $FLOW_WORK_DIR"

export DAPHNE_BOARD="$BOARD"
export DAPHNE_PLATFORM_CORE="$PLATFORM_CORE"
export DAPHNE_PLATFORM_TARGET="$BUILD_TARGET"
export DAPHNE_SYSTEM_NAME="$SYSTEM_NAME"
export DAPHNE_FUSESOC_WORK_ROOT="$FLOW_WORK_DIR"
: "${DAPHNE_EXPORT_PROJECT_XPR:=${SYSTEM_NAME}.xpr}"
: "${DAPHNE_EXPORT_IMPL_RUN:=impl_1}"
export DAPHNE_EXPORT_PROJECT_XPR
export DAPHNE_EXPORT_IMPL_RUN

if [ "$DRY_RUN" -eq 1 ]; then
  echo "INFO: Dry-run only, stopping before Vivado."
  exit 0
fi

if daphne_platform_requires_packaged_ip_preflight "$ROOT_DIR" "$BOARD" "$PLATFORM_CORE" "$BUILD_TARGET"; then
  echo "INFO: Running packaged-IP preflight before native build."
  "$ROOT_DIR/scripts/fusesoc/preflight_vivado_build.sh"
  export DAPHNE_PACKAGED_IP_PREFLIGHT_DONE=1
fi

if daphne_platform_exports_flow_bundle "$ROOT_DIR" "$BOARD" "$PLATFORM_CORE" "$BUILD_TARGET"; then
  echo "INFO: Checking board timing-path defaults and AFE timing constraint contract."
  "$ROOT_DIR/scripts/fusesoc/check_board_timing_path_contract.sh"
  "$ROOT_DIR/scripts/fusesoc/check_afe_timing_constraint_contract.sh"
  "$ROOT_DIR/scripts/fusesoc/check_frontend_clock_contract.sh"
  echo "INFO: Running BD-backed Vivado batch implementation for the board-complete platform target."
  exec "$ROOT_DIR/scripts/fusesoc/vivado_batch_hook.sh"
fi

exec "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" run \
  --setup \
  --build \
  --work-root "$FLOW_WORK_DIR" \
  --system-name "$SYSTEM_NAME" \
  --target "$BUILD_TARGET" \
  "$PLATFORM_CORE"
