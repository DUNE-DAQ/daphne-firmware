#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: collect_project_artifacts.sh PETALINUX_PROJECT_DIR [BUNDLE_DIR]

Collect boot, DT, rootfs, and staged overlay artifacts from a built PetaLinux
project into a stable repo-owned bundle directory.

Default bundle directory:
  petalinux/output/<project-name>
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 || $# -gt 2 ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
PROJECT_DIR="$(CDPATH= cd -- "$1" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
BUNDLE_DIR_INPUT="${2:-$ROOT_DIR/petalinux/output/$PROJECT_NAME}"
BUNDLE_DIR="$BUNDLE_DIR_INPUT"

IMAGES_DIR="$PROJECT_DIR/images/linux"
STAGED_DIR="$PROJECT_DIR/project-spec/meta-daphne/recipes-firmware/daphne-overlay/files/staged"
BOOT_DIR="$BUNDLE_DIR/boot"
ROOTFS_DIR="$BUNDLE_DIR/rootfs"
OVERLAY_DIR="$BUNDLE_DIR/overlay"
META_DIR="$BUNDLE_DIR/meta"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' not found on PATH" >&2
    exit 2
  }
}

need_cmd find
need_cmd sort

if [[ ! -d "$PROJECT_DIR/project-spec" || ! -d "$PROJECT_DIR/build/conf" ]]; then
  echo "ERROR: $PROJECT_DIR does not look like an initialized PetaLinux project." >&2
  exit 2
fi

if [[ ! -d "$IMAGES_DIR" ]]; then
  echo "ERROR: missing images directory: $IMAGES_DIR" >&2
  echo "Run petalinux-build first." >&2
  exit 2
fi

mkdir -p "$BOOT_DIR" "$ROOTFS_DIR" "$OVERLAY_DIR" "$META_DIR"

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$dst"
  fi
}

copy_glob_matches() {
  local src_dir="$1"
  local pattern="$2"
  local dst_dir="$3"
  find "$src_dir" -maxdepth 1 -type f -name "$pattern" -print | sort | while read -r path; do
    cp -f "$path" "$dst_dir/$(basename "$path")"
  done
}

copy_if_exists "$IMAGES_DIR/BOOT.BIN" "$BOOT_DIR/BOOT.BIN"
copy_if_exists "$IMAGES_DIR/Image" "$BOOT_DIR/Image"
copy_if_exists "$IMAGES_DIR/boot.scr" "$BOOT_DIR/boot.scr"
copy_if_exists "$IMAGES_DIR/system.dtb" "$BOOT_DIR/system.dtb"
copy_if_exists "$IMAGES_DIR/image.ub" "$BOOT_DIR/image.ub"
copy_if_exists "$IMAGES_DIR/ramdisk.cpio.gz.u-boot" "$BOOT_DIR/ramdisk.cpio.gz.u-boot"
copy_if_exists "$IMAGES_DIR/rootfs.cpio.gz.u-boot" "$BOOT_DIR/rootfs.cpio.gz.u-boot"

copy_glob_matches "$IMAGES_DIR" "*.dtb" "$BOOT_DIR"
copy_glob_matches "$IMAGES_DIR" "*.dtbo" "$BOOT_DIR"

copy_if_exists "$IMAGES_DIR/rootfs.ext4" "$ROOTFS_DIR/rootfs.ext4"
copy_if_exists "$IMAGES_DIR/rootfs.ext4.gz" "$ROOTFS_DIR/rootfs.ext4.gz"
copy_if_exists "$IMAGES_DIR/rootfs.tar.gz" "$ROOTFS_DIR/rootfs.tar.gz"
copy_if_exists "$IMAGES_DIR/rootfs.wic" "$ROOTFS_DIR/rootfs.wic"
copy_if_exists "$IMAGES_DIR/rootfs.wic.gz" "$ROOTFS_DIR/rootfs.wic.gz"
copy_if_exists "$IMAGES_DIR/rootfs.cpio.gz" "$ROOTFS_DIR/rootfs.cpio.gz"
copy_if_exists "$IMAGES_DIR/rootfs.manifest" "$ROOTFS_DIR/rootfs.manifest"

if [[ -d "$STAGED_DIR" ]]; then
  copy_if_exists "$STAGED_DIR/daphne-overlay.dtbo" "$OVERLAY_DIR/daphne-overlay.dtbo"
  copy_if_exists "$STAGED_DIR/daphne-overlay.bin" "$OVERLAY_DIR/daphne-overlay.bin"
  copy_if_exists "$STAGED_DIR/shell.json" "$OVERLAY_DIR/shell.json"
  copy_if_exists "$STAGED_DIR/SHA256SUMS" "$OVERLAY_DIR/SHA256SUMS"
  copy_if_exists "$STAGED_DIR/BUILD-METADATA.txt" "$OVERLAY_DIR/BUILD-METADATA.txt"
fi

cat > "$META_DIR/COLLECT-METADATA.txt" <<EOF
project_dir=$PROJECT_DIR
project_name=$PROJECT_NAME
images_dir=$IMAGES_DIR
staged_overlay_dir=$STAGED_DIR
collected_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

(
  cd "$BUNDLE_DIR"
  find . -type f | sort > MANIFEST.txt
)

checksum_cmd=()
if command -v sha256sum >/dev/null 2>&1; then
  checksum_cmd=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  checksum_cmd=(shasum -a 256)
else
  checksum_cmd=()
fi

if (( ${#checksum_cmd[@]} > 0 )); then
  (
    cd "$BUNDLE_DIR"
    find . -type f ! -name SHA256SUMS | sort | xargs "${checksum_cmd[@]}" > SHA256SUMS
  )
fi

cat <<EOF
Collected PetaLinux artifacts into:
  $BUNDLE_DIR

Boot dir:
  $BOOT_DIR
Rootfs dir:
  $ROOTFS_DIR
Overlay dir:
  $OVERLAY_DIR
Meta dir:
  $META_DIR
EOF
