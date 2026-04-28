#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap_kr260_project.sh PETALINUX_PROJECT_DIR [options]

Attach the repo-owned meta-daphne layer to an existing KR260-compatible
PetaLinux project.

This script:
  1. links or copies petalinux/meta-daphne into project-spec/meta-daphne
  2. appends the DAPHNE layer entry to build/conf/bblayers.conf
  3. appends the DAPHNE package set to build/conf/local.conf
  4. records the requested DAPHNE image profile in build/conf/local.conf

Options:
  --image-profile NAME   DAPHNE image profile: developer|minimal
                         (default: developer)
  -h, --help             Show this help

Environment:
  DAPHNE_META_LAYER_MODE=symlink|copy   default: symlink
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

PROJECT_ARG="$1"
shift

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
PROJECT_DIR="$(CDPATH= cd -- "$PROJECT_ARG" && pwd)"
META_LAYER_SRC="$ROOT_DIR/petalinux/meta-daphne"
CONFIG_DIR="$ROOT_DIR/petalinux/config/kr260"
LAYER_MODE="${DAPHNE_META_LAYER_MODE:-symlink}"
IMAGE_PROFILE="developer"

BUILD_CONF_DIR="$PROJECT_DIR/build/conf"
PROJECT_SPEC_DIR="$PROJECT_DIR/project-spec"
META_LAYER_DST="$PROJECT_SPEC_DIR/meta-daphne"
BBLAYERS_FILE="$BUILD_CONF_DIR/bblayers.conf"
LOCAL_CONF_FILE="$BUILD_CONF_DIR/local.conf"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-profile)
      IMAGE_PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$IMAGE_PROFILE" in
  developer|minimal)
    ;;
  *)
    echo "ERROR: unsupported --image-profile: $IMAGE_PROFILE" >&2
    exit 2
    ;;
esac

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: project directory does not exist: $PROJECT_ARG" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_SPEC_DIR" || ! -d "$BUILD_CONF_DIR" ]]; then
  echo "ERROR: $PROJECT_DIR does not look like an initialized PetaLinux project." >&2
  echo "Expected: $PROJECT_SPEC_DIR and $BUILD_CONF_DIR" >&2
  exit 2
fi

if [[ ! -d "$META_LAYER_SRC" ]]; then
  echo "ERROR: missing repo-owned meta layer: $META_LAYER_SRC" >&2
  exit 2
fi

install_meta_layer() {
  rm -rf "$META_LAYER_DST"
  case "$LAYER_MODE" in
    symlink)
      ln -s "$META_LAYER_SRC" "$META_LAYER_DST"
      ;;
    copy)
      cp -R "$META_LAYER_SRC" "$META_LAYER_DST"
      ;;
    *)
      echo "ERROR: unsupported DAPHNE_META_LAYER_MODE=$LAYER_MODE" >&2
      exit 2
      ;;
  esac
}

append_once() {
  local src="$1"
  local dst="$2"
  local marker_begin="$3"
  local marker_end="$4"

  if grep -Fq "$marker_begin" "$dst"; then
    return 0
  fi

  {
    printf '\n%s\n' "$marker_begin"
    cat "$src"
    printf '%s\n' "$marker_end"
  } >> "$dst"
}

upsert_profile_setting() {
  local dst="$1"
  local marker_begin="# >>> DAPHNE image profile >>>"
  local marker_end="# <<< DAPHNE image profile <<<"

  python3 - "$dst" "$marker_begin" "$marker_end" "$IMAGE_PROFILE" <<'PY'
from pathlib import Path
import sys

dst = Path(sys.argv[1])
begin = sys.argv[2]
end = sys.argv[3]
profile = sys.argv[4]
block = f"{begin}\nDAPHNE_IMAGE_PROFILE = \"{profile}\"\n{end}\n"
text = dst.read_text()

if begin in text and end in text:
    start = text.index(begin)
    finish = text.index(end, start) + len(end)
    if finish < len(text) and text[finish:finish + 1] == "\n":
        finish += 1
    text = text[:start] + block + text[finish:]
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += "\n" + block

dst.write_text(text)
PY
}

install_meta_layer

append_once \
  "$CONFIG_DIR/bblayers.conf.append" \
  "$BBLAYERS_FILE" \
  "# >>> DAPHNE meta-daphne >>>" \
  "# <<< DAPHNE meta-daphne <<<"

append_once \
  "$CONFIG_DIR/local.conf.append" \
  "$LOCAL_CONF_FILE" \
  "# >>> DAPHNE image packages >>>" \
  "# <<< DAPHNE image packages <<<"

upsert_profile_setting "$LOCAL_CONF_FILE"

cat <<EOF
Attached meta-daphne to:
  $META_LAYER_DST

Updated:
  $BBLAYERS_FILE
  $LOCAL_CONF_FILE

Selected DAPHNE image profile:
  $IMAGE_PROFILE

Next manual steps:
  1. Run petalinux-config --get-hw-description against the directory that contains your generated .xsa.
  2. Review device-tree integration under project-spec/meta-daphne/recipes-bsp/device-tree/files/.
  3. Stage overlay assets from xilinx/output/ once the firmware build is qualified.
  4. Build and validate the image on a KR260/PetaLinux host.
EOF
