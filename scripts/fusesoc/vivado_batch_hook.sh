#!/bin/sh
set -eu

WORK_ROOT="${PWD}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLATFORM_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
BOARD="${DAPHNE_BOARD:-k26c}"
ETH_MODE="${DAPHNE_ETH_MODE:-create_ip}"

. "$PLATFORM_ROOT/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$PLATFORM_ROOT" "$BOARD"

if ! command -v vivado >/dev/null 2>&1; then
  echo "ERROR: vivado is not installed or not on PATH." >&2
  exit 2
fi

if [ "$ETH_MODE" = "vendored_hdl" ]; then
  echo "ERROR: DAPHNE_ETH_MODE=vendored_hdl is not qualified for full implementation yet." >&2
  echo "Use DAPHNE_ETH_MODE=create_ip for the current WSL/Windows Vivado flow." >&2
  exit 2
fi

if [ -z "${DAPHNE_GIT_SHA-}" ]; then
  DAPHNE_GIT_SHA=0000000
  export DAPHNE_GIT_SHA
  echo "WARNING: DAPHNE_GIT_SHA not set. Falling back to $DAPHNE_GIT_SHA for artifact naming." >&2
fi

: "${DAPHNE_OUTPUT_DIR:=./output-$DAPHNE_GIT_SHA}"

resolve_work_output_dir() {
  case "$DAPHNE_OUTPUT_DIR" in
    /*)
      printf '%s\n' "$DAPHNE_OUTPUT_DIR"
      ;;
    ./*)
      printf '%s\n' "$PLATFORM_ROOT/xilinx/${DAPHNE_OUTPUT_DIR#./}"
      ;;
    *)
      printf '%s\n' "$PLATFORM_ROOT/xilinx/$DAPHNE_OUTPUT_DIR"
      ;;
  esac
}

resolve_edalize_project_base() {
  run_tcl_path=$(find "$WORK_ROOT" -maxdepth 1 -type f -name '*_run.tcl' | sort | head -n 1)
  if [ -n "$run_tcl_path" ]; then
    basename "$run_tcl_path" _run.tcl
    return 0
  fi

  project_tcl_path=$(find "$WORK_ROOT" -maxdepth 1 -type f -name '*.tcl' \
    ! -name '*_run.tcl' ! -name '*_synth.tcl' ! -name '*_pgm.tcl' | sort | head -n 1)
  if [ -n "$project_tcl_path" ]; then
    basename "$project_tcl_path" .tcl
    return 0
  fi

  return 1
}

stage_edalize_compat_outputs() {
  project_base="$(resolve_edalize_project_base)" || return 0
  output_dir_path="$(resolve_work_output_dir)"
  build_name_prefix="${DAPHNE_BUILD_NAME_PREFIX:-daphne_selftrigger}"
  build_name="${build_name_prefix}_${DAPHNE_GIT_SHA}"
  bit_path="$output_dir_path/${build_name}.bit"

  if [ ! -f "$bit_path" ]; then
    echo "ERROR: expected batch bitstream at $bit_path" >&2
    exit 2
  fi

  # The deprecated Vivado backend still expects a project-local .xpr/.bit pair
  # even though the real build was completed by the batch hook above.
  : >"$WORK_ROOT/${project_base}.xpr"
  cp -f "$bit_path" "$WORK_ROOT/${project_base}.bit"
}

append_unique_path() {
  current="$1"
  candidate="$2"
  [ -n "$candidate" ] || {
    printf '%s' "$current"
    return 0
  }
  case ";$current;" in
    *";$candidate;"*)
      printf '%s' "$current"
      ;;
    "")
      printf '%s' "$candidate"
      ;;
    *)
      printf '%s;%s' "$current" "$candidate"
      ;;
  esac
}

find_first_file_dir() {
  search_root="$1"
  leaf="$2"
  if [ ! -d "$search_root" ]; then
    return 0
  fi
  found_path=$(find "$search_root" -type f -name "$leaf" -print -quit 2>/dev/null || true)
  if [ -n "$found_path" ]; then
    dirname "$found_path"
  fi
}

if [ -z "${DAPHNE_IP_REPO_ROOT-}" ]; then
  if [ -d "$WORK_ROOT/ip_repo/daphne_ip" ]; then
    DAPHNE_IP_REPO_ROOT="$WORK_ROOT/ip_repo/daphne_ip"
  elif [ -d "$WORK_ROOT/src/dune-daq_daphne_daphne-ip_0.1.0/ip_repo/daphne_ip" ]; then
    DAPHNE_IP_REPO_ROOT="$WORK_ROOT/src/dune-daq_daphne_daphne-ip_0.1.0/ip_repo/daphne_ip"
  fi
fi

if [ -n "${DAPHNE_IP_REPO_ROOT-}" ] && [ -z "${DAPHNE_USER_IP_REPO_PARENT-}" ]; then
  DAPHNE_USER_IP_REPO_PARENT="$(dirname "$DAPHNE_IP_REPO_ROOT")"
fi

if [ -z "${DAPHNE_IP_EXTRA_SOURCE_ROOTS-}" ]; then
  auto_extra_roots=""
  for candidate_dir in \
    "$WORK_ROOT/rtl/isolated/common" \
    "$WORK_ROOT/rtl/isolated/common/primitives" \
    "$WORK_ROOT/rtl/isolated/subsystems/control" \
    "$WORK_ROOT/rtl/isolated/subsystems/frontend" \
    "$WORK_ROOT/rtl/isolated/subsystems/readout" \
    "$WORK_ROOT/rtl/isolated/subsystems/spy" \
    "$WORK_ROOT/rtl/isolated/subsystems/timing" \
    "$WORK_ROOT/rtl/isolated/subsystems/trigger"
  do
    if [ -d "$candidate_dir" ]; then
      auto_extra_roots="$(append_unique_path "$auto_extra_roots" "$candidate_dir")"
    fi
  done

  if [ -d "$WORK_ROOT/src" ]; then
    for support_path in $(daphne_legacy_support_source_list "$PLATFORM_ROOT"); do
      required_leaf="$(basename "$support_path")"
      found_dir="$(find_first_file_dir "$WORK_ROOT/src" "$required_leaf")"
      auto_extra_roots="$(append_unique_path "$auto_extra_roots" "$found_dir")"
    done
  fi

  if [ -n "$auto_extra_roots" ]; then
    DAPHNE_IP_EXTRA_SOURCE_ROOTS="$auto_extra_roots"
  fi
fi

export DAPHNE_BOARD="$BOARD"
export DAPHNE_ETH_MODE="$ETH_MODE"
export DAPHNE_FPGA_PART
export DAPHNE_BOARD_PART
export DAPHNE_PFM_NAME
export DAPHNE_CONSTRAINT_FILE
export DAPHNE_CONSTRAINT_FILES
export DAPHNE_GIT_SHA
export DAPHNE_OUTPUT_DIR
if [ -n "${DAPHNE_IP_REPO_ROOT-}" ]; then
  export DAPHNE_IP_REPO_ROOT
fi
if [ -n "${DAPHNE_USER_IP_REPO_PARENT-}" ]; then
  export DAPHNE_USER_IP_REPO_PARENT
fi
if [ -n "${DAPHNE_IP_EXTRA_SOURCE_ROOTS-}" ]; then
  export DAPHNE_IP_EXTRA_SOURCE_ROOTS
fi

cd "$PLATFORM_ROOT/xilinx"

shim_tcl=".daphne-vivado-shim.$$.tcl"
trap 'rm -f "$shim_tcl"' EXIT INT TERM HUP

append_env_tcl() {
  var_name="$1"
  eval "var_value=\${$var_name-}"
  [ -n "$var_value" ] || return 0
  escaped_value=$(printf '%s' "$var_value" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf 'set ::env(%s) "%s"\n' "$var_name" "$escaped_value" >>"$shim_tcl"
}

: >"$shim_tcl"
append_env_tcl DAPHNE_FPGA_PART
append_env_tcl DAPHNE_BOARD_PART
append_env_tcl DAPHNE_PFM_NAME
append_env_tcl DAPHNE_CONSTRAINT_FILE
append_env_tcl DAPHNE_CONSTRAINT_FILES
append_env_tcl DAPHNE_BOARD
append_env_tcl DAPHNE_ETH_MODE
append_env_tcl DAPHNE_GIT_SHA
append_env_tcl DAPHNE_MAX_THREADS
append_env_tcl DAPHNE_OUTPUT_DIR
append_env_tcl DAPHNE_BD_NAME
append_env_tcl DAPHNE_BD_WRAPPER_NAME
append_env_tcl DAPHNE_BUILD_NAME_PREFIX
append_env_tcl DAPHNE_OVERLAY_NAME_PREFIX
append_env_tcl DAPHNE_USER_IP_VLNV
append_env_tcl DAPHNE_IP_TOP_HDL_FILE
append_env_tcl DAPHNE_IP_TOP_MODULE
append_env_tcl DAPHNE_IP_CELL_NAME
append_env_tcl DAPHNE_IP_COMPONENT_IDENTIFIER
append_env_tcl DAPHNE_IP_DISPLAY_NAME
append_env_tcl DAPHNE_IP_XGUI_FILE
append_env_tcl DAPHNE_IP_CELL_BIND_ROOT
append_env_tcl DAPHNE_TIMING_ENDPOINT_PATH
append_env_tcl DAPHNE_IP_EXTRA_SOURCE_ROOTS
append_env_tcl DAPHNE_IP_REPO_ROOT
append_env_tcl DAPHNE_USER_IP_REPO_PARENT
append_env_tcl DAPHNE_SKIP_POST_SYNTH_REPORTS
append_env_tcl DAPHNE_SKIP_POST_SYNTH_CHECKPOINT
append_env_tcl DAPHNE_SYNTH_DIRECTIVE
append_env_tcl DAPHNE_OPT_DIRECTIVE
append_env_tcl DAPHNE_PLACE_DIRECTIVE
append_env_tcl DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE
append_env_tcl DAPHNE_ROUTE_DIRECTIVE
append_env_tcl DAPHNE_POST_ROUTE_PHYSOPT_DIRECTIVE
append_env_tcl XILINX_VITIS
printf 'set script_dir [file dirname [file normalize [info script]]]\n' >>"$shim_tcl"
printf 'source -notrace [file join $script_dir "vivado_impl_entry.tcl"]\n' >>"$shim_tcl"

vivado -mode batch -source "$shim_tcl"
stage_edalize_compat_outputs
