#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OUTPUT_DIR]

Complete the DT overlay bundle from an existing Vivado hardware handoff.

Expected inputs in OUTPUT_DIR:
  - daphne_selftrigger_<gitsha>.xsa
  - daphne_selftrigger_<gitsha>.bin
  - legacy daphne3_st_<gitsha>.xsa / daphne3_st_<gitsha>.bin are accepted

Generated outputs:
  - daphne_selftrigger_<gitsha>.dtbo
  - daphne_selftrigger_ol_<gitsha>/
  - daphne_selftrigger_ol_<gitsha>.zip
  - SHA256SUMS
EOF
}

is_wsl() {
  uname -r | grep -qiE 'microsoft|wsl'
}

find_latest_xsa() {
  local search_dir="$1"
  local candidate

  for pattern in 'daphne_selftrigger_*.xsa' 'daphne3_st_*.xsa'; do
    candidate="$(find "$search_dir" -maxdepth 1 -type f -name "$pattern" | sort | tail -n 1)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 0
}

select_xsct_output_dir() {
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

ensure_xsct() {
  if command -v xsct >/dev/null 2>&1; then
    return 0
  fi

  setup_script="$ROOT_DIR/scripts/wsl/setup_windows_xilinx.sh"
  if [[ -f "$setup_script" ]]; then
    # shellcheck disable=SC1090
    . "$setup_script"
  fi

  if ! command -v xsct >/dev/null 2>&1; then
    echo "ERROR: required command 'xsct' not found on PATH" >&2
    echo "ERROR: if you are running from WSL, source scripts/wsl/setup_windows_xilinx.sh first" >&2
    exit 2
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
OUTPUT_DIR_INPUT="${1:-${DAPHNE_OUTPUT_DIR:-$ROOT_DIR/xilinx/output}}"
OUTPUT_DIR="$(CDPATH= cd -- "$OUTPUT_DIR_INPUT" && pwd)"
XSCT_OUTPUT_DIR="$(select_xsct_output_dir "$OUTPUT_DIR")"
DTBO_GEN_TCL="$ROOT_DIR/xilinx/daphne_dtbo_gen.tcl"
AXI_SPI_PATCH="$ROOT_DIR/xilinx/scripts/axi_quad_spi_dtbo_patch.sed"
if command -v sha256sum >/dev/null 2>&1; then
  SHA256_CMD=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  SHA256_CMD=(shasum -a 256)
else
  echo "ERROR: neither sha256sum nor shasum is available on PATH" >&2
  exit 2
fi

ensure_xsct
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

latest_xsa="$(find_latest_xsa "$OUTPUT_DIR")"

if [[ -z "$latest_xsa" && "$XSCT_OUTPUT_DIR" != "$OUTPUT_DIR" ]]; then
  latest_xsa="$(find_latest_xsa "$XSCT_OUTPUT_DIR")"
fi

if [[ -z "$latest_xsa" ]]; then
  echo "ERROR: no daphne_selftrigger_*.xsa found in $OUTPUT_DIR or $XSCT_OUTPUT_DIR" >&2
  exit 2
fi

xsa_basename="$(basename "$latest_xsa")"
case "$xsa_basename" in
  daphne_selftrigger_*.xsa)
    artifact_prefix="daphne_selftrigger_"
    overlay_prefix="daphne_selftrigger_ol_"
    git_sha="${xsa_basename#daphne_selftrigger_}"
    git_sha="${git_sha%.xsa}"
    ;;
  daphne3_st_*.xsa)
    artifact_prefix="daphne3_st_"
    overlay_prefix="daphne3_st_OL_"
    git_sha="${xsa_basename#daphne3_st_}"
    git_sha="${git_sha%.xsa}"
    ;;
  *)
    echo "ERROR: unrecognized XSA name: $xsa_basename" >&2
    exit 2
    ;;
esac

bin_file="$OUTPUT_DIR/${artifact_prefix}${git_sha}.bin"
bin_input_file="$bin_file"
if [[ ! -f "$bin_input_file" ]]; then
  bin_input_file="$XSCT_OUTPUT_DIR/${artifact_prefix}${git_sha}.bin"
fi
dtbo_file="$OUTPUT_DIR/${artifact_prefix}${git_sha}.dtbo"
overlay_dir="$OUTPUT_DIR/${overlay_prefix}${git_sha}"
overlay_zip="$OUTPUT_DIR/${overlay_prefix}${git_sha}.zip"
json_file="$OUTPUT_DIR/shell.json"

if [[ ! -f "$bin_input_file" ]]; then
  echo "ERROR: expected bitstream binary not found in $OUTPUT_DIR or $XSCT_OUTPUT_DIR" >&2
  exit 2
fi

echo "INFO: completing DTBO bundle for git SHA $git_sha"
echo "INFO: output dir = $OUTPUT_DIR"
if [[ "$XSCT_OUTPUT_DIR" != "$OUTPUT_DIR" ]]; then
  echo "INFO: xsct dir   = $XSCT_OUTPUT_DIR"
fi
echo "INFO: xsa        = $latest_xsa"
echo "INFO: bin        = $bin_input_file"

xsct "$DTBO_GEN_TCL" "$latest_xsa" "$XSCT_OUTPUT_DIR" "$git_sha"

pl_dtsi_path="$(
  find "$XSCT_OUTPUT_DIR/${artifact_prefix}${git_sha}" -type f -name 'pl.dtsi' | sort | head -n 1
)"

if [[ -z "$pl_dtsi_path" ]]; then
  echo "ERROR: XSCT completed but no pl.dtsi was generated under $XSCT_OUTPUT_DIR/${artifact_prefix}${git_sha}" >&2
  exit 2
fi

sed -i.bak -f "$AXI_SPI_PATCH" "$pl_dtsi_path"
rm -f "${pl_dtsi_path}.bak"

dtc -@ -O dtb -o "$dtbo_file" "$pl_dtsi_path"

mkdir -p "$overlay_dir"
printf '{ "shell_type" : "XRT_FLAT", "num_slots": "1" }\n' > "$json_file"
cp -f "$dtbo_file" "$overlay_dir/daphne_selftrigger_ol_${git_sha}.dtbo"
cp -f "$bin_input_file" "$overlay_dir/daphne_selftrigger_ol_${git_sha}.bin"
cp -f "$json_file" "$overlay_dir/shell.json"

(
  cd "$OUTPUT_DIR"
  rm -f "$(basename "$overlay_zip")"
  zip -r "$(basename "$overlay_zip")" "$(basename "$overlay_dir")" >/dev/null
  "${SHA256_CMD[@]}" \
    "$(basename "$dtbo_file")" \
    "$(basename "$bin_file")" \
    "$(basename "$overlay_zip")" \
    "$(basename "$overlay_dir")/daphne_selftrigger_ol_${git_sha}.dtbo" \
    "$(basename "$overlay_dir")/daphne_selftrigger_ol_${git_sha}.bin" \
    "$(basename "$overlay_dir")/shell.json" > SHA256SUMS
)

echo "INFO: generated artifacts:"
printf '  %s\n' \
  "$dtbo_file" \
  "$overlay_dir" \
  "$overlay_zip" \
  "$OUTPUT_DIR/SHA256SUMS"
