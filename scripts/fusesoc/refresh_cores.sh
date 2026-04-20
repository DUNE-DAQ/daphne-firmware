#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"

python3 "$ROOT_DIR/scripts/fusesoc/generate_daphne_core.py"
if [ -f "$ROOT_DIR/xilinx/daphne_fullstream_ip_gen.tcl" ] && [ -d "$ROOT_DIR/ip_repo/daphne3_ip" ]; then
  python3 "$ROOT_DIR/scripts/fusesoc/generate_daphne_fullstream_core.py"
else
  echo "INFO: Skipping fullstream core generation until the daphne3_ip tree is present."
fi
"$ROOT_DIR/scripts/fusesoc/fusesoc.sh" list-cores
