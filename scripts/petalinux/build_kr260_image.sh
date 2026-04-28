#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build_kr260_image.sh PETALINUX_PROJECT_DIR HW_HANDOFF_DIR [options]

Create or reuse a KR260-compatible PetaLinux project, apply the hardware
handoff, attach the repo-owned layer, optionally stage the overlay payload,
run petalinux-build, package BOOT.BIN, and collect the resulting artifacts.

Project creation/config options:
  --bsp BSP_PATH          Create the project from a BSP
  --template NAME        PetaLinux template when --bsp is not given
  --image-profile NAME   DAPHNE image profile: developer|minimal
                         (default: developer)
  --output-dir DIR       Firmware xilinx/output directory for overlay staging
  --skip-stage-overlay   Do not stage overlay artifacts
  --copy-layer           Copy meta-daphne instead of symlinking it

Build/package options:
  --bundle-dir DIR       Repo-owned collection directory for resulting images
  --skip-package-boot    Do not run petalinux-package --boot
  --skip-collect         Do not collect artifacts after the build
  -h, --help             Show this help

Environment:
  DAPHNE_PETALINUX_BUILD_ARGS    extra args for petalinux-build
  DAPHNE_PETALINUX_PACKAGE_ARGS  extra args for petalinux-package --boot
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 2
fi

PROJECT_ARG="$1"
HW_HANDOFF_ARG="$2"
shift 2

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
PROJECT_NAME="$(basename "$PROJECT_ARG")"
BUNDLE_DIR="$ROOT_DIR/petalinux/output/$PROJECT_NAME"

INIT_ARGS=("$PROJECT_ARG" "$HW_HANDOFF_ARG")
STAGE_OVERLAY=1
PACKAGE_BOOT=1
COLLECT=1
BUILD_ARGS="${DAPHNE_PETALINUX_BUILD_ARGS:-}"
PACKAGE_ARGS="${DAPHNE_PETALINUX_PACKAGE_ARGS:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bsp|--template|--output-dir|--image-profile)
      INIT_ARGS+=("$1" "$2")
      shift 2
      ;;
    --skip-stage-overlay|--copy-layer)
      INIT_ARGS+=("$1")
      [[ "$1" == "--skip-stage-overlay" ]] && STAGE_OVERLAY=0
      shift
      ;;
    --bundle-dir)
      BUNDLE_DIR="$2"
      shift 2
      ;;
    --skip-package-boot)
      PACKAGE_BOOT=0
      shift
      ;;
    --skip-collect)
      COLLECT=0
      shift
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

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' not found on PATH" >&2
    exit 2
  }
}

need_cmd petalinux-build
if (( PACKAGE_BOOT )); then
  need_cmd petalinux-package
fi

"$ROOT_DIR/scripts/petalinux/init_kr260_project.sh" "${INIT_ARGS[@]}"

PROJECT_DIR="$(CDPATH= cd -- "$PROJECT_ARG" && pwd)"

(
  cd "$PROJECT_DIR"
  # shellcheck disable=SC2086
  petalinux-build $BUILD_ARGS
)

if (( PACKAGE_BOOT )); then
  (
    cd "$PROJECT_DIR"
    # shellcheck disable=SC2086
    petalinux-package --boot --u-boot --force $PACKAGE_ARGS
  )
fi

if (( COLLECT )); then
  "$ROOT_DIR/scripts/petalinux/collect_project_artifacts.sh" "$PROJECT_DIR" "$BUNDLE_DIR"
fi

missing=()
for rel in "boot/BOOT.BIN" "boot/Image" "boot/system.dtb"; do
  if [[ ! -f "$BUNDLE_DIR/$rel" ]]; then
    missing+=("$rel")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'ERROR: build completed but the collected bundle is still missing expected artifacts:\n' >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 3
fi

cat <<EOF
Full PetaLinux image bundle available under:
  $BUNDLE_DIR

Next validation step:
  review boot/, rootfs/, and overlay/ against ~/golden/daphne14-2026-03-12/
EOF
