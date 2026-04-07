#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
CORE_PATH="$ROOT_DIR/cores/features/k26c-board-spy-trigger-plane.core"
TOP_PATH="$ROOT_DIR/rtl/isolated/subsystems/spy/k26c_board_spy_trigger_plane.vhd"

EXPECTED_CORE_DEPS=''

actual_core_deps="$(
  awk '
    /  rtl:/ { in_rtl=1; next }
    in_rtl && /    depend:/ { in_depend=1; next }
    in_rtl && in_depend && /    files:/ { exit }
    in_rtl && in_depend && /      - / {
      sub(/^      - /, "", $0)
      print
    }
  ' "$CORE_PATH" | sort -u
)"

expected_core_deps="$(printf '%s' "$EXPECTED_CORE_DEPS" | sed '/^$/d' | sort -u)"

if [ "$actual_core_deps" != "$expected_core_deps" ]; then
  echo "ERROR: k26c-board-spy-trigger-plane.core direct deps drifted from the board-local spy-trigger contract." >&2
  echo "INFO: expected:" >&2
  printf '%s\n' "$expected_core_deps" >&2
  echo "INFO: actual:" >&2
  printf '%s\n' "$actual_core_deps" >&2
  exit 1
fi

actual_entity_deps="$(rg -o 'entity work\.[A-Za-z0-9_]+' "$TOP_PATH" | sed 's/^entity work\.//' | sort -u)"

if [ -n "$actual_entity_deps" ]; then
  echo "ERROR: k26c_board_spy_trigger_plane.vhd must remain self-contained and board-local." >&2
  echo "INFO: actual entity instantiations:" >&2
  printf '%s\n' "$actual_entity_deps" >&2
  exit 1
fi

echo "INFO: Spy-trigger plane remains self-contained and free of imported entity dependencies."
