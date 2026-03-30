#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
USER_BIN="$(python3 - <<'PY'
import os
import site
print(os.path.join(site.USER_BASE, "bin"))
PY
)"

if [ -d "$USER_BIN" ]; then
  PATH="$USER_BIN:$PATH"
fi

export PATH
export XDG_CACHE_HOME="$ROOT_DIR/.cache"
export XDG_DATA_HOME="$ROOT_DIR/.fusesoc"

mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME"

exec fusesoc --config "$ROOT_DIR/fusesoc.conf" "$@"
