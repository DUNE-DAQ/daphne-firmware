#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OUTPUT_DIR]

Complete the DT overlay bundle from an existing Vivado hardware handoff.

Expected inputs in OUTPUT_DIR:
  - <build-name-prefix>_<gitsha>.xsa
  - <build-name-prefix>_<gitsha>.bin
  - if DAPHNE_ACCEPT_LEGACY_ARTIFACT_ALIASES=1:
    legacy daphne3_st_<gitsha>.xsa / daphne3_st_<gitsha>.bin are accepted

Generated outputs:
  - <build-name-prefix>_<gitsha>.dtbo
  - <overlay-name-prefix>_<gitsha>/
  - <overlay-name-prefix>_<gitsha>.zip
  - <overlay-name-prefix>_<gitsha>.SHA256SUMS
  - SHA256SUMS
EOF
}

is_wsl() {
  uname -r | grep -qiE 'microsoft|wsl'
}

find_latest_xsa() {
  local search_dir="$1"
  local candidate

  candidate="$(find "$search_dir" -maxdepth 1 -type f -name "${BUILD_NAME_PREFIX}_*.xsa" | sort | tail -n 1)"
  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if [[ "$ACCEPT_LEGACY_ARTIFACT_ALIASES" == "1" ]]; then
    candidate="$(find "$search_dir" -maxdepth 1 -type f -name "${LEGACY_ARTIFACT_PREFIX}_*.xsa" | sort | tail -n 1)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  return 0
}

select_dtgen_output_dir() {
  local requested_dir mirror_dir

  requested_dir="$1"
  case "$requested_dir" in
    /mnt/[a-zA-Z]/*)
      printf '%s\n' "$requested_dir"
      return 0
      ;;
  esac

  if is_wsl; then
    case "$requested_dir" in
      /home/*)
        mirror_dir="/mnt/c${requested_dir}"
        if [[ -d "$mirror_dir" ]]; then
          printf '%s\n' "$mirror_dir"
          return 0
        fi
        ;;
    esac
  fi

  printf '%s\n' "$requested_dir"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' not found on PATH" >&2
    exit 2
  }
}

normalize_pl_dtsi() {
  local dtsi_path="$1"
  local firmware_name="$2"

  python3 "$PL_OVERLAY_NORMALIZER" \
    --firmware-name "$firmware_name" \
    "$dtsi_path"
}

select_dtgen_tool() {
  if command -v sdtgen >/dev/null 2>&1; then
    DTGEN_CMD="sdtgen"
    DTGEN_KIND="sdtgen"
    return 0
  fi

  if command -v xsct >/dev/null 2>&1; then
    DTGEN_CMD="xsct"
    DTGEN_KIND="xsct"
    return 0
  fi

  return 1
}

ensure_dtgen() {
  if select_dtgen_tool; then
    return 0
  fi

  setup_script="$ROOT_DIR/scripts/wsl/setup_windows_xilinx.sh"
  if [[ -f "$setup_script" ]]; then
    # shellcheck disable=SC1090
    . "$setup_script"
  fi

  if ! select_dtgen_tool; then
    echo "ERROR: required command 'sdtgen' or legacy 'xsct' not found on PATH" >&2
    echo "ERROR: if you are running from WSL, source scripts/wsl/setup_windows_xilinx.sh first" >&2
    exit 2
  fi
}

generate_pl_dtsi() {
  local hw_xsa="$1"
  local dtgen_output_dir="$2"
  local git_sha="$3"
  local artifact_prefix="$4"
  local overlay_prefix="$5"
  local generated_dir="$dtgen_output_dir/${artifact_prefix}_${git_sha}"

  case "$DTGEN_KIND" in
    sdtgen)
      "$DTGEN_CMD" -xsa "$hw_xsa" -dir "$generated_dir" -zocl enable
      ;;
    xsct)
      "$DTGEN_CMD" "$DTBO_GEN_TCL" "$hw_xsa" "$dtgen_output_dir" "$git_sha" "$artifact_prefix" "$overlay_prefix"
      ;;
    *)
      echo "ERROR: no device-tree generator selected" >&2
      exit 2
      ;;
  esac
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(unset CDPATH; cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
# ROOT_DIR is resolved at runtime.
# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"
if [[ -n "${1:-}" ]]; then
  OUTPUT_DIR_INPUT="$1"
elif [[ -n "${DAPHNE_OUTPUT_DIR:-}" ]]; then
  OUTPUT_DIR_INPUT="${DAPHNE_OUTPUT_DIR}"
elif [[ -n "${DAPHNE_GIT_SHA:-}" ]]; then
  OUTPUT_DIR_INPUT="$ROOT_DIR/xilinx/output-$DAPHNE_GIT_SHA"
else
  OUTPUT_DIR_INPUT="$ROOT_DIR/xilinx/output"
fi
OUTPUT_DIR="$(unset CDPATH; cd -- "$OUTPUT_DIR_INPUT" && pwd)"
DTGEN_OUTPUT_DIR="$(select_dtgen_output_dir "$OUTPUT_DIR")"
DTBO_GEN_TCL="$ROOT_DIR/xilinx/daphne_dtbo_gen.tcl"
AXI_SPI_PATCH="$ROOT_DIR/xilinx/scripts/axi_quad_spi_dtbo_patch.sed"
PL_OVERLAY_NORMALIZER="$ROOT_DIR/scripts/package/normalize_pl_overlay.py"
BUILD_NAME_PREFIX="${DAPHNE_BUILD_NAME_PREFIX:-daphne_selftrigger}"
OVERLAY_NAME_PREFIX="${DAPHNE_OVERLAY_NAME_PREFIX:-${BUILD_NAME_PREFIX}_ol}"
ACCEPT_LEGACY_ARTIFACT_ALIASES="${DAPHNE_ACCEPT_LEGACY_ARTIFACT_ALIASES:-0}"
LEGACY_ARTIFACT_PREFIX="${DAPHNE_LEGACY_ARTIFACT_PREFIX:-daphne3_st}"
LEGACY_OVERLAY_PREFIX="${DAPHNE_LEGACY_OVERLAY_PREFIX:-daphne3_st_OL}"
if command -v sha256sum >/dev/null 2>&1; then
  SHA256_CMD=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  SHA256_CMD=(shasum -a 256)
else
  echo "ERROR: neither sha256sum nor shasum is available on PATH" >&2
  exit 2
fi

ensure_dtgen
need_cmd dtc
need_cmd zip
need_cmd python3

if [[ ! -d "$OUTPUT_DIR" ]]; then
  echo "ERROR: output directory does not exist: $OUTPUT_DIR_INPUT" >&2
  exit 2
fi

if [[ ! -f "$DTBO_GEN_TCL" ]]; then
  echo "ERROR: missing legacy XSCT helper: $DTBO_GEN_TCL" >&2
  exit 2
fi

if [[ ! -f "$AXI_SPI_PATCH" ]]; then
  echo "ERROR: missing AXI Quad SPI patch: $AXI_SPI_PATCH" >&2
  exit 2
fi

if [[ ! -f "$PL_OVERLAY_NORMALIZER" ]]; then
  echo "ERROR: missing PL overlay normalizer: $PL_OVERLAY_NORMALIZER" >&2
  exit 2
fi

latest_xsa="$(find_latest_xsa "$OUTPUT_DIR")"

if [[ -z "$latest_xsa" && "$DTGEN_OUTPUT_DIR" != "$OUTPUT_DIR" ]]; then
  latest_xsa="$(find_latest_xsa "$DTGEN_OUTPUT_DIR")"
fi

if [[ -z "$latest_xsa" ]]; then
  echo "ERROR: no ${BUILD_NAME_PREFIX}_*.xsa found in $OUTPUT_DIR or $DTGEN_OUTPUT_DIR" >&2
  if [[ "$ACCEPT_LEGACY_ARTIFACT_ALIASES" == "1" ]]; then
    echo "ERROR: legacy ${LEGACY_ARTIFACT_PREFIX}_*.xsa aliases were also checked" >&2
  fi
  exit 2
fi

xsa_basename="$(basename "$latest_xsa")"
case "$xsa_basename" in
  ${BUILD_NAME_PREFIX}_*.xsa)
    artifact_prefix="${BUILD_NAME_PREFIX}"
    overlay_prefix="${OVERLAY_NAME_PREFIX}"
    git_sha="${xsa_basename#"${BUILD_NAME_PREFIX}_"}"
    git_sha="${git_sha%.xsa}"
    ;;
  *)
    if [[ "$ACCEPT_LEGACY_ARTIFACT_ALIASES" == "1" && "$xsa_basename" == ${LEGACY_ARTIFACT_PREFIX}_*.xsa ]]; then
      artifact_prefix="${LEGACY_ARTIFACT_PREFIX}"
      overlay_prefix="${LEGACY_OVERLAY_PREFIX}"
      git_sha="${xsa_basename#"${LEGACY_ARTIFACT_PREFIX}_"}"
      git_sha="${git_sha%.xsa}"
    else
      echo "ERROR: unrecognized XSA name: $xsa_basename" >&2
      exit 2
    fi
    ;;
esac

bin_file="$OUTPUT_DIR/${artifact_prefix}_${git_sha}.bin"
bin_input_file="$bin_file"
if [[ ! -f "$bin_input_file" ]]; then
  bin_input_file="$DTGEN_OUTPUT_DIR/${artifact_prefix}_${git_sha}.bin"
fi
dtbo_file="$OUTPUT_DIR/${artifact_prefix}_${git_sha}.dtbo"
overlay_dir="$OUTPUT_DIR/${overlay_prefix}_${git_sha}"
overlay_zip="$OUTPUT_DIR/${overlay_prefix}_${git_sha}.zip"
json_file="$OUTPUT_DIR/shell.json"

if [[ ! -f "$bin_input_file" ]]; then
  echo "ERROR: expected bitstream binary not found in $OUTPUT_DIR or $DTGEN_OUTPUT_DIR" >&2
  exit 2
fi

echo "INFO: completing DTBO bundle for git SHA $git_sha"
echo "INFO: output dir = $OUTPUT_DIR"
if [[ "$DTGEN_OUTPUT_DIR" != "$OUTPUT_DIR" ]]; then
  echo "INFO: dtgen dir  = $DTGEN_OUTPUT_DIR"
fi
echo "INFO: dtgen tool = $DTGEN_CMD"
echo "INFO: xsa        = $latest_xsa"
echo "INFO: bin        = $bin_input_file"

pl_dtsi_path="$(
  find "$DTGEN_OUTPUT_DIR/${artifact_prefix}_${git_sha}" -type f -name 'pl.dtsi' 2>/dev/null | sort | head -n 1 || true
)"

if [[ -n "$pl_dtsi_path" ]]; then
  echo "INFO: reusing existing pl.dtsi at $pl_dtsi_path"
else
  generate_pl_dtsi "$latest_xsa" "$DTGEN_OUTPUT_DIR" "$git_sha" "$artifact_prefix" "$overlay_prefix"

  pl_dtsi_path="$(
    find "$DTGEN_OUTPUT_DIR/${artifact_prefix}_${git_sha}" -type f -name 'pl.dtsi' 2>/dev/null | sort | head -n 1 || true
  )"
fi

if [[ -z "$pl_dtsi_path" ]]; then
  echo "ERROR: device-tree generator completed but no pl.dtsi was generated under $DTGEN_OUTPUT_DIR/${artifact_prefix}_${git_sha}" >&2
  exit 2
fi

normalize_pl_dtsi "$pl_dtsi_path" "${overlay_prefix}_${git_sha}.bin"

if ! grep -Eq '(axi_intc|interrupt-controller)@9c010000' "$pl_dtsi_path"; then
  echo "ERROR: expected AXI interrupt controller node at 0x9C010000 was not found in $pl_dtsi_path" >&2
  exit 2
fi

if ! grep -q 'interrupt-controller;' "$pl_dtsi_path"; then
  echo "ERROR: generated pl.dtsi is missing AXI interrupt-controller provider flag after patching" >&2
  exit 2
fi

if ! grep -q '#interrupt-cells = <2>;' "$pl_dtsi_path"; then
  echo "ERROR: generated pl.dtsi is missing '#interrupt-cells = <2>;' for the AXI interrupt controller" >&2
  exit 2
fi

dtc -@ -O dtb -o "$dtbo_file" "$pl_dtsi_path"

mkdir -p "$overlay_dir"
printf '{ "shell_type" : "XRT_FLAT", "num_slots": "1" }\n' > "$json_file"
cp -f "$dtbo_file" "$overlay_dir/${overlay_prefix}_${git_sha}.dtbo"
cp -f "$bin_input_file" "$overlay_dir/${overlay_prefix}_${git_sha}.bin"
cp -f "$json_file" "$overlay_dir/shell.json"

(
  cd "$OUTPUT_DIR"
  rm -f "$(basename "$overlay_zip")"
  zip -r "$(basename "$overlay_zip")" "$(basename "$overlay_dir")" >/dev/null

  bundle_manifest="${overlay_prefix}_${git_sha}.SHA256SUMS"
  bundle_checksum_paths=(
    "${overlay_prefix}_${git_sha}.zip"
    "${overlay_prefix}_${git_sha}/${overlay_prefix}_${git_sha}.bin"
    "${overlay_prefix}_${git_sha}/${overlay_prefix}_${git_sha}.dtbo"
    "${overlay_prefix}_${git_sha}/shell.json"
  )
  "${SHA256_CMD[@]}" "${bundle_checksum_paths[@]}" > "$bundle_manifest"

  checksum_candidates=(
    "${artifact_prefix}_${git_sha}.bit"
    "${artifact_prefix}_${git_sha}.bin"
    "${artifact_prefix}_${git_sha}.xsa"
    "${artifact_prefix}_${git_sha}.dtbo"
    "${overlay_prefix}_${git_sha}.zip"
    "${overlay_prefix}_${git_sha}/${overlay_prefix}_${git_sha}.bin"
    "${overlay_prefix}_${git_sha}/${overlay_prefix}_${git_sha}.dtbo"
    "${overlay_prefix}_${git_sha}/shell.json"
    "$bundle_manifest"
    post_route_timing_summary.rpt
    post_route_bus_skew.rpt
    post_route_cdc.rpt
    post_route_methodology.rpt
    post_route_status.rpt
    post_route_power.rpt
    post_route_util.rpt
    post_imp_drc.rpt
  )
  checksum_paths=()
  for checksum_path in "${checksum_candidates[@]}"; do
    if [[ -s "$checksum_path" ]]; then
      checksum_paths+=("$checksum_path")
    fi
  done
  "${SHA256_CMD[@]}" "${checksum_paths[@]}" > SHA256SUMS
)

echo "INFO: generated artifacts:"
printf '  %s\n' \
  "$dtbo_file" \
  "$overlay_dir" \
  "$overlay_zip" \
  "$OUTPUT_DIR/${overlay_prefix}_${git_sha}.SHA256SUMS" \
  "$OUTPUT_DIR/SHA256SUMS"
