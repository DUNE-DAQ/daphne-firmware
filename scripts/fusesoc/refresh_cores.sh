#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"

python3 "$ROOT_DIR/scripts/fusesoc/generate_daphne_core.py"
"$ROOT_DIR/scripts/fusesoc/fusesoc.sh" list-cores
