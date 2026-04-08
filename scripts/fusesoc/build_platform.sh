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
DEFAULT_PLATFORM_TARGET="$(daphne_default_platform_target "$ROOT_DIR" "$BOARD" "$DEFAULT_PLATFORM_CORE")"

: "${DEFAULT_CORE:=dune-daq:daphne:k26c-platform:0.1.0}"
: "${DEFAULT_MODULAR_CORE:=dune-daq:daphne:k26c-modular-platform:0.1.0}"
: "${DEFAULT_COMPOSABLE_CORE:=dune-daq:daphne:k26c-composable-platform:0.1.0}"
: "${DEFAULT_PLATFORM_CORE:=$DEFAULT_COMPOSABLE_CORE}"
: "${DEFAULT_PLATFORM_TARGET:=impl}"

DRY_RUN=0
PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-$DEFAULT_PLATFORM_CORE}"
BUILD_TARGET="${DAPHNE_PLATFORM_TARGET:-}"
AUDIT_NATIVE_IMPL_GRAPH="${DAPHNE_AUDIT_NATIVE_IMPL_GRAPH:-1}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Build the DAPHNE firmware through the repo-local FuseSoC platform layer.

Options:
  --platform-core <VLNV>  Use an explicit platform core
  --modular               Use $DEFAULT_MODULAR_CORE
  --composable            Use $DEFAULT_COMPOSABLE_CORE
  --target <name>         Use an explicit FuseSoC target for the selected platform core
  --skip-native-audit     Skip the native composable impl graph audit before build
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
    --skip-native-audit)
      AUDIT_NATIVE_IMPL_GRAPH=0
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
  BUILD_TARGET="$(daphne_default_platform_target "$ROOT_DIR" "$BOARD" "$PLATFORM_CORE")"
fi

if [ "$PLATFORM_CORE" = "$DEFAULT_PLATFORM_CORE" ] && [ "$BUILD_TARGET" = "impl_legacy_flow" ]; then
  echo "ERROR: target 'impl_legacy_flow' has been retired." >&2
  echo "Use '--composable --target impl' for the native board-shell implementation path." >&2
  exit 2
fi

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
export DAPHNE_AUDIT_NATIVE_IMPL_GRAPH="$AUDIT_NATIVE_IMPL_GRAPH"
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

if [ "$PLATFORM_CORE" = "$DEFAULT_PLATFORM_CORE" ] && \
   [ "$BUILD_TARGET" = "$DEFAULT_PLATFORM_TARGET" ] && \
   [ "$AUDIT_NATIVE_IMPL_GRAPH" != "0" ]; then
  echo "INFO: Auditing native impl graph before build."
  "$ROOT_DIR/scripts/fusesoc/check_native_impl_graph.sh"
fi

exec "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" run \
  --setup \
  --build \
  --work-root "$FLOW_WORK_DIR" \
  --system-name "$SYSTEM_NAME" \
  --target "$BUILD_TARGET" \
  "$PLATFORM_CORE"
