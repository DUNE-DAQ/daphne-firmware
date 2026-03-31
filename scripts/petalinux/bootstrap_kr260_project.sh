#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap_kr260_project.sh PETALINUX_PROJECT_DIR

Attach the repo-owned meta-daphne layer to an existing KR260-compatible
PetaLinux project.

This script:
  1. links or copies petalinux/meta-daphne into project-spec/meta-daphne
  2. appends the DAPHNE layer entry to build/conf/bblayers.conf
  3. appends the DAPHNE package set to build/conf/local.conf

Environment:
  DAPHNE_META_LAYER_MODE=symlink|copy   default: symlink
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 1 ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
PROJECT_DIR="$(CDPATH= cd -- "$1" && pwd)"
META_LAYER_SRC="$ROOT_DIR/petalinux/meta-daphne"
CONFIG_DIR="$ROOT_DIR/petalinux/config/kr260"
LAYER_MODE="${DAPHNE_META_LAYER_MODE:-symlink}"

BUILD_CONF_DIR="$PROJECT_DIR/build/conf"
PROJECT_SPEC_DIR="$PROJECT_DIR/project-spec"
META_LAYER_DST="$PROJECT_SPEC_DIR/meta-daphne"
BBLAYERS_FILE="$BUILD_CONF_DIR/bblayers.conf"
LOCAL_CONF_FILE="$BUILD_CONF_DIR/local.conf"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: project directory does not exist: $1" >&2
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

cat <<EOF
Attached meta-daphne to:
  $META_LAYER_DST

Updated:
  $BBLAYERS_FILE
  $LOCAL_CONF_FILE

Next manual steps:
  1. Run petalinux-config --get-hw-description against the directory that contains your generated .xsa.
  2. Review device-tree integration under project-spec/meta-daphne/recipes-bsp/device-tree/files/.
  3. Stage overlay assets from xilinx/output/ once the firmware build is qualified.
  4. Build and validate the image on a KR260/PetaLinux host.
EOF
