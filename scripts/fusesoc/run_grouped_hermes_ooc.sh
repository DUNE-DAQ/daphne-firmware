#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
CORE="dune-daq:daphne:grouped-hermes-readout-ooc:0.1.0"
SOURCE_COUNT=""

usage() {
  cat <<'EOF'
Usage: run_grouped_hermes_ooc.sh --sources <2|5|10>

Runs the grouped-Hermes Vivado out-of-context measurement target for the
selected logical source count.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sources)
      shift
      [ "$#" -gt 0 ] || {
        echo "ERROR: --sources requires an argument." >&2
        exit 2
      }
      SOURCE_COUNT="$1"
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

case "$SOURCE_COUNT" in
  2) TARGET="synth_src2_ooc" ;;
  5) TARGET="synth_src5_ooc" ;;
  10) TARGET="synth_src10_ooc" ;;
  *)
    echo "ERROR: --sources must be one of 2, 5, or 10." >&2
    usage >&2
    exit 2
    ;;
esac

WORK_ROOT_DEFAULT="$ROOT_DIR/build/grouped-hermes-ooc-src$SOURCE_COUNT"
WORK_ROOT="${DAPHNE_FUSESOC_WORK_ROOT:-$WORK_ROOT_DEFAULT}"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/fusesoc/refresh_cores.sh" >/dev/null

echo "INFO: Running grouped Hermes OOC target '$TARGET'"
echo "INFO: Core: $CORE"
echo "INFO: Work root: $WORK_ROOT"

exec "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" run \
  --setup \
  --build \
  --work-root "$WORK_ROOT" \
  --target "$TARGET" \
  "$CORE"
