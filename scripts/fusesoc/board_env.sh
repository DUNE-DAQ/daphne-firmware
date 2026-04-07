#!/bin/sh

daphne_board_manifest_path() {
  root_dir="$1"
  board_name="$2"
  printf '%s/boards/%s/board.yml' "$root_dir" "$board_name"
}

daphne_legacy_support_manifest_path() {
  root_dir="$1"
  printf '%s/xilinx/legacy_flow_support_sources.txt' "$root_dir"
}

daphne_expand_legacy_support_entry() {
  resolved_path="$1"

  if [ -d "$resolved_path" ]; then
    find "$resolved_path" -type f -name '*.vhd' \
      ! -path '*/validate/*' \
      ! -name '*_validate_stub.vhd' \
      ! -name 'legacy_public_top_bridge.vhd' \
      -print
  elif [ -f "$resolved_path" ]; then
    printf '%s\n' "$resolved_path"
  else
    echo "ERROR: missing legacy support entry: $resolved_path" >&2
    return 2
  fi
}

daphne_board_manifest_scalar() {
  manifest_path="$1"
  key_name="$2"
  awk -F': *' -v key="$key_name" '
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
      sub("^[[:space:]]*" key ":[[:space:]]*", "", $0)
      sub(/[[:space:]]+#.*$/, "", $0)
      gsub(/^["'"'"']|["'"'"']$/, "", $0)
      print $0
      exit
    }
  ' "$manifest_path"
}

daphne_board_manifest_value() {
  root_dir="$1"
  board_name="$2"
  key_name="$3"
  manifest_path="$(daphne_board_manifest_path "$root_dir" "$board_name")"

  [ -f "$manifest_path" ] || return 1

  value="$(daphne_board_manifest_scalar "$manifest_path" "$key_name")"
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi

  parent_board="$(daphne_board_manifest_scalar "$manifest_path" inherits)"
  if [ -n "$parent_board" ]; then
    daphne_board_manifest_value "$root_dir" "$parent_board" "$key_name"
  fi
}

daphne_board_manifest_value_with_fallback() {
  root_dir="$1"
  board_name="$2"
  preferred_key="$3"
  fallback_key="$4"

  preferred_value="$(daphne_board_manifest_value "$root_dir" "$board_name" "$preferred_key")"
  if [ -n "$preferred_value" ]; then
    printf '%s' "$preferred_value"
    return 0
  fi

  daphne_board_manifest_value "$root_dir" "$board_name" "$fallback_key"
}

daphne_platform_core_build_slug() {
  platform_core="$1"
  printf '%s' "$platform_core" | tr ':' '_'
}

daphne_default_platform_core() {
  root_dir="$1"
  board_name="$2"

  default_core="$(daphne_board_manifest_value "$root_dir" "$board_name" default_platform_core)"
  if [ -n "$default_core" ]; then
    printf '%s' "$default_core"
    return 0
  fi

  composable_core="$(daphne_board_manifest_value "$root_dir" "$board_name" composable_platform_core)"
  if [ -n "$composable_core" ]; then
    printf '%s' "$composable_core"
    return 0
  fi

  legacy_core="$(daphne_board_manifest_value "$root_dir" "$board_name" platform_core)"
  if [ -n "$legacy_core" ]; then
    printf '%s' "$legacy_core"
  fi
}

daphne_default_platform_target() {
  root_dir="$1"
  board_name="$2"
  platform_core="${3:-$(daphne_default_platform_core "$root_dir" "$board_name")}"

  default_core="$(daphne_default_platform_core "$root_dir" "$board_name")"
  if [ -n "$default_core" ] && [ "$platform_core" = "$default_core" ]; then
    default_target="$(daphne_board_manifest_value "$root_dir" "$board_name" default_platform_target)"
    if [ -z "$default_target" ]; then
      default_target="$(daphne_board_manifest_value "$root_dir" "$board_name" composable_default_target)"
    fi
    : "${default_target:=impl}"
    printf '%s' "$default_target"
    return 0
  fi

  composable_core="$(daphne_board_manifest_value "$root_dir" "$board_name" composable_platform_core)"
  if [ -n "$composable_core" ] && [ "$platform_core" = "$composable_core" ]; then
    composable_target="$(daphne_board_manifest_value "$root_dir" "$board_name" composable_default_target)"
    : "${composable_target:=impl}"
    printf '%s' "$composable_target"
    return 0
  fi

  printf '%s' "impl"
}

daphne_platform_exports_flow_bundle() {
  root_dir="$1"
  board_name="$2"
  platform_core="${3:-$(daphne_default_platform_core "$root_dir" "$board_name")}"
  platform_target="${4:-$(daphne_default_platform_target "$root_dir" "$board_name" "$platform_core")}"

  default_core="$(daphne_default_platform_core "$root_dir" "$board_name")"
  default_target="$(daphne_default_platform_target "$root_dir" "$board_name" "$default_core")"

  [ -n "$default_core" ] || return 1
  [ "$platform_core" = "$default_core" ] || return 1
  [ "$platform_target" = "$default_target" ]
}

daphne_platform_requires_packaged_ip_preflight() {
  root_dir="$1"
  board_name="$2"
  platform_core="${3:-$(daphne_default_platform_core "$root_dir" "$board_name")}"
  platform_target="${4:-$(daphne_default_platform_target "$root_dir" "$board_name" "$platform_core")}"

  if daphne_platform_exports_flow_bundle "$root_dir" "$board_name" "$platform_core" "$platform_target"; then
    return 1
  fi

  case "$platform_target" in
    synth_public_top_ooc|synth_public_top_flow|synth_board_shell_ooc|synth_board_shell_flow|validate|validate_optional_off|validate_frontend_shell|validate_public_top)
      return 1
      ;;
  esac

  return 0
}

daphne_resolve_board_defaults() {
  root_dir="$1"
  board_name="${2:-${DAPHNE_BOARD:-k26c}}"
  manifest_path="$(daphne_board_manifest_path "$root_dir" "$board_name")"

  if [ ! -f "$manifest_path" ]; then
    echo "ERROR: unknown board '$board_name'." >&2
    echo "Expected board manifest at $manifest_path." >&2
    exit 2
  fi

  supported="$(daphne_board_manifest_value "$root_dir" "$board_name" supported)"
  inherits="$(daphne_board_manifest_scalar "$manifest_path" inherits)"
  fpga_part="$(daphne_board_manifest_value "$root_dir" "$board_name" fpga_part)"
  board_part="$(daphne_board_manifest_value "$root_dir" "$board_name" board_part)"
  pfm_name="$(daphne_board_manifest_value "$root_dir" "$board_name" pfm_name)"
  constraint_file="$(daphne_board_manifest_value "$root_dir" "$board_name" constraint_file)"
  constraint_files="$(daphne_board_manifest_value "$root_dir" "$board_name" constraint_files)"
  required_constraint_files="$(daphne_board_manifest_value "$root_dir" "$board_name" required_constraint_files)"
  default_platform_target="$(daphne_board_manifest_value "$root_dir" "$board_name" default_platform_target)"
  user_ip_vlnv="$(daphne_board_manifest_value_with_fallback "$root_dir" "$board_name" legacy_user_ip_vlnv user_ip_vlnv)"
  bd_name="$(daphne_board_manifest_value_with_fallback "$root_dir" "$board_name" legacy_bd_name bd_name)"
  bd_wrapper_name="$(daphne_board_manifest_value_with_fallback "$root_dir" "$board_name" legacy_bd_wrapper_name bd_wrapper_name)"
  build_name_prefix="$(daphne_board_manifest_value "$root_dir" "$board_name" build_name_prefix)"
  overlay_name_prefix="$(daphne_board_manifest_value "$root_dir" "$board_name" overlay_name_prefix)"
  ip_top_hdl_file="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_top_hdl_file)"
  ip_top_module="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_top_module)"
  ip_cell_name="$(daphne_board_manifest_value_with_fallback "$root_dir" "$board_name" legacy_ip_cell_name ip_cell_name)"
  ip_component_identifier="$(daphne_board_manifest_value_with_fallback "$root_dir" "$board_name" legacy_ip_component_identifier ip_component_identifier)"
  ip_display_name="$(daphne_board_manifest_value_with_fallback "$root_dir" "$board_name" legacy_ip_display_name ip_display_name)"
  ip_xgui_file="$(daphne_board_manifest_value_with_fallback "$root_dir" "$board_name" legacy_ip_xgui_file ip_xgui_file)"
  ip_cell_bind_root="$(daphne_board_manifest_value_with_fallback "$root_dir" "$board_name" legacy_ip_cell_bind_root ip_cell_bind_root)"
  public_top_hdl_file="$(daphne_board_manifest_value "$root_dir" "$board_name" public_top_hdl_file)"
  public_top_module="$(daphne_board_manifest_value "$root_dir" "$board_name" public_top_module)"
  timing_endpoint_path="$(daphne_board_manifest_value "$root_dir" "$board_name" timing_endpoint_path)"
  timing_plane_path="$(daphne_board_manifest_value "$root_dir" "$board_name" timing_plane_path)"
  afe_capture_input_delay_enable="$(daphne_board_manifest_value "$root_dir" "$board_name" afe_capture_input_delay_enable)"
  afe_capture_virtual_launch_period_ns="$(daphne_board_manifest_value "$root_dir" "$board_name" afe_capture_virtual_launch_period_ns)"
  afe_capture_input_delay_min_ns="$(daphne_board_manifest_value "$root_dir" "$board_name" afe_capture_input_delay_min_ns)"
  afe_capture_input_delay_max_ns="$(daphne_board_manifest_value "$root_dir" "$board_name" afe_capture_input_delay_max_ns)"

  if [ -z "$ip_top_hdl_file" ] && [ -n "$public_top_hdl_file" ]; then
    ip_top_hdl_file="$public_top_hdl_file"
  fi
  if [ -z "$ip_top_module" ] && [ -n "$public_top_module" ]; then
    ip_top_module="$public_top_module"
  fi
  if [ -z "$default_platform_target" ]; then
    default_platform_target="$(daphne_default_platform_target "$root_dir" "$board_name")"
  fi

  if [ "$supported" != "true" ]; then
    echo "ERROR: board '$board_name' is scaffolded but not yet supported." >&2
    if [ -n "$inherits" ]; then
      echo "Board profile inherits from '$inherits'; missing items are tracked in boards/$board_name/board.yml." >&2
    fi
    exit 2
  fi

  if [ -z "$fpga_part" ] || [ -z "$board_part" ] || [ -z "$pfm_name" ] || [ -z "$constraint_file" ]; then
    echo "ERROR: board manifest '$manifest_path' is missing one of fpga_part, board_part, pfm_name, or constraint_file." >&2
    exit 2
  fi

  if [ -z "$constraint_files" ]; then
    constraint_files="$constraint_file"
  fi

  effective_constraint_files="${DAPHNE_CONSTRAINT_FILES:-$constraint_files}"
  if [ -z "$effective_constraint_files" ]; then
    effective_constraint_files="$constraint_file"
  fi

  if [ -n "$required_constraint_files" ]; then
    old_ifs="$IFS"
    IFS=';'
    set -- $required_constraint_files
    IFS="$old_ifs"
    for required_constraint_file in "$@"; do
      required_constraint_file="$(printf '%s' "$required_constraint_file" | tr -d '[:space:]')"
      [ -n "$required_constraint_file" ] || continue
      case ";$effective_constraint_files;" in
        *";$required_constraint_file;"*) ;;
        *)
          echo "ERROR: board manifest '$manifest_path' requires constraint file '$required_constraint_file' to be present in the effective constraint_files list." >&2
          exit 2
          ;;
      esac
    done
  fi

  : "${DAPHNE_FPGA_PART:=$fpga_part}"
  : "${DAPHNE_BOARD_PART:=$board_part}"
  : "${DAPHNE_PFM_NAME:=$pfm_name}"
  : "${DAPHNE_CONSTRAINT_FILE:=$constraint_file}"
  : "${DAPHNE_CONSTRAINT_FILES:=$effective_constraint_files}"
  if [ -n "$required_constraint_files" ]; then
    : "${DAPHNE_REQUIRED_CONSTRAINT_FILES:=$required_constraint_files}"
  fi
  if [ -n "$user_ip_vlnv" ]; then
    : "${DAPHNE_USER_IP_VLNV:=$user_ip_vlnv}"
  fi
  if [ -n "$bd_name" ]; then
    : "${DAPHNE_BD_NAME:=$bd_name}"
  fi
  if [ -n "$bd_wrapper_name" ]; then
    : "${DAPHNE_BD_WRAPPER_NAME:=$bd_wrapper_name}"
  fi
  if [ -n "$build_name_prefix" ]; then
    : "${DAPHNE_BUILD_NAME_PREFIX:=$build_name_prefix}"
  fi
  if [ -n "$overlay_name_prefix" ]; then
    : "${DAPHNE_OVERLAY_NAME_PREFIX:=$overlay_name_prefix}"
  fi
  if [ -n "$default_platform_target" ]; then
    : "${DAPHNE_DEFAULT_PLATFORM_TARGET:=$default_platform_target}"
  fi
  if [ -n "$ip_top_hdl_file" ]; then
    : "${DAPHNE_IP_TOP_HDL_FILE:=$ip_top_hdl_file}"
  fi
  if [ -n "$ip_top_module" ]; then
    : "${DAPHNE_IP_TOP_MODULE:=$ip_top_module}"
  fi
  if [ -n "$ip_cell_name" ]; then
    : "${DAPHNE_IP_CELL_NAME:=$ip_cell_name}"
  fi
  if [ -n "$ip_component_identifier" ]; then
    : "${DAPHNE_IP_COMPONENT_IDENTIFIER:=$ip_component_identifier}"
  fi
  if [ -n "$ip_display_name" ]; then
    : "${DAPHNE_IP_DISPLAY_NAME:=$ip_display_name}"
  fi
  if [ -n "$ip_xgui_file" ]; then
    : "${DAPHNE_IP_XGUI_FILE:=$ip_xgui_file}"
  fi
  if [ -n "$ip_cell_bind_root" ]; then
    : "${DAPHNE_IP_CELL_BIND_ROOT:=$ip_cell_bind_root}"
  fi
  if [ -n "$public_top_hdl_file" ]; then
    : "${DAPHNE_PUBLIC_TOP_HDL_FILE:=$public_top_hdl_file}"
  fi
  if [ -n "$public_top_module" ]; then
    : "${DAPHNE_PUBLIC_TOP_MODULE:=$public_top_module}"
  fi
  if [ -n "$timing_endpoint_path" ]; then
    : "${DAPHNE_TIMING_ENDPOINT_PATH:=$timing_endpoint_path}"
  fi
  if [ -n "$timing_plane_path" ]; then
    : "${DAPHNE_TIMING_PLANE_PATH:=$timing_plane_path}"
  fi
  if [ -n "$afe_capture_input_delay_enable" ]; then
    : "${DAPHNE_AFE_CAPTURE_INPUT_DELAY_ENABLE:=$afe_capture_input_delay_enable}"
  fi
  if [ -n "$afe_capture_virtual_launch_period_ns" ]; then
    : "${DAPHNE_AFE_CAPTURE_VIRTUAL_LAUNCH_PERIOD_NS:=$afe_capture_virtual_launch_period_ns}"
  fi
  if [ -n "$afe_capture_input_delay_min_ns" ]; then
    : "${DAPHNE_AFE_CAPTURE_INPUT_DELAY_MIN_NS:=$afe_capture_input_delay_min_ns}"
  fi
  if [ -n "$afe_capture_input_delay_max_ns" ]; then
    : "${DAPHNE_AFE_CAPTURE_INPUT_DELAY_MAX_NS:=$afe_capture_input_delay_max_ns}"
  fi
  DAPHNE_BOARD="$board_name"

  export DAPHNE_BOARD
  export DAPHNE_FPGA_PART
  export DAPHNE_BOARD_PART
  export DAPHNE_PFM_NAME
  export DAPHNE_CONSTRAINT_FILE
  export DAPHNE_CONSTRAINT_FILES
  if [ -n "${DAPHNE_REQUIRED_CONSTRAINT_FILES-}" ]; then
    export DAPHNE_REQUIRED_CONSTRAINT_FILES
  fi
  if [ -n "${DAPHNE_USER_IP_VLNV-}" ]; then
    export DAPHNE_USER_IP_VLNV
  fi
  if [ -n "${DAPHNE_DEFAULT_PLATFORM_TARGET-}" ]; then
    export DAPHNE_DEFAULT_PLATFORM_TARGET
  fi
  if [ -n "${DAPHNE_BD_NAME-}" ]; then
    export DAPHNE_BD_NAME
  fi
  if [ -n "${DAPHNE_BD_WRAPPER_NAME-}" ]; then
    export DAPHNE_BD_WRAPPER_NAME
  fi
  if [ -n "${DAPHNE_BUILD_NAME_PREFIX-}" ]; then
    export DAPHNE_BUILD_NAME_PREFIX
  fi
  if [ -n "${DAPHNE_OVERLAY_NAME_PREFIX-}" ]; then
    export DAPHNE_OVERLAY_NAME_PREFIX
  fi
  if [ -n "${DAPHNE_IP_TOP_HDL_FILE-}" ]; then
    export DAPHNE_IP_TOP_HDL_FILE
  fi
  if [ -n "${DAPHNE_IP_TOP_MODULE-}" ]; then
    export DAPHNE_IP_TOP_MODULE
  fi
  if [ -n "${DAPHNE_IP_CELL_NAME-}" ]; then
    export DAPHNE_IP_CELL_NAME
  fi
  if [ -n "${DAPHNE_IP_COMPONENT_IDENTIFIER-}" ]; then
    export DAPHNE_IP_COMPONENT_IDENTIFIER
  fi
  if [ -n "${DAPHNE_IP_DISPLAY_NAME-}" ]; then
    export DAPHNE_IP_DISPLAY_NAME
  fi
  if [ -n "${DAPHNE_IP_XGUI_FILE-}" ]; then
    export DAPHNE_IP_XGUI_FILE
  fi
  if [ -n "${DAPHNE_IP_CELL_BIND_ROOT-}" ]; then
    export DAPHNE_IP_CELL_BIND_ROOT
  fi
  if [ -n "${DAPHNE_PUBLIC_TOP_HDL_FILE-}" ]; then
    export DAPHNE_PUBLIC_TOP_HDL_FILE
  fi
  if [ -n "${DAPHNE_PUBLIC_TOP_MODULE-}" ]; then
    export DAPHNE_PUBLIC_TOP_MODULE
  fi
  if [ -n "${DAPHNE_TIMING_ENDPOINT_PATH-}" ]; then
    export DAPHNE_TIMING_ENDPOINT_PATH
  fi
  if [ -n "${DAPHNE_TIMING_PLANE_PATH-}" ]; then
    export DAPHNE_TIMING_PLANE_PATH
  fi
  if [ -n "${DAPHNE_AFE_CAPTURE_INPUT_DELAY_ENABLE-}" ]; then
    export DAPHNE_AFE_CAPTURE_INPUT_DELAY_ENABLE
  fi
  if [ -n "${DAPHNE_AFE_CAPTURE_VIRTUAL_LAUNCH_PERIOD_NS-}" ]; then
    export DAPHNE_AFE_CAPTURE_VIRTUAL_LAUNCH_PERIOD_NS
  fi
  if [ -n "${DAPHNE_AFE_CAPTURE_INPUT_DELAY_MIN_NS-}" ]; then
    export DAPHNE_AFE_CAPTURE_INPUT_DELAY_MIN_NS
  fi
  if [ -n "${DAPHNE_AFE_CAPTURE_INPUT_DELAY_MAX_NS-}" ]; then
    export DAPHNE_AFE_CAPTURE_INPUT_DELAY_MAX_NS
  fi
}

daphne_legacy_support_source_list() {
  root_dir="$1"
  manifest_path="$(daphne_legacy_support_manifest_path "$root_dir")"

  if [ ! -f "$manifest_path" ]; then
    echo "ERROR: expected legacy support manifest at $manifest_path." >&2
    exit 2
  fi

  {
    sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest_path" |
      while IFS= read -r rel_path; do
        [ -n "$rel_path" ] || continue
        case "$rel_path" in
          /*) resolved_path="$rel_path" ;;
          *) resolved_path="$root_dir/$rel_path" ;;
        esac
        daphne_expand_legacy_support_entry "$resolved_path"
      done
  } | sort -u
}
