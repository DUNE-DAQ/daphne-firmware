#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"

if ! command -v ghdl >/dev/null 2>&1; then
  echo "ERROR: ghdl is not installed." >&2
  echo "Install GHDL first, then rerun this smoke test." >&2
  exit 2
fi

if [ "$#" -eq 0 ]; then
  set -- \
    dune-daq:daphne:thresholds-test:0.1.0 \
    dune-daq:daphne:frontend-test:0.1.0
fi

for core in "$@"; do
  echo "Running $core"
  "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" run \
    --clean \
    --target sim \
    --tool ghdl \
    --build-root "$ROOT_DIR/build/fusesoc" \
    "$core"
done
