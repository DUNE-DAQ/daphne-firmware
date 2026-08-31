#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(unset CDPATH; cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"

# Keep artifact names aligned with the selected board profile.
# ROOT_DIR is resolved at runtime.
# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"

GIT_SHA="${2:-${DAPHNE_GIT_SHA:-}}"
if [[ -z "$GIT_SHA" ]]; then
  GIT_SHA="$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD)"
fi

if [[ ! "$GIT_SHA" =~ ^[0-9a-fA-F]{7,}$ ]]; then
  echo "ERROR: git SHA must contain at least seven hexadecimal characters: '$GIT_SHA'." >&2
  exit 2
fi

OUTPUT_DIR="${1:-${DAPHNE_OUTPUT_DIR:-$ROOT_DIR/xilinx/output-$GIT_SHA}}"
BUILD_NAME_PREFIX="${DAPHNE_BUILD_NAME_PREFIX:-daphne_selftrigger}"
OVERLAY_NAME_PREFIX="${DAPHNE_OVERLAY_NAME_PREFIX:-${BUILD_NAME_PREFIX}_ol}"
BUILD_NAME="${BUILD_NAME_PREFIX}_${GIT_SHA}"
OVERLAY_NAME="${OVERLAY_NAME_PREFIX}_${GIT_SHA}"
OVERLAY_DIR="$OUTPUT_DIR/$OVERLAY_NAME"
failed=0

check_file() {
  local label="$1"
  local path="$2"

  if [[ -s "$path" ]]; then
    printf 'PASS  %-18s %8s  %s\n' "$label" "$(du -h "$path" | awk '{print $1}')" "$path"
  else
    printf 'FAIL  %-18s %s\n' "$label" "$path" >&2
    failed=1
  fi
}

check_manifest_path_once() {
  local label="$1"
  local manifest="$2"
  local checksum_path="$3"
  local match_count

  match_count="$(awk -v path="$checksum_path" '
    {
      name = $2
      sub(/^\*/, "", name)
      if (NF == 2 && name == path) count += 1
    }
    END { print count + 0 }
  ' "$manifest")"
  if [[ "$match_count" != "1" ]]; then
    echo "FAIL  $label must contain exactly one checksum for $checksum_path (found $match_count)" >&2
    failed=1
  fi
}

echo "Checking self-trigger build $GIT_SHA"
echo "Output directory: $OUTPUT_DIR"

check_file "FPGA bitstream" "$OUTPUT_DIR/$BUILD_NAME.bit"
check_file "FPGA binary" "$OUTPUT_DIR/$BUILD_NAME.bin"
check_file "hardware XSA" "$OUTPUT_DIR/$BUILD_NAME.xsa"
check_file "device-tree blob" "$OUTPUT_DIR/$BUILD_NAME.dtbo"
check_file "overlay bitstream" "$OVERLAY_DIR/$OVERLAY_NAME.bin"
check_file "overlay DTBO" "$OVERLAY_DIR/$OVERLAY_NAME.dtbo"
check_file "overlay metadata" "$OVERLAY_DIR/shell.json"
check_file "overlay archive" "$OUTPUT_DIR/$OVERLAY_NAME.zip"
check_file "overlay manifest" "$OUTPUT_DIR/$OVERLAY_NAME.SHA256SUMS"
check_file "checksums" "$OUTPUT_DIR/SHA256SUMS"
check_file "route timing" "$OUTPUT_DIR/post_route_timing_summary.rpt"
check_file "bus skew" "$OUTPUT_DIR/post_route_bus_skew.rpt"
check_file "CDC report" "$OUTPUT_DIR/post_route_cdc.rpt"
check_file "methodology" "$OUTPUT_DIR/post_route_methodology.rpt"
check_file "route status" "$OUTPUT_DIR/post_route_status.rpt"
check_file "power report" "$OUTPUT_DIR/post_route_power.rpt"
check_file "utilization" "$OUTPUT_DIR/post_route_util.rpt"
check_file "DRC report" "$OUTPUT_DIR/post_imp_drc.rpt"

checksum_manifest="$OUTPUT_DIR/SHA256SUMS"
if [[ -s "$checksum_manifest" ]]; then
  if command -v sha256sum >/dev/null 2>&1; then
    if (unset CDPATH; cd -- "$OUTPUT_DIR" && sha256sum -c SHA256SUMS); then
      echo "PASS  packaged-file checksums"
    else
      echo "FAIL  a packaged-file checksum does not match" >&2
      failed=1
    fi
  elif command -v shasum >/dev/null 2>&1; then
    if (unset CDPATH; cd -- "$OUTPUT_DIR" && shasum -a 256 -c SHA256SUMS); then
      echo "PASS  packaged-file checksums"
    else
      echo "FAIL  a packaged-file checksum does not match" >&2
      failed=1
    fi
  else
    echo "FAIL  sha256sum or shasum is required to verify SHA256SUMS" >&2
    failed=1
  fi

  for checksum_path in \
    "$BUILD_NAME.bit" \
    "$BUILD_NAME.bin" \
    "$BUILD_NAME.xsa" \
    "$BUILD_NAME.dtbo" \
    "$OVERLAY_NAME.zip" \
    "$OVERLAY_NAME/$OVERLAY_NAME.bin" \
    "$OVERLAY_NAME/$OVERLAY_NAME.dtbo" \
    "$OVERLAY_NAME/shell.json" \
    "$OVERLAY_NAME.SHA256SUMS" \
    post_route_timing_summary.rpt \
    post_route_bus_skew.rpt \
    post_route_cdc.rpt \
    post_route_methodology.rpt \
    post_route_status.rpt \
    post_route_power.rpt \
    post_route_util.rpt \
    post_imp_drc.rpt
  do
    check_manifest_path_once "checksum manifest" "$checksum_manifest" "$checksum_path"
  done
fi

bundle_checksum_manifest="$OUTPUT_DIR/$OVERLAY_NAME.SHA256SUMS"
if [[ -s "$bundle_checksum_manifest" ]]; then
  if command -v sha256sum >/dev/null 2>&1; then
    if (unset CDPATH; cd -- "$OUTPUT_DIR" && sha256sum -c "$OVERLAY_NAME.SHA256SUMS"); then
      echo "PASS  overlay bundle checksums"
    else
      echo "FAIL  an overlay bundle checksum does not match" >&2
      failed=1
    fi
  elif command -v shasum >/dev/null 2>&1; then
    if (unset CDPATH; cd -- "$OUTPUT_DIR" && shasum -a 256 -c "$OVERLAY_NAME.SHA256SUMS"); then
      echo "PASS  overlay bundle checksums"
    else
      echo "FAIL  an overlay bundle checksum does not match" >&2
      failed=1
    fi
  fi

  for checksum_path in \
    "$OVERLAY_NAME.zip" \
    "$OVERLAY_NAME/$OVERLAY_NAME.bin" \
    "$OVERLAY_NAME/$OVERLAY_NAME.dtbo" \
    "$OVERLAY_NAME/shell.json"
  do
    check_manifest_path_once "overlay manifest" "$bundle_checksum_manifest" "$checksum_path"
  done
fi

timing_report="$OUTPUT_DIR/post_route_timing_summary.rpt"
if [[ -s "$timing_report" ]]; then
  if grep -Fq 'All user specified timing constraints are met.' "$timing_report"; then
    echo "PASS  timing constraints met"
  elif grep -Eq 'Timing constraints are not met|VIOLATED' "$timing_report"; then
    echo "FAIL  timing violations are present in $timing_report" >&2
    grep -E 'WNS\(ns\)|TNS\(ns\)|VIOLATED|Timing constraints are not met' \
      "$timing_report" | head -12 >&2 || true
    failed=1
  else
    echo "FAIL  timing result was not recognized in $timing_report" >&2
    failed=1
  fi
fi

if command -v unzip >/dev/null 2>&1; then
  if [[ -s "$OUTPUT_DIR/$OVERLAY_NAME.zip" ]]; then
    if unzip -tqq "$OUTPUT_DIR/$OVERLAY_NAME.zip"; then
      echo "PASS  overlay archive integrity"
    else
      echo "FAIL  overlay archive is corrupt" >&2
      failed=1
    fi
  fi

  if [[ -s "$OUTPUT_DIR/$BUILD_NAME.xsa" ]]; then
    if unzip -tqq "$OUTPUT_DIR/$BUILD_NAME.xsa"; then
      echo "PASS  hardware XSA integrity"
    else
      echo "FAIL  hardware XSA is corrupt" >&2
      failed=1
    fi
  fi
else
  echo "FAIL  unzip is required to verify the XSA and overlay archive" >&2
  failed=1
fi

if command -v dtc >/dev/null 2>&1; then
  if [[ -s "$OUTPUT_DIR/$BUILD_NAME.dtbo" ]]; then
    if dtc -I dtb -O dts -o /dev/null "$OUTPUT_DIR/$BUILD_NAME.dtbo" 2>/dev/null; then
      echo "PASS  device-tree blob parses"
    else
      echo "FAIL  device-tree blob does not parse" >&2
      failed=1
    fi
  fi
else
  echo "FAIL  dtc is required to verify the device-tree blob" >&2
  failed=1
fi

drc_report="$OUTPUT_DIR/post_imp_drc.rpt"
if [[ -s "$drc_report" ]]; then
  if grep -Eq '^[[:space:]]*[A-Z0-9-]+#[0-9]+[[:space:]]+(Error|Critical)' "$drc_report"; then
    echo "FAIL  error-level DRC violations are present in $drc_report" >&2
    failed=1
  else
    echo "PASS  no error-level DRC violations"
  fi
fi

bus_skew_report="$OUTPUT_DIR/post_route_bus_skew.rpt"
if [[ -s "$bus_skew_report" ]]; then
  if grep -Fq 'Slack (VIOLATED)' "$bus_skew_report"; then
    echo "FAIL  a bus-skew constraint is violated in $bus_skew_report" >&2
    failed=1
  else
    echo "PASS  no violated bus-skew constraints"
  fi
fi

route_status_report="$OUTPUT_DIR/post_route_status.rpt"
if [[ -s "$route_status_report" ]]; then
  if grep -Eq '# of nets with routing errors.*:[[:space:]]+0' "$route_status_report"; then
    echo "PASS  no routing errors"
  else
    echo "FAIL  routed-net status is not clean in $route_status_report" >&2
    failed=1
  fi
fi

cdc_report="$OUTPUT_DIR/post_route_cdc.rpt"
if [[ -s "$cdc_report" ]] && grep -Eq '^[[:space:]]*CDC-[0-9]+[[:space:]]+Critical' "$cdc_report"; then
  echo "LIMITATION  Vivado reports critical CDC classifications; review $cdc_report"
fi

methodology_report="$OUTPUT_DIR/post_route_methodology.rpt"
if [[ -s "$methodology_report" ]] && grep -Fq 'Critical Warning' "$methodology_report"; then
  echo "LIMITATION  Vivado reports critical methodology warnings; review $methodology_report"
fi

if (( failed != 0 )); then
  echo "RESULT: FAILED. Keep the output directory and inspect the reported file." >&2
  exit 1
fi

echo "RESULT: PASS. Artifact integrity and implementation gates passed."
