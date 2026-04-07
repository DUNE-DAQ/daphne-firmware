#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"

DEFAULT_CORE="$(daphne_board_manifest_value "$ROOT_DIR" "$BOARD" platform_core)"
DEFAULT_MODULAR_CORE="$(daphne_board_manifest_value "$ROOT_DIR" "$BOARD" modular_platform_core)"
DEFAULT_COMPOSABLE_CORE="$(daphne_board_manifest_value "$ROOT_DIR" "$BOARD" composable_platform_core)"
DEFAULT_PLATFORM_CORE="$(daphne_default_platform_core "$ROOT_DIR" "$BOARD")"
DEFAULT_COMPOSABLE_TARGET="$(daphne_board_manifest_value "$ROOT_DIR" "$BOARD" composable_default_target)"

: "${DEFAULT_CORE:=dune-daq:daphne:k26c-platform:0.1.0}"
: "${DEFAULT_MODULAR_CORE:=dune-daq:daphne:k26c-modular-platform:0.1.0}"
: "${DEFAULT_COMPOSABLE_CORE:=dune-daq:daphne:k26c-composable-platform:0.1.0}"
: "${DEFAULT_PLATFORM_CORE:=$DEFAULT_COMPOSABLE_CORE}"
: "${DEFAULT_COMPOSABLE_TARGET:=impl}"

DRY_RUN=0
PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-$DEFAULT_PLATFORM_CORE}"
BUILD_TARGET="${DAPHNE_PLATFORM_TARGET:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Build the DAPHNE firmware through the repo-local FuseSoC platform layer.

Options:
  --platform-core <VLNV>  Use an explicit platform core
  --modular               Use $DEFAULT_MODULAR_CORE
  --composable            Use $DEFAULT_COMPOSABLE_CORE
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
    --modular)
      PLATFORM_CORE="$DEFAULT_MODULAR_CORE"
      ;;
    --composable)
      PLATFORM_CORE="$DEFAULT_COMPOSABLE_CORE"
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

case "$PLATFORM_CORE" in
  "$DEFAULT_CORE"|"$DEFAULT_MODULAR_CORE"|"$DEFAULT_COMPOSABLE_CORE")
    ;;
  *)
    echo "ERROR: unsupported platform core '$PLATFORM_CORE'." >&2
    echo "Supported cores today are:" >&2
    echo "  $DEFAULT_CORE" >&2
    echo "  $DEFAULT_MODULAR_CORE" >&2
    echo "  $DEFAULT_COMPOSABLE_CORE" >&2
    exit 2
    ;;
esac

if [ -z "$BUILD_TARGET" ]; then
  case "$PLATFORM_CORE" in
    "$DEFAULT_COMPOSABLE_CORE")
      BUILD_TARGET="$DEFAULT_COMPOSABLE_TARGET"
      ;;
    *)
      BUILD_TARGET="impl"
      ;;
  esac
fi

if [ "$PLATFORM_CORE" = "$DEFAULT_COMPOSABLE_CORE" ] && [ "$BUILD_TARGET" = "impl_legacy_flow" ]; then
  BUILD_TARGET="impl"
fi

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/fusesoc/refresh_cores.sh" >/dev/null
"$ROOT_DIR/scripts/fusesoc/fusesoc.sh" core-info "$PLATFORM_CORE" >/dev/null

echo "INFO: Selected FuseSoC platform core: $PLATFORM_CORE"
echo "INFO: Resolved board profile: $BOARD"
echo "INFO: Selected FuseSoC target: $BUILD_TARGET"

export DAPHNE_BOARD="$BOARD"
export DAPHNE_PLATFORM_CORE="$PLATFORM_CORE"
export DAPHNE_PLATFORM_TARGET="$BUILD_TARGET"

SYSTEM_NAME="${DAPHNE_SYSTEM_NAME:-$(daphne_platform_core_build_slug "$PLATFORM_CORE")}"
export DAPHNE_SYSTEM_NAME="$SYSTEM_NAME"
: "${DAPHNE_EXPORT_PROJECT_XPR:=${SYSTEM_NAME}.xpr}"
: "${DAPHNE_EXPORT_IMPL_RUN:=impl_1}"
export DAPHNE_EXPORT_PROJECT_XPR
export DAPHNE_EXPORT_IMPL_RUN

if [ "$DRY_RUN" -eq 1 ]; then
  echo "INFO: Dry-run only, stopping before Vivado."
  exit 0
fi

exec "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" run \
  --setup \
  --build \
  --target "$BUILD_TARGET" \
  "$PLATFORM_CORE"
