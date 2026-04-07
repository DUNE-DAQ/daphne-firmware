#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [FLOW_WORK_DIR] [OUTPUT_DIR]

Export legacy-style handoff artifacts from an impl_legacy_flow Vivado project.

Arguments:
  FLOW_WORK_DIR  Default: build/dune-daq_daphne_k26c-composable-platform_0.1.0/impl_legacy_flow
  OUTPUT_DIR     Default: xilinx/output-<gitsha> (or DAPHNE_OUTPUT_DIR if set)

Generated outputs:
  - daphne_selftrigger_<gitsha>.bit
  - daphne_selftrigger_<gitsha>.bin
  - daphne_selftrigger_<gitsha>.xsa
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
DEFAULT_FLOW_WORK_DIR="$ROOT_DIR/build/dune-daq_daphne_k26c-composable-platform_0.1.0/impl_legacy_flow"
FLOW_WORK_DIR_INPUT="${1:-$DEFAULT_FLOW_WORK_DIR}"

if [[ -z "${DAPHNE_GIT_SHA:-}" ]] && command -v git >/dev/null 2>&1; then
  DAPHNE_GIT_SHA="$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD)"
  export DAPHNE_GIT_SHA
fi

resolve_output_dir() {
  local output_dir_value="${1:-}"

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

OUTPUT_DIR_INPUT="${2:-${DAPHNE_OUTPUT_DIR:-}}"
FLOW_WORK_DIR="$(CDPATH= cd -- "$FLOW_WORK_DIR_INPUT" && pwd)"
OUTPUT_DIR="$(resolve_output_dir "$OUTPUT_DIR_INPUT")"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' not found on PATH" >&2
    exit 2
  }
}

ensure_vivado() {
  if command -v vivado >/dev/null 2>&1; then
    return 0
  fi

  setup_script="$ROOT_DIR/scripts/wsl/setup_windows_xilinx.sh"
  if [[ -f "$setup_script" ]]; then
    # shellcheck disable=SC1090
    . "$setup_script"
  fi

  need_cmd vivado
}

if [[ ! -d "$FLOW_WORK_DIR" ]]; then
  echo "ERROR: Flow work directory does not exist: $FLOW_WORK_DIR_INPUT" >&2
  exit 2
fi

project_xpr="$(find "$FLOW_WORK_DIR" -maxdepth 1 -type f -name '*.xpr' | sort | head -n 1)"
if [[ -z "$project_xpr" ]]; then
  echo "ERROR: no Vivado project (*.xpr) found under $FLOW_WORK_DIR" >&2
  exit 2
fi

ensure_vivado

mkdir -p "$OUTPUT_DIR"

echo "INFO: exporting impl_legacy_flow handoff"
echo "INFO: flow work dir = $FLOW_WORK_DIR"
echo "INFO: project       = $project_xpr"
echo "INFO: output dir    = $OUTPUT_DIR"

vivado -mode batch \
  -source "$ROOT_DIR/xilinx/daphne_export_flow_handoff.tcl" \
  -tclargs "$project_xpr" "$OUTPUT_DIR"

echo "INFO: export complete"
find "$OUTPUT_DIR" -maxdepth 1 \( -name 'daphne_selftrigger_*.bit' -o -name 'daphne_selftrigger_*.bin' -o -name 'daphne_selftrigger_*.xsa' \) | sort
