#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
FORMAL_DIR="$ROOT_DIR/formal/sby"
OSS_CAD_ENV="${OSS_CAD_SUITE_ENV:-$HOME/tools/oss-cad-suite/environment}"

activate_oss_cad_suite() {
  if [[ -f "$OSS_CAD_ENV" ]]; then
    # shellcheck disable=SC1090
    . "$OSS_CAD_ENV"
  fi
}

discover_jobs() {
  find "$FORMAL_DIR" -maxdepth 1 -type f -name '*.sby' | LC_ALL=C sort
}

if ! command -v sby >/dev/null 2>&1 || [[ -z "${GHDL_PREFIX:-}" ]]; then
  activate_oss_cad_suite
fi

if ! command -v sby >/dev/null 2>&1; then
  echo "ERROR: symbiyosys (sby) is not installed or not on PATH." >&2
  echo "Hint: source ~/tools/oss-cad-suite/environment or set OSS_CAD_SUITE_ENV." >&2
  exit 2
fi

if [[ "${1:-}" == "--list" ]]; then
  discover_jobs
  exit 0
fi

if [[ "$#" -eq 0 ]]; then
  mapfile -t jobs < <(discover_jobs)
else
  jobs=("$@")
fi

for job in "${jobs[@]}"; do
  echo "Running formal proof $job"
  job_dir=$(dirname "$job")
  job_file=$(basename "$job")
  (
    cd "$job_dir"
    sby -f "$job_file"
  )
done
