#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"

CORE_PATH="$ROOT_DIR/cores/features/k26c-board-shell.core"
TOP_PATH="$ROOT_DIR/rtl/isolated/tops/k26c_board_shell.vhd"

EXPECTED_CORE_DEPS='
dune-daq:daphne:daphne-package:0.1.0
dune-daq:daphne:k26c-board-analog-control-plane:0.1.0
dune-daq:daphne:k26c-board-frontend-plane:0.1.0
dune-daq:daphne:k26c-board-selftrigger-plane:0.1.0
dune-daq:daphne:k26c-board-spy-capture-plane:0.1.0
dune-daq:daphne:k26c-board-timing-plane:0.1.0
'

EXPECTED_ENTITY_DEPS='
k26c_board_analog_control_plane
k26c_board_frontend_plane
k26c_board_selftrigger_plane
k26c_board_spy_capture_plane
k26c_board_timing_plane
'

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
  echo "ERROR: k26c-board-shell.core direct deps drifted from the board-plane contract." >&2
  echo "INFO: expected:" >&2
  printf '%s\n' "$expected_core_deps" >&2
  echo "INFO: actual:" >&2
  printf '%s\n' "$actual_core_deps" >&2
  exit 1
fi

actual_entity_deps="$(
  rg -o 'entity work\.[A-Za-z0-9_]+' "$TOP_PATH" \
    | sed 's/^entity work\.//' \
    | sort -u
)"

expected_entity_deps="$(printf '%s' "$EXPECTED_ENTITY_DEPS" | sed '/^$/d' | sort -u)"

if [ "$actual_entity_deps" != "$expected_entity_deps" ]; then
  echo "ERROR: k26c_board_shell.vhd entity instantiations drifted from the board-plane contract." >&2
  echo "INFO: expected:" >&2
  printf '%s\n' "$expected_entity_deps" >&2
  echo "INFO: actual:" >&2
  printf '%s\n' "$actual_entity_deps" >&2
  exit 1
fi

echo "INFO: Board shell remains constrained to explicit board-plane cores and entities."
