#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
BUILD_ROOT_BASE="${DAPHNE_FUSESOC_BUILD_ROOT:-$ROOT_DIR/build/fusesoc-logic}"

list_suite() {
  case "$1" in
    default)
      cat <<'EOF'
dune-daq:daphne:config-control:0.1.0
dune-daq:daphne:selftrigger:0.1.0
dune-daq:daphne:frontend-control:0.1.0
EOF
      ;;
    composable)
      cat <<'EOF'
dune-daq:daphne:daphne-composable-core-top:0.1.0
dune-daq:daphne:daphne-composable-frontend-shell:0.1.0
dune-daq:daphne:daphne-composable-top:0.1.0
EOF
      ;;
    all-local)
      list_suite default
      list_suite composable
      ;;
    *)
      echo "ERROR: unknown smoke suite '$1'" >&2
      echo "Known suites: default, composable, all-local" >&2
      exit 2
      ;;
  esac
}

if ! command -v ghdl >/dev/null 2>&1; then
  echo "ERROR: ghdl is not installed." >&2
  echo "Install GHDL first, then rerun this smoke test." >&2
  exit 2
fi

if [ "${1:-}" = "--list-suites" ]; then
  printf '%s\n' default composable all-local
  exit 0
fi

if [ "${1:-}" = "--suite" ]; then
  if [ "$#" -lt 2 ]; then
    echo "ERROR: --suite requires a suite name." >&2
    exit 2
  fi
  suite_name="$2"
  shift 2
  set -- $(list_suite "$suite_name") "$@"
elif [ "$#" -eq 0 ]; then
  set -- $(list_suite default)
fi

for core in "$@"; do
  core_build_root=$(printf '%s' "$core" | tr ':/' '__' | tr -c 'A-Za-z0-9._-' '_')
  echo "Running $core"
  "$ROOT_DIR/scripts/fusesoc/fusesoc.sh" run \
    --clean \
    --target sim \
    --tool ghdl \
    --build-root "$BUILD_ROOT_BASE/$core_build_root" \
    "$core"
done
