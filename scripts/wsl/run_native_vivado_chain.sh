#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_native_vivado_chain.sh [options]

Run the supported native-Linux Vivado/Vitis flow from WSL or a Linux host.
This wrapper auto-detects Linux-installed Vivado/Vitis settings scripts,
verifies that PATH resolves to the native Linux tools, and then delegates to
scripts/remote/run_remote_vivado_chain.sh.

Options:
  --board <name>                         Set DAPHNE_BOARD (default: k26c)
  --eth-mode <mode>                      Set DAPHNE_ETH_MODE (default: create_ip)
  --platform-core <vlvn>                 Set DAPHNE_PLATFORM_CORE
  --target <name>                        Set DAPHNE_PLATFORM_TARGET
  --threads <n>                          Set DAPHNE_MAX_THREADS
  --output-dir <path>                    Set DAPHNE_OUTPUT_DIR
  --git-sha <sha>                        Set DAPHNE_GIT_SHA
  --vivado-settings <settings64.sh>      Use this Vivado settings script
  --vitis-settings <settings64.sh>       Use this Vitis settings script
  --log-dir <path>                       Set DAPHNE_REMOTE_LOG_DIR
  --run-id <id>                          Set DAPHNE_REMOTE_RUN_ID
  --stop-after-synth                     Set DAPHNE_STOP_AFTER_SYNTH=1
  --dump-post-synth-debug                Set DAPHNE_DUMP_POST_SYNTH_DEBUG=1
  --synth-directive <name>               Set DAPHNE_SYNTH_DIRECTIVE
  --opt-directive <name>                 Set DAPHNE_OPT_DIRECTIVE
  --post-place-physopt <name>            Set DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE
  --dry-run                              Print the resolved environment and exit
  -h, --help                             Show this help

Environment:
  XILINX_SETTINGS_SH                     Preferred Vivado settings script
  XILINX_VITIS_SETTINGS_SH               Preferred Vitis settings script
  DAPHNE_NATIVE_XILINX_ROOTS             Colon-separated native Linux install roots

Notes:
  - This wrapper intentionally ignores Windows install roots such as /mnt/c/Xilinx.
  - This repo's native Linux Tcl flow expects both Vivado and Vitis/XSCT.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

require_arg() {
  [ "$#" -ge 2 ] || die "missing value for $1"
}

append_unique_root() {
  local candidate="$1"
  local existing

  [ -n "$candidate" ] || return 0
  [ -d "$candidate" ] || return 0

  for existing in "${SEARCH_ROOTS[@]}"; do
    if [ "$existing" = "$candidate" ]; then
      return 0
    fi
  done

  SEARCH_ROOTS+=("$candidate")
}

detect_settings_script() {
  local product="$1"
  local root
  local settings_path

  for root in "${SEARCH_ROOTS[@]}"; do
    [ -d "$root/$product" ] || continue
    settings_path="$(
      find "$root/$product" -mindepth 2 -maxdepth 2 -type f -name settings64.sh 2>/dev/null |
      sort -V |
      tail -n 1
    )"
    if [ -n "$settings_path" ]; then
      printf '%s\n' "$settings_path"
      return 0
    fi
  done

  return 1
}

ensure_native_tool() {
  local tool_name="$1"
  local resolved_tool="$2"
  local expected_tool="$3"

  [ -n "$resolved_tool" ] || die "$tool_name is not on PATH after sourcing $expected_tool"
  [ -x "$expected_tool" ] || die "expected $tool_name binary does not exist: $expected_tool"

  case "$resolved_tool" in
    /mnt/*|"$HOME"/.local/bin/*|"$HOME"/.cache/daphne-wsl-xilinx/*)
      die "$tool_name resolved to a non-native path: $resolved_tool"
      ;;
  esac

  if [ "$resolved_tool" != "$expected_tool" ]; then
    die "$tool_name resolved to $resolved_tool instead of $expected_tool"
  fi
}

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
ETH_MODE="${DAPHNE_ETH_MODE:-create_ip}"
DRY_RUN=0
POST_PACKAGE=0
VIVADO_SETTINGS_SH="${XILINX_SETTINGS_SH:-}"
VITIS_SETTINGS_SH="${XILINX_VITIS_SETTINGS_SH:-}"
SEARCH_ROOTS=()

if [ -n "${DAPHNE_NATIVE_XILINX_ROOTS:-}" ]; then
  OLD_IFS="$IFS"
  IFS=':'
  for root in ${DAPHNE_NATIVE_XILINX_ROOTS}; do
    append_unique_root "$root"
  done
  IFS="$OLD_IFS"
fi

append_unique_root "$HOME/tools/Xilinx"
append_unique_root "/opt/Xilinx"
append_unique_root "/tools/Xilinx"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --board)
      require_arg "$@"
      BOARD="$2"
      shift 2
      ;;
    --eth-mode)
      require_arg "$@"
      ETH_MODE="$2"
      shift 2
      ;;
    --platform-core)
      require_arg "$@"
      export DAPHNE_PLATFORM_CORE="$2"
      shift 2
      ;;
    --target|--platform-target)
      require_arg "$@"
      export DAPHNE_PLATFORM_TARGET="$2"
      shift 2
      ;;
    --threads)
      require_arg "$@"
      export DAPHNE_MAX_THREADS="$2"
      shift 2
      ;;
    --output-dir)
      require_arg "$@"
      export DAPHNE_OUTPUT_DIR="$2"
      shift 2
      ;;
    --git-sha)
      require_arg "$@"
      export DAPHNE_GIT_SHA="$2"
      shift 2
      ;;
    --vivado-settings)
      require_arg "$@"
      VIVADO_SETTINGS_SH="$2"
      shift 2
      ;;
    --vitis-settings)
      require_arg "$@"
      VITIS_SETTINGS_SH="$2"
      shift 2
      ;;
    --log-dir)
      require_arg "$@"
      export DAPHNE_REMOTE_LOG_DIR="$2"
      shift 2
      ;;
    --run-id)
      require_arg "$@"
      export DAPHNE_REMOTE_RUN_ID="$2"
      shift 2
      ;;
    --stop-after-synth)
      export DAPHNE_STOP_AFTER_SYNTH=1
      shift
      ;;
    --dump-post-synth-debug)
      export DAPHNE_DUMP_POST_SYNTH_DEBUG=1
      shift
      ;;
    --synth-directive)
      require_arg "$@"
      export DAPHNE_SYNTH_DIRECTIVE="$2"
      shift 2
      ;;
    --opt-directive)
      require_arg "$@"
      export DAPHNE_OPT_DIRECTIVE="$2"
      shift 2
      ;;
    --post-place-physopt)
      require_arg "$@"
      export DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [ -z "$VIVADO_SETTINGS_SH" ]; then
  VIVADO_SETTINGS_SH="$(detect_settings_script "Vivado" || true)"
fi
[ -n "$VIVADO_SETTINGS_SH" ] || die "could not find a native Linux Vivado settings64.sh under ${SEARCH_ROOTS[*]}"
[ -f "$VIVADO_SETTINGS_SH" ] || die "Vivado settings script does not exist: $VIVADO_SETTINGS_SH"

if [ -z "$VITIS_SETTINGS_SH" ]; then
  VITIS_SETTINGS_SH="$(detect_settings_script "Vitis" || true)"
fi

export XILINX_SETTINGS_SH="$VIVADO_SETTINGS_SH"
[ -n "$VITIS_SETTINGS_SH" ] || die "could not find a native Linux Vitis settings64.sh under ${SEARCH_ROOTS[*]}"
[ -f "$VITIS_SETTINGS_SH" ] || die "Vitis settings script does not exist: $VITIS_SETTINGS_SH"
export XILINX_VITIS_SETTINGS_SH="$VITIS_SETTINGS_SH"

export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"
export DAPHNE_REMOTE_PACKAGE_DTBO="$POST_PACKAGE"

# shellcheck disable=SC1090
. "$XILINX_SETTINGS_SH"
if [ -n "${XILINX_VITIS_SETTINGS_SH:-}" ]; then
  # shellcheck disable=SC1090
  . "$XILINX_VITIS_SETTINGS_SH"
fi

VIVADO_BIN_EXPECTED="$(dirname "$XILINX_SETTINGS_SH")/bin/vivado"
VIVADO_BIN_RESOLVED="$(command -v vivado || true)"
ensure_native_tool "vivado" "$VIVADO_BIN_RESOLVED" "$VIVADO_BIN_EXPECTED"

XSCT_BIN_EXPECTED=""
XSCT_BIN_RESOLVED=""
XSCT_BIN_EXPECTED="$(dirname "$XILINX_VITIS_SETTINGS_SH")/bin/xsct"
XSCT_BIN_RESOLVED="$(command -v xsct || true)"
ensure_native_tool "xsct" "$XSCT_BIN_RESOLVED" "$XSCT_BIN_EXPECTED"

if [ "$DRY_RUN" = "1" ]; then
  printf 'root_dir=%s\n' "$ROOT_DIR"
  printf 'board=%s\n' "$DAPHNE_BOARD"
  printf 'eth_mode=%s\n' "$DAPHNE_ETH_MODE"
  printf 'vivado_settings=%s\n' "$XILINX_SETTINGS_SH"
  printf 'vitis_settings=%s\n' "${XILINX_VITIS_SETTINGS_SH:-}"
  printf 'vivado=%s\n' "$VIVADO_BIN_RESOLVED"
  printf 'xsct=%s\n' "$XSCT_BIN_RESOLVED"
  printf 'platform_core=%s\n' "${DAPHNE_PLATFORM_CORE:-}"
  printf 'platform_target=%s\n' "${DAPHNE_PLATFORM_TARGET:-}"
  printf 'max_threads=%s\n' "${DAPHNE_MAX_THREADS:-}"
  printf 'output_dir=%s\n' "${DAPHNE_OUTPUT_DIR:-}"
  printf 'git_sha=%s\n' "${DAPHNE_GIT_SHA:-}"
  exit 0
fi

exec "$ROOT_DIR/scripts/remote/run_remote_vivado_chain.sh"
