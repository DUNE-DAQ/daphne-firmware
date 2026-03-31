#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
ETH_MODE="${DAPHNE_ETH_MODE:-create_ip}"

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

if ! command -v vivado >/dev/null 2>&1; then
  echo "ERROR: vivado is not installed or not on PATH." >&2
  exit 2
fi

if [ "$ETH_MODE" = "vendored_hdl" ]; then
  echo "ERROR: DAPHNE_ETH_MODE=vendored_hdl is not qualified for full implementation yet." >&2
  echo "Use DAPHNE_ETH_MODE=create_ip for the current WSL/Windows Vivado flow." >&2
  exit 2
fi

export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"
export DAPHNE_FPGA_PART
export DAPHNE_BOARD_PART
export DAPHNE_PFM_NAME

if [ -z "${DAPHNE_GIT_SHA-}" ] && command -v git >/dev/null 2>&1; then
  if resolved_git_sha=$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD 2>/dev/null); then
    export DAPHNE_GIT_SHA="$resolved_git_sha"
  fi
fi

exec "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" run --target=impl dune-daq:daphne:k26c-platform:0.1.0
