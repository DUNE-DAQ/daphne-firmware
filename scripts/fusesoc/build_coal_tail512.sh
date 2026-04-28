#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"

cd "$ROOT_DIR"

exec "$ROOT_DIR/scripts/fusesoc/build_platform.sh" \
  --platform-core dune-daq:daphne:k26c-composable-platform:0.1.0 \
  --target impl_coal_tail512 \
  "$@"
