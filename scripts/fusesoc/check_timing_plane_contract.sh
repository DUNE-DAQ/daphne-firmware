#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"

CORE_PATH="$ROOT_DIR/cores/features/k26c-board-timing-plane.core"
TOP_PATH="$ROOT_DIR/rtl/isolated/subsystems/timing/k26c_board_timing_plane.vhd"

EXPECTED_CORE_DEPS='
dune-daq:daphne:daphne-subsystem-types:0.1.0
dune-daq:daphne:timing-endpoint:0.1.0
'

EXPECTED_ENTITY_DEPS='
endpoint
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
  echo "ERROR: k26c-board-timing-plane.core direct deps drifted from the endpoint contract." >&2
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
  echo "ERROR: k26c_board_timing_plane.vhd entity instantiations drifted from the endpoint contract." >&2
  echo "INFO: expected:" >&2
  printf '%s\n' "$expected_entity_deps" >&2
  echo "INFO: actual:" >&2
  printf '%s\n' "$actual_entity_deps" >&2
  exit 1
fi

echo "INFO: Timing plane remains constrained to a single endpoint boundary."
