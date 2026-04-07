#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: stage_overlay_into_project.sh PETALINUX_PROJECT_DIR [OUTPUT_DIR]

Copy the generated DAPHNE overlay artifacts from xilinx/output into the
repo-owned meta-daphne layer inside an initialized PetaLinux project.

Expected source artifacts:
  - <overlay-name-prefix>_<gitsha>/
  - <overlay-name-prefix>_<gitsha>.zip
  - legacy daphne3_st_OL_<gitsha>/ and daphne3_st_OL_<gitsha>.zip are accepted
  - SHA256SUMS

The staged canonical filenames are:
  - daphne-overlay.dtbo
  - daphne-overlay.bin
  - shell.json
  - SHA256SUMS
  - BUILD-METADATA.txt
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 || $# -gt 2 ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"
PROJECT_DIR="$(CDPATH= cd -- "$1" && pwd)"
OUTPUT_DIR_INPUT="${2:-${DAPHNE_OUTPUT_DIR:-$ROOT_DIR/xilinx/output}}"
OUTPUT_DIR="$(CDPATH= cd -- "$OUTPUT_DIR_INPUT" && pwd)"
OVERLAY_NAME_PREFIX="${DAPHNE_OVERLAY_NAME_PREFIX:-daphne_selftrigger_ol}"

META_LAYER_DIR="$PROJECT_DIR/project-spec/meta-daphne"
STAGED_DIR="$META_LAYER_DIR/recipes-firmware/daphne-overlay/files/staged"

if [[ ! -d "$PROJECT_DIR/project-spec" || ! -d "$PROJECT_DIR/build/conf" ]]; then
  echo "ERROR: $PROJECT_DIR does not look like an initialized PetaLinux project." >&2
  exit 2
fi

if [[ ! -d "$META_LAYER_DIR" ]]; then
  echo "ERROR: missing project-spec/meta-daphne in $PROJECT_DIR" >&2
  echo "Run scripts/petalinux/bootstrap_kr260_project.sh first." >&2
  exit 2
fi

overlay_zip=""
for pattern in "${OVERLAY_NAME_PREFIX}_*.zip" 'daphne3_st_OL_*.zip'; do
  candidate="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name "$pattern" | sort | tail -n 1)"
  if [[ -n "$candidate" ]]; then
    overlay_zip="$candidate"
    break
  fi
done

if [[ -z "$overlay_zip" ]]; then
  echo "ERROR: no ${OVERLAY_NAME_PREFIX}_*.zip or daphne3_st_OL_*.zip found in $OUTPUT_DIR" >&2
  echo "Run scripts/package/complete_dtbo_bundle.sh first." >&2
  exit 2
fi

overlay_zip_base="$(basename "$overlay_zip")"
case "$overlay_zip_base" in
  ${OVERLAY_NAME_PREFIX}_*.zip)
    overlay_prefix="${OVERLAY_NAME_PREFIX}"
    ;;
  daphne3_st_OL_*.zip)
    overlay_prefix="daphne3_st_OL"
    ;;
  *)
    echo "ERROR: unrecognized overlay zip name: $overlay_zip_base" >&2
    exit 2
    ;;
esac

git_sha="${overlay_zip_base#${overlay_prefix}_}"
git_sha="${git_sha%.zip}"
overlay_dir="$OUTPUT_DIR/${overlay_prefix}_${git_sha}"
sha_file="$OUTPUT_DIR/SHA256SUMS"

if [[ ! -d "$overlay_dir" ]]; then
  echo "ERROR: missing overlay directory: $overlay_dir" >&2
  exit 2
fi

dtbo_src="$overlay_dir/${overlay_prefix}_${git_sha}.dtbo"
bin_src="$overlay_dir/${overlay_prefix}_${git_sha}.bin"
json_src="$overlay_dir/shell.json"

for f in "$dtbo_src" "$bin_src" "$json_src"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing staged source artifact: $f" >&2
    exit 2
  fi
done

mkdir -p "$STAGED_DIR"
cp -f "$dtbo_src" "$STAGED_DIR/daphne-overlay.dtbo"
cp -f "$bin_src" "$STAGED_DIR/daphne-overlay.bin"
cp -f "$json_src" "$STAGED_DIR/shell.json"
if [[ -f "$sha_file" ]]; then
  cp -f "$sha_file" "$STAGED_DIR/SHA256SUMS"
else
  rm -f "$STAGED_DIR/SHA256SUMS"
fi

cat > "$STAGED_DIR/BUILD-METADATA.txt" <<EOF
git_sha=${git_sha}
overlay_dir=${overlay_dir}
overlay_zip=${overlay_zip}
source_output_dir=${OUTPUT_DIR}
staged_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

cat <<EOF
Staged overlay artifacts into:
  $STAGED_DIR

Files:
  $STAGED_DIR/daphne-overlay.dtbo
  $STAGED_DIR/daphne-overlay.bin
  $STAGED_DIR/shell.json
  $STAGED_DIR/BUILD-METADATA.txt
$( [[ -f "$STAGED_DIR/SHA256SUMS" ]] && printf '  %s\n' "$STAGED_DIR/SHA256SUMS" )
EOF
