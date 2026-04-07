#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BUILD_DIR="$(pwd)"
PACKAGE_DTBO="${DAPHNE_PACKAGE_DTBO:-auto}"

if [[ -z "${DAPHNE_GIT_SHA:-}" ]] && command -v git >/dev/null 2>&1; then
  if resolved_git_sha="$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD 2>/dev/null)"; then
    DAPHNE_GIT_SHA="$resolved_git_sha"
    export DAPHNE_GIT_SHA
  fi
fi

resolve_output_dir() {
  local output_dir_value="${DAPHNE_OUTPUT_DIR:-}"

  if [[ -z "$output_dir_value" ]]; then
    printf '%s\n' "$ROOT_DIR/xilinx/output-${DAPHNE_GIT_SHA:-0000000}"
    return 0
  fi

  case "$output_dir_value" in
    /*)
      printf '%s\n' "$output_dir_value"
      ;;
    ./*)
      printf '%s\n' "$ROOT_DIR/xilinx/${output_dir_value#./}"
      ;;
    *)
      printf '%s\n' "$ROOT_DIR/xilinx/$output_dir_value"
      ;;
  esac
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' not found on PATH" >&2
    exit 2
  }
}

run_dtbo_packaging() {
  local package_script="$ROOT_DIR/scripts/package/complete_dtbo_bundle.sh"

  case "$PACKAGE_DTBO" in
    0|false|FALSE|no|NO)
      echo "INFO: Skipping DTBO packaging by request (DAPHNE_PACKAGE_DTBO=$PACKAGE_DTBO)."
      return 0
      ;;
  esac

  if [[ ! -f "$package_script" ]]; then
    if [[ "$PACKAGE_DTBO" == "auto" ]]; then
      echo "WARNING: DTBO packaging helper not found at $package_script; skipping optional overlay packaging." >&2
      return 0
    fi
    echo "ERROR: DTBO packaging helper not found at $package_script" >&2
    exit 2
  fi

  echo "INFO: Completing DTBO bundle from exported handoff artifacts (mode=$PACKAGE_DTBO)."
  if "$package_script" "$OUTPUT_DIR"; then
    return 0
  fi

  if [[ "$PACKAGE_DTBO" == "auto" ]]; then
    echo "WARNING: Optional DTBO packaging failed; keeping exported .bit/.bin/.xsa artifacts." >&2
    return 0
  fi

  echo "ERROR: DTBO packaging failed with DAPHNE_PACKAGE_DTBO=$PACKAGE_DTBO" >&2
  exit 2
}

project_xpr="$(find "$BUILD_DIR" -maxdepth 1 -type f -name '*.xpr' | sort | head -n 1)"
if [[ -z "$project_xpr" ]]; then
  echo "ERROR: no Vivado project (*.xpr) found under $BUILD_DIR" >&2
  exit 2
fi

OUTPUT_DIR="$(resolve_output_dir)"
mkdir -p "$OUTPUT_DIR"

need_cmd vivado

echo "INFO: Flow-owned legacy export hook"
echo "INFO: build dir  = $BUILD_DIR"
echo "INFO: project    = $project_xpr"
echo "INFO: output dir = $OUTPUT_DIR"

vivado -mode batch \
  -source "$ROOT_DIR/xilinx/daphne_export_flow_handoff.tcl" \
  -tclargs "$project_xpr" "$OUTPUT_DIR"

run_dtbo_packaging

find "$OUTPUT_DIR" -maxdepth 1 \
  \( -name 'daphne_selftrigger_*.bit' \
  -o -name 'daphne_selftrigger_*.bin' \
  -o -name 'daphne_selftrigger_*.xsa' \
  -o -name 'daphne_selftrigger_*.dtbo' \
  -o -name 'daphne_selftrigger_ol_*.zip' \
  -o -name 'SHA256SUMS' \) | sort >"$BUILD_DIR/impl_legacy_flow_artifacts.txt"

echo "INFO: Flow-owned legacy export hook complete"
cat "$BUILD_DIR/impl_legacy_flow_artifacts.txt"
