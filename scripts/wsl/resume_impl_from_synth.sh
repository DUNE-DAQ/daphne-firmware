#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"
. "$ROOT_DIR/scripts/wsl/setup_windows_xilinx.sh"

if ! command -v vivado >/dev/null 2>&1; then
  echo "ERROR: vivado is not available on PATH after loading the Windows wrapper." >&2
  exit 2
fi

if [ -z "${DAPHNE_GIT_SHA-}" ] && command -v git >/dev/null 2>&1; then
  if resolved_git_sha=$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD 2>/dev/null); then
    export DAPHNE_GIT_SHA="$resolved_git_sha"
  fi
fi

if [ -z "${DAPHNE_GIT_SHA-}" ]; then
  echo "ERROR: DAPHNE_GIT_SHA is not set and could not be derived from git." >&2
  exit 2
fi

case "$DAPHNE_GIT_SHA" in
  *[!0-9a-fA-F]*|'')
    echo "ERROR: DAPHNE_GIT_SHA must be hexadecimal because the BD version generic uses 28'h<sha>." >&2
    echo "ERROR: Current value: $DAPHNE_GIT_SHA" >&2
    exit 2
    ;;
esac

export DAPHNE_BOARD="$BOARD"
export DAPHNE_GIT_SHA
: "${DAPHNE_OUTPUT_DIR:=./output-$DAPHNE_GIT_SHA}"
export DAPHNE_OUTPUT_DIR

if [ -z "${DAPHNE_PLATFORM_CORE-}" ]; then
  DAPHNE_PLATFORM_CORE="$(daphne_default_platform_core "$ROOT_DIR" "$BOARD")"
  export DAPHNE_PLATFORM_CORE
fi

if [ -z "${DAPHNE_PLATFORM_TARGET-}" ]; then
  DAPHNE_PLATFORM_TARGET="$(daphne_default_platform_target "$ROOT_DIR" "$BOARD" "$DAPHNE_PLATFORM_CORE")"
  export DAPHNE_PLATFORM_TARGET
fi

OUTPUT_DIR="$DAPHNE_OUTPUT_DIR"
case "$OUTPUT_DIR" in
  /*) ;;
  ./*) OUTPUT_DIR="$ROOT_DIR/xilinx/${OUTPUT_DIR#./}" ;;
  *) OUTPUT_DIR="$ROOT_DIR/xilinx/$OUTPUT_DIR" ;;
esac

SYNTH_DCP="$OUTPUT_DIR/${DAPHNE_BD_NAME:-daphne_selftrigger_bd}_synth.dcp"
if [ ! -f "$SYNTH_DCP" ]; then
  echo "ERROR: synth checkpoint not found: $SYNTH_DCP" >&2
  exit 2
fi

echo "INFO: Repo root        = $ROOT_DIR"
echo "INFO: Board            = $DAPHNE_BOARD"
echo "INFO: Git SHA          = $DAPHNE_GIT_SHA"
echo "INFO: Output dir       = $OUTPUT_DIR"
echo "INFO: Synth checkpoint = $SYNTH_DCP"
echo "INFO: Resuming implementation from synth checkpoint."

cd "$ROOT_DIR"
exec vivado -mode batch -source "$ROOT_DIR/xilinx/vivado_resume_from_synth_entry.tcl"
