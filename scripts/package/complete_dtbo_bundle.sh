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
  - SHA256SUMS
EOF
}

is_wsl() {
  uname -r | grep -qiE 'microsoft|wsl'
}

find_latest_xsa() {
  local search_dir="$1"
  local candidate

  for pattern in "${BUILD_NAME_PREFIX}_*.xsa"; do
    candidate="$(find "$search_dir" -maxdepth 1 -type f -name "$pattern" | sort | tail -n 1)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [[ "$ACCEPT_LEGACY_ARTIFACT_ALIASES" == "1" ]]; then
    for pattern in "${LEGACY_ARTIFACT_PREFIX}_*.xsa"; do
      candidate="$(find "$search_dir" -maxdepth 1 -type f -name "$pattern" | sort | tail -n 1)"
      if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  fi

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
BOARD="${DAPHNE_BOARD:-k26c}"
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
OUTPUT_DIR="$(CDPATH= cd -- "$OUTPUT_DIR_INPUT" && pwd)"
XSCT_OUTPUT_DIR="$(select_xsct_output_dir "$OUTPUT_DIR")"
DTBO_GEN_TCL="$ROOT_DIR/xilinx/daphne_dtbo_gen.tcl"
AXI_SPI_PATCH="$ROOT_DIR/xilinx/scripts/axi_quad_spi_dtbo_patch.sed"
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
  echo "ERROR: no ${BUILD_NAME_PREFIX}_*.xsa found in $OUTPUT_DIR or $XSCT_OUTPUT_DIR" >&2
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
    git_sha="${xsa_basename#${BUILD_NAME_PREFIX}_}"
    git_sha="${git_sha%.xsa}"
    ;;
  *)
    if [[ "$ACCEPT_LEGACY_ARTIFACT_ALIASES" == "1" && "$xsa_basename" == ${LEGACY_ARTIFACT_PREFIX}_*.xsa ]]; then
      artifact_prefix="${LEGACY_ARTIFACT_PREFIX}"
      overlay_prefix="${LEGACY_OVERLAY_PREFIX}"
      git_sha="${xsa_basename#${LEGACY_ARTIFACT_PREFIX}_}"
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
  bin_input_file="$XSCT_OUTPUT_DIR/${artifact_prefix}_${git_sha}.bin"
fi
dtbo_file="$OUTPUT_DIR/${artifact_prefix}_${git_sha}.dtbo"
overlay_dir="$OUTPUT_DIR/${overlay_prefix}_${git_sha}"
overlay_zip="$OUTPUT_DIR/${overlay_prefix}_${git_sha}.zip"
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

xsct "$DTBO_GEN_TCL" "$latest_xsa" "$XSCT_OUTPUT_DIR" "$git_sha" "$artifact_prefix" "$overlay_prefix"

pl_dtsi_path="$(
  find "$XSCT_OUTPUT_DIR/${artifact_prefix}_${git_sha}" -type f -name 'pl.dtsi' | sort | head -n 1
)"

if [[ -z "$pl_dtsi_path" ]]; then
  echo "ERROR: XSCT completed but no pl.dtsi was generated under $XSCT_OUTPUT_DIR/${artifact_prefix}_${git_sha}" >&2
  exit 2
fi

sed -i.bak -f "$AXI_SPI_PATCH" "$pl_dtsi_path"
rm -f "${pl_dtsi_path}.bak"

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
  "${SHA256_CMD[@]}" \
    "$(basename "$dtbo_file")" \
    "$(basename "$bin_file")" \
    "$(basename "$overlay_zip")" \
    "$(basename "$overlay_dir")/${overlay_prefix}_${git_sha}.dtbo" \
    "$(basename "$overlay_dir")/${overlay_prefix}_${git_sha}.bin" \
    "$(basename "$overlay_dir")/shell.json" > SHA256SUMS
)

echo "INFO: generated artifacts:"
printf '  %s\n' \
  "$dtbo_file" \
  "$overlay_dir" \
  "$overlay_zip" \
  "$OUTPUT_DIR/SHA256SUMS"
