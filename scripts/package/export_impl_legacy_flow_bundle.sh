#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export DAPHNE_PLATFORM_TARGET="${DAPHNE_PLATFORM_TARGET:-impl_legacy_flow}"
exec "$SCRIPT_DIR/export_impl_bundle.sh" "$@"
