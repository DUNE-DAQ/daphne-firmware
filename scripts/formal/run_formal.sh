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

resolve_job() {
  local job="$1"

  case "$job" in
    /*)
      printf '%s\n' "$job"
      ;;
    *.sby)
      if [[ -f "$job" ]]; then
        printf '%s\n' "$job"
      else
        printf '%s\n' "$FORMAL_DIR/${job##*/}"
      fi
      ;;
    *)
      printf '%s\n' "$FORMAL_DIR/$job.sby"
      ;;
  esac
}

list_suite() {
  case "$1" in
    default)
      cat <<'EOF'
fe_axi_axi_lite
thresholds_axi_lite
frontend_register_slice_contract
control_plane_boundary_contract
EOF
      ;;
    leaf-fast)
      cat <<'EOF'
afe_capture_slice_boundary_contract
afe_capture_to_trigger_bank_contract
afe_config_slice_boundary_contract
analog_control_boundary_contract
configurable_delay_line_contract
control_plane_boundary_contract
fe_axi_axi_lite
fixed_delay_line_contract
frontend_boundary_gate
frontend_register_slice_contract
frontend_to_selftrigger_adapter_contract
spy_buffer_boundary_gate
thresholds_axi_lite
trigger_pipeline_boundary_gate
EOF
      ;;
    cover-fast)
      cat <<'EOF'
fe_axi_axi_lite_cover
thresholds_axi_lite_cover
EOF
      ;;
    composable)
      cat <<'EOF'
daphne_composable_core_top_contract
daphne_composable_frontend_shell_contract
daphne_composable_top_contract
EOF
      ;;
    composable-cover)
      cat <<'EOF'
daphne_composable_top_cover
EOF
      ;;
    all-local)
      discover_jobs
      ;;
    *)
      echo "ERROR: unknown formal suite '$1'" >&2
      echo "Known suites: default, leaf-fast, cover-fast, composable, composable-cover, all-local" >&2
      exit 2
      ;;
  esac
}

print_suite_names() {
  printf '%s\n' default leaf-fast cover-fast composable composable-cover all-local
}

if ! command -v sby >/dev/null 2>&1 || [[ -z "${GHDL_PREFIX:-}" ]]; then
  activate_oss_cad_suite
fi

if ! command -v sby >/dev/null 2>&1; then
  echo "ERROR: symbiyosys (sby) is not installed or not on PATH." >&2
  echo "Hint: source ~/tools/oss-cad-suite/environment or set OSS_CAD_SUITE_ENV." >&2
  exit 2
fi

suite_name=""
requested_jobs=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --list)
      discover_jobs
      exit 0
      ;;
    --list-suites)
      print_suite_names
      exit 0
      ;;
    --suite)
      if [[ "$#" -lt 2 ]]; then
        echo "ERROR: --suite requires a suite name." >&2
        exit 2
      fi
      suite_name="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/formal/run_formal.sh [--list] [--list-suites] [--suite NAME] [job ...]

Without arguments, run every checked-in .sby job under formal/sby/.
EOF
      exit 0
      ;;
    *)
      requested_jobs+=("$1")
      shift
      ;;
  esac
done

jobs=()
if [[ -n "$suite_name" ]]; then
  suite_jobs=()
  while IFS= read -r suite_job; do
    suite_jobs+=("$suite_job")
  done < <(list_suite "$suite_name")
  requested_jobs+=("${suite_jobs[@]}")
fi

if [[ "${#requested_jobs[@]}" -eq 0 ]]; then
  while IFS= read -r discovered_job; do
    jobs+=("$discovered_job")
  done < <(discover_jobs)
else
  for job in "${requested_jobs[@]}"; do
    job_path=$(resolve_job "$job")
    if [[ ! -f "$job_path" ]]; then
      echo "ERROR: formal job not found: $job" >&2
      exit 2
    fi
    jobs+=("$job_path")
  done
fi

passed_jobs=()
failed_jobs=()

for job in "${jobs[@]}"; do
  echo "Running formal proof $job"
  job_dir=$(dirname "$job")
  job_file=$(basename "$job")
  if (
    cd "$job_dir"
    sby -f "$job_file"
  ); then
    passed_jobs+=("$job")
  else
    failed_jobs+=("$job")
  fi
done

echo
echo "Formal summary: ${#passed_jobs[@]} passed, ${#failed_jobs[@]} failed"
if [[ "${#failed_jobs[@]}" -gt 0 ]]; then
  printf 'Failed jobs:\n'
  printf '  %s\n' "${failed_jobs[@]}"
  exit 1
fi
