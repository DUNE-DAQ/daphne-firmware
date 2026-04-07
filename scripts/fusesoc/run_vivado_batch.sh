#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-dune-daq:daphne:k26c-platform:0.1.0}"
PLATFORM_TARGET="${DAPHNE_PLATFORM_TARGET:-}"

case "$BOARD" in
  k26c)
    : "${DAPHNE_FPGA_PART:=xck26-sfvc784-2LV-c}"
    : "${DAPHNE_BOARD_PART:=xilinx.com:k26c:part0:1.4}"
    : "${DAPHNE_PFM_NAME:=xilinx:k26c:name:0.0}"
    ;;
  kr260)
    echo "ERROR: board '$BOARD' is scaffolded but not yet supported." >&2
    echo "Missing items are tracked in boards/kr260/board.yml." >&2
    exit 2
    ;;
  *)
    echo "ERROR: unknown board '$BOARD'." >&2
    echo "Set DAPHNE_BOARD=k26c or provide explicit DAPHNE_FPGA_PART/DAPHNE_BOARD_PART/DAPHNE_PFM_NAME overrides." >&2
    exit 2
    ;;
esac

export DAPHNE_BOARD="$BOARD"
export DAPHNE_FPGA_PART
export DAPHNE_BOARD_PART
export DAPHNE_PFM_NAME
export DAPHNE_PLATFORM_CORE

if [ -z "${DAPHNE_GIT_SHA-}" ] && command -v git >/dev/null 2>&1; then
  if resolved_git_sha=$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD 2>/dev/null); then
    export DAPHNE_GIT_SHA="$resolved_git_sha"
  fi
fi

if [ -z "$PLATFORM_TARGET" ] && [ "$PLATFORM_CORE" = "dune-daq:daphne:k26c-composable-platform:0.1.0" ]; then
  PLATFORM_TARGET="impl"
fi

if [ -n "$PLATFORM_TARGET" ]; then
  export DAPHNE_PLATFORM_TARGET="$PLATFORM_TARGET"
  exec "$ROOT_DIR/scripts/fusesoc/build_platform.sh" --platform-core "$PLATFORM_CORE" --target "$PLATFORM_TARGET"
fi

exec "$ROOT_DIR/scripts/fusesoc/build_platform.sh" --platform-core "$PLATFORM_CORE"
