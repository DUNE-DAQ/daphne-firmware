#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BUILD_DIR="$(pwd)"
PACKAGE_DTBO="${DAPHNE_PACKAGE_DTBO:-auto}"
BOARD="${DAPHNE_BOARD:-k26c}"
TARGET_NAME="${DAPHNE_PLATFORM_TARGET:-impl}"
ARTIFACT_LIST_NAME="${DAPHNE_EXPORT_ARTIFACT_LIST_NAME:-${TARGET_NAME}_artifacts.txt}"

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"

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

resolve_project_xpr() {
  local system_name="${DAPHNE_SYSTEM_NAME:-}"
  local project_xpr_value="${DAPHNE_EXPORT_PROJECT_XPR:-}"

  if [[ -z "$system_name" && -n "${DAPHNE_PLATFORM_CORE:-}" ]]; then
    system_name="$(daphne_platform_core_build_slug "$DAPHNE_PLATFORM_CORE")"
  fi
  if [[ -z "$project_xpr_value" && -n "$system_name" ]]; then
    project_xpr_value="${system_name}.xpr"
  fi

  if [[ -n "$project_xpr_value" ]]; then
    case "$project_xpr_value" in
      /*)
        printf '%s\n' "$project_xpr_value"
        return 0
        ;;
      *)
        printf '%s\n' "$BUILD_DIR/$project_xpr_value"
        return 0
        ;;
    esac
  fi

  find "$BUILD_DIR" -maxdepth 1 -type f -name '*.xpr' | sort | head -n 1
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

project_xpr="$(resolve_project_xpr)"
if [[ -z "$project_xpr" ]]; then
  echo "ERROR: no Vivado project (*.xpr) found under $BUILD_DIR" >&2
  exit 2
fi
if [[ ! -f "$project_xpr" ]]; then
  echo "ERROR: expected Vivado project at $project_xpr" >&2
  exit 2
fi

OUTPUT_DIR="$(resolve_output_dir)"
mkdir -p "$OUTPUT_DIR"

BUILD_NAME_PREFIX="${DAPHNE_BUILD_NAME_PREFIX:-daphne_selftrigger}"
OVERLAY_NAME_PREFIX="${DAPHNE_OVERLAY_NAME_PREFIX:-${BUILD_NAME_PREFIX}_ol}"
IMPL_RUN_NAME="${DAPHNE_EXPORT_IMPL_RUN:-impl_1}"

need_cmd vivado

echo "INFO: Flow-owned Vivado export hook"
echo "INFO: build dir  = $BUILD_DIR"
echo "INFO: project    = $project_xpr"
echo "INFO: impl run   = $IMPL_RUN_NAME"
echo "INFO: output dir = $OUTPUT_DIR"
echo "INFO: target     = $TARGET_NAME"

vivado -mode batch \
  -source "$ROOT_DIR/xilinx/daphne_export_flow_handoff.tcl" \
  -tclargs "$project_xpr" "$OUTPUT_DIR" "$IMPL_RUN_NAME"

run_dtbo_packaging

find "$OUTPUT_DIR" -maxdepth 1 \
  \( -name "${BUILD_NAME_PREFIX}_*.bit" \
  -o -name "${BUILD_NAME_PREFIX}_*.bin" \
  -o -name "${BUILD_NAME_PREFIX}_*.xsa" \
  -o -name "${BUILD_NAME_PREFIX}_*.dtbo" \
  -o -name "${OVERLAY_NAME_PREFIX}_*.zip" \
  -o -name 'SHA256SUMS' \) | sort >"$BUILD_DIR/$ARTIFACT_LIST_NAME"

echo "INFO: Flow-owned Vivado export hook complete"
cat "$BUILD_DIR/$ARTIFACT_LIST_NAME"
