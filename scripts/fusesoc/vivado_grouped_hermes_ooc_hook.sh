#!/bin/sh
set -eu

TOP_NAME="${1:?missing OOC top name}"
RUN_LABEL="${2:-$TOP_NAME}"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

export DAPHNE_COMPOSABLE_OOC_TOP="$TOP_NAME"
: "${DAPHNE_OUTPUT_DIR:=./output-grouped-hermes-ooc-$RUN_LABEL}"
export DAPHNE_OUTPUT_DIR

exec "$SCRIPT_DIR/vivado_composable_ooc_hook.sh"
