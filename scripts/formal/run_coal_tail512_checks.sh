#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"

cd "$ROOT_DIR"
exec "$ROOT_DIR/scripts/formal/run_formal.sh" --suite coal-tail512 "$@"
