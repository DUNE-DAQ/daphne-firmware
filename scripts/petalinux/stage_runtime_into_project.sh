#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: stage_runtime_into_project.sh PETALINUX_PROJECT_DIR RUNTIME_BUNDLE_TGZ

Copy a qualified DAPHNE userspace runtime bundle into the repo-owned
meta-daphne layer inside an initialized PetaLinux project.

The staged canonical filenames are:
  - daphne-server-runtime-minimal.tgz
  - BUILD-METADATA.txt
  - SHA256SUMS
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 2 ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi

PROJECT_DIR="$(CDPATH= cd -- "$1" && pwd)"
RUNTIME_BUNDLE_INPUT="$2"
RUNTIME_BUNDLE="$(CDPATH= cd -- "$(dirname -- "$RUNTIME_BUNDLE_INPUT")" && pwd)/$(basename -- "$RUNTIME_BUNDLE_INPUT")"
META_LAYER_DIR="$PROJECT_DIR/project-spec/meta-daphne"
STAGED_DIR="$META_LAYER_DIR/recipes-apps/daphne-server/files/staged"

if [[ ! -d "$PROJECT_DIR/project-spec" || ! -d "$PROJECT_DIR/build/conf" ]]; then
  echo "ERROR: $PROJECT_DIR does not look like an initialized PetaLinux project." >&2
  exit 2
fi

if [[ ! -d "$META_LAYER_DIR" ]]; then
  echo "ERROR: missing project-spec/meta-daphne in $PROJECT_DIR" >&2
  echo "Run scripts/petalinux/bootstrap_kr260_project.sh first." >&2
  exit 2
fi

if [[ ! -f "$RUNTIME_BUNDLE" ]]; then
  echo "ERROR: missing runtime bundle: $RUNTIME_BUNDLE" >&2
  exit 2
fi

mkdir -p "$STAGED_DIR"
cp -f "$RUNTIME_BUNDLE" "$STAGED_DIR/daphne-server-runtime-minimal.tgz"

cat > "$STAGED_DIR/BUILD-METADATA.txt" <<EOF
artifact=daphne-server-runtime-minimal.tgz
sha256=$(sha256sum "$RUNTIME_BUNDLE" | awk '{print $1}')
provenance=external-qualified-input
EOF

(
  cd "$STAGED_DIR"
  sha256sum daphne-server-runtime-minimal.tgz > SHA256SUMS
)

cat <<EOF
Staged runtime bundle into:
  $STAGED_DIR

Files:
  $STAGED_DIR/daphne-server-runtime-minimal.tgz
  $STAGED_DIR/BUILD-METADATA.txt
  $STAGED_DIR/SHA256SUMS
EOF
