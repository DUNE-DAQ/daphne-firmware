#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OUTPUT_DIR]

Complete the DT overlay bundle from an existing Vivado hardware handoff.

Expected inputs in OUTPUT_DIR:
  - daphne3_st_<gitsha>.xsa
  - daphne3_st_<gitsha>.bin

Generated outputs:
  - daphne3_st_<gitsha>.dtbo
  - daphne3_st_OL_<gitsha>/
  - daphne3_st_OL_<gitsha>.zip
  - SHA256SUMS
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' not found on PATH" >&2
    exit 2
  }
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
OUTPUT_DIR_INPUT="${1:-${DAPHNE_OUTPUT_DIR:-$ROOT_DIR/xilinx/output}}"
OUTPUT_DIR="$(CDPATH= cd -- "$OUTPUT_DIR_INPUT" && pwd)"
DTBO_GEN_TCL="$ROOT_DIR/xilinx/daphne3_dtbo_gen.tcl"
AXI_SPI_PATCH="$ROOT_DIR/xilinx/scripts/axi_quad_spi_dtbo_patch.sed"
if command -v sha256sum >/dev/null 2>&1; then
  SHA256_CMD=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  SHA256_CMD=(shasum -a 256)
else
  echo "ERROR: neither sha256sum nor shasum is available on PATH" >&2
  exit 2
fi

need_cmd xsct
need_cmd dtc
need_cmd zip

if [[ ! -d "$OUTPUT_DIR" ]]; then
  echo "ERROR: output directory does not exist: $OUTPUT_DIR_INPUT" >&2
  exit 2
fi

if [[ ! -f "$DTBO_GEN_TCL" ]]; then
  echo "ERROR: missing XSCT helper: $DTBO_GEN_TCL" >&2
  exit 2
fi

if [[ ! -f "$AXI_SPI_PATCH" ]]; then
  echo "ERROR: missing AXI Quad SPI patch: $AXI_SPI_PATCH" >&2
  exit 2
fi

latest_xsa="$(
  find "$OUTPUT_DIR" -maxdepth 1 -type f -name 'daphne3_st_*.xsa' | sort | tail -n 1
)"

if [[ -z "$latest_xsa" ]]; then
  echo "ERROR: no daphne3_st_*.xsa found in $OUTPUT_DIR" >&2
  exit 2
fi

xsa_basename="$(basename "$latest_xsa")"
git_sha="${xsa_basename#daphne3_st_}"
git_sha="${git_sha%.xsa}"

bin_file="$OUTPUT_DIR/daphne3_st_${git_sha}.bin"
dtbo_file="$OUTPUT_DIR/daphne3_st_${git_sha}.dtbo"
overlay_dir="$OUTPUT_DIR/daphne3_st_OL_${git_sha}"
overlay_zip="$OUTPUT_DIR/daphne3_st_OL_${git_sha}.zip"
json_file="$OUTPUT_DIR/shell.json"

if [[ ! -f "$bin_file" ]]; then
  echo "ERROR: expected bitstream binary not found: $bin_file" >&2
  exit 2
fi

echo "INFO: completing DTBO bundle for git SHA $git_sha"
echo "INFO: output dir = $OUTPUT_DIR"
echo "INFO: xsa        = $latest_xsa"
echo "INFO: bin        = $bin_file"

xsct "$DTBO_GEN_TCL" "$latest_xsa" "$OUTPUT_DIR" "$git_sha"

pl_dtsi_path="$(
  find "$OUTPUT_DIR/daphne3_st_${git_sha}" -type f -name 'pl.dtsi' | sort | head -n 1
)"

if [[ -z "$pl_dtsi_path" ]]; then
  echo "ERROR: XSCT completed but no pl.dtsi was generated under $OUTPUT_DIR/daphne3_st_${git_sha}" >&2
  exit 2
fi

sed -i.bak -f "$AXI_SPI_PATCH" "$pl_dtsi_path"
rm -f "${pl_dtsi_path}.bak"

dtc -@ -O dtb -o "$dtbo_file" "$pl_dtsi_path"

mkdir -p "$overlay_dir"
printf '{ "shell_type" : "XRT_FLAT", "num_slots": "1" }\n' > "$json_file"
cp -f "$dtbo_file" "$overlay_dir/daphne3_st_OL_${git_sha}.dtbo"
cp -f "$bin_file" "$overlay_dir/daphne3_st_OL_${git_sha}.bin"
cp -f "$json_file" "$overlay_dir/shell.json"

(
  cd "$OUTPUT_DIR"
  rm -f "$(basename "$overlay_zip")"
  zip -r "$(basename "$overlay_zip")" "$(basename "$overlay_dir")" >/dev/null
  "${SHA256_CMD[@]}" \
    "$(basename "$dtbo_file")" \
    "$(basename "$bin_file")" \
    "$(basename "$overlay_zip")" \
    "$(basename "$overlay_dir")/daphne3_st_OL_${git_sha}.dtbo" \
    "$(basename "$overlay_dir")/daphne3_st_OL_${git_sha}.bin" \
    "$(basename "$overlay_dir")/shell.json" > SHA256SUMS
)

echo "INFO: generated artifacts:"
printf '  %s\n' \
  "$dtbo_file" \
  "$overlay_dir" \
  "$overlay_zip" \
  "$OUTPUT_DIR/SHA256SUMS"
