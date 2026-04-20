#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"

board_profile="k26c-fullstream"
platform_core="dune-daq:daphne-fullstream:k26c-platform:0.1.0"
modular_platform_core="dune-daq:daphne-fullstream:k26c-modular-platform:0.1.0"

require_core() {
  core_vlnv="$1"
  if ! "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" core-info "$core_vlnv" >/dev/null 2>&1; then
    echo "ERROR: missing FuseSoC core '$core_vlnv'." >&2
    exit 1
  fi
}

require_log_line() {
  log_path="$1"
  expected="$2"
  if ! grep -Fq "$expected" "$log_path"; then
    echo "ERROR: fullstream dry-run log '$log_path' is missing expected line: $expected" >&2
    exit 1
  fi
}

require_core "$platform_core"
require_core "$modular_platform_core"

dryrun_log="$(mktemp "${TMPDIR:-/tmp}/daphne-fullstream-support.XXXXXX.log")"
trap 'rm -f "$dryrun_log"' EXIT INT TERM

if ! DAPHNE_BOARD="$board_profile" "$ROOT_DIR/scripts/fusesoc/build_platform.sh" --dry-run >"$dryrun_log" 2>&1; then
  cat "$dryrun_log" >&2
  echo "ERROR: fullstream build-platform dry-run failed." >&2
  exit 1
fi

require_log_line "$dryrun_log" "INFO: Selected FuseSoC platform core: $platform_core"
require_log_line "$dryrun_log" "INFO: Resolved board profile: $board_profile"
require_log_line "$dryrun_log" "INFO: Selected FuseSoC system name: k26c_full"
require_log_line "$dryrun_log" "INFO: Selected FuseSoC work root: $ROOT_DIR/build/k26c_full/impl"
require_log_line "$dryrun_log" "INFO: Dry-run only, stopping before Vivado."

echo "INFO: Fullstream scaffold selection and FuseSoC discovery are consistent."
