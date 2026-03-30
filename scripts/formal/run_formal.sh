#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"

if ! command -v sby >/dev/null 2>&1; then
  echo "ERROR: symbiyosys (sby) is not installed." >&2
  exit 2
fi

if [ "$#" -eq 0 ]; then
  set -- \
    "$ROOT_DIR/formal/sby/fe_axi_axi_lite.sby" \
    "$ROOT_DIR/formal/sby/thresholds_axi_lite.sby"
fi

for job in "$@"; do
  echo "Running formal scaffold $job"
  sby -f "$job"
done
