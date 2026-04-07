#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
PLATFORM_TARGET="${DAPHNE_PLATFORM_TARGET:-}"

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"

DEFAULT_CORE="$(daphne_board_manifest_value "$ROOT_DIR" "$BOARD" platform_core)"
DEFAULT_COMPOSABLE_CORE="$(daphne_board_manifest_value "$ROOT_DIR" "$BOARD" composable_platform_core)"
: "${DEFAULT_CORE:=dune-daq:daphne:k26c-platform:0.1.0}"
: "${DEFAULT_COMPOSABLE_CORE:=dune-daq:daphne:k26c-composable-platform:0.1.0}"
PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-$DEFAULT_CORE}"

export DAPHNE_BOARD="$BOARD"
export DAPHNE_FPGA_PART
export DAPHNE_BOARD_PART
export DAPHNE_PFM_NAME
export DAPHNE_CONSTRAINT_FILE
export DAPHNE_CONSTRAINT_FILES
export DAPHNE_PLATFORM_CORE

if [ -z "${DAPHNE_GIT_SHA-}" ] && command -v git >/dev/null 2>&1; then
  if resolved_git_sha=$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD 2>/dev/null); then
    export DAPHNE_GIT_SHA="$resolved_git_sha"
  fi
fi

if [ -z "$PLATFORM_TARGET" ] && [ "$PLATFORM_CORE" = "$DEFAULT_COMPOSABLE_CORE" ]; then
  PLATFORM_TARGET="impl"
fi

if [ -n "$PLATFORM_TARGET" ]; then
  export DAPHNE_PLATFORM_TARGET="$PLATFORM_TARGET"
  exec "$ROOT_DIR/scripts/fusesoc/build_platform.sh" --platform-core "$PLATFORM_CORE" --target "$PLATFORM_TARGET"
fi

exec "$ROOT_DIR/scripts/fusesoc/build_platform.sh" --platform-core "$PLATFORM_CORE"
