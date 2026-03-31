#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
DEFAULT_CORE="dune-daq:daphne:k26c-platform:0.1.0"
DEFAULT_MODULAR_CORE="dune-daq:daphne:k26c-modular-platform:0.1.0"

DRY_RUN=0
PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-$DEFAULT_CORE}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Build the DAPHNE firmware through the repo-local FuseSoC platform layer.

Options:
  --platform-core <VLNV>  Use an explicit platform core
  --modular               Use $DEFAULT_MODULAR_CORE
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
  dune-daq:daphne:k26c-platform:0.1.0|dune-daq:daphne:k26c-modular-platform:0.1.0)
    BOARD="k26c"
    ;;
  *)
    echo "ERROR: unsupported platform core '$PLATFORM_CORE'." >&2
    echo "Supported cores today are:" >&2
    echo "  $DEFAULT_CORE" >&2
    echo "  $DEFAULT_MODULAR_CORE" >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/fusesoc/refresh_cores.sh" >/dev/null
"$ROOT_DIR/scripts/fusesoc/fusesoc.sh" core-info "$PLATFORM_CORE" >/dev/null

echo "INFO: Selected FuseSoC platform core: $PLATFORM_CORE"
echo "INFO: Resolved board profile: $BOARD"
echo "INFO: Build mode: impl"

export DAPHNE_BOARD="$BOARD"
export DAPHNE_PLATFORM_CORE="$PLATFORM_CORE"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "INFO: Dry-run only, stopping before Vivado."
  exit 0
fi

exec "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" run \
  --setup \
  --build \
  --target impl \
  "$PLATFORM_CORE"
