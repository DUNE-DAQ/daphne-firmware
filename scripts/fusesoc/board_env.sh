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

daphne_platform_core_build_slug() {
  platform_core="$1"
  printf '%s' "$platform_core" | tr ':' '_'
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
  user_ip_vlnv="$(daphne_board_manifest_value "$root_dir" "$board_name" user_ip_vlnv)"
  bd_name="$(daphne_board_manifest_value "$root_dir" "$board_name" bd_name)"
  bd_wrapper_name="$(daphne_board_manifest_value "$root_dir" "$board_name" bd_wrapper_name)"
  build_name_prefix="$(daphne_board_manifest_value "$root_dir" "$board_name" build_name_prefix)"
  overlay_name_prefix="$(daphne_board_manifest_value "$root_dir" "$board_name" overlay_name_prefix)"
  ip_top_hdl_file="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_top_hdl_file)"
  ip_top_module="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_top_module)"
  ip_cell_name="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_cell_name)"
  ip_component_identifier="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_component_identifier)"
  ip_display_name="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_display_name)"
  ip_xgui_file="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_xgui_file)"
  ip_cell_bind_root="$(daphne_board_manifest_value "$root_dir" "$board_name" ip_cell_bind_root)"
  timing_endpoint_path="$(daphne_board_manifest_value "$root_dir" "$board_name" timing_endpoint_path)"

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

  : "${DAPHNE_FPGA_PART:=$fpga_part}"
  : "${DAPHNE_BOARD_PART:=$board_part}"
  : "${DAPHNE_PFM_NAME:=$pfm_name}"
  : "${DAPHNE_CONSTRAINT_FILE:=$constraint_file}"
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
  if [ -n "$timing_endpoint_path" ]; then
    : "${DAPHNE_TIMING_ENDPOINT_PATH:=$timing_endpoint_path}"
  fi
  DAPHNE_BOARD="$board_name"

  export DAPHNE_BOARD
  export DAPHNE_FPGA_PART
  export DAPHNE_BOARD_PART
  export DAPHNE_PFM_NAME
  export DAPHNE_CONSTRAINT_FILE
  if [ -n "${DAPHNE_USER_IP_VLNV-}" ]; then
    export DAPHNE_USER_IP_VLNV
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
  if [ -n "${DAPHNE_TIMING_ENDPOINT_PATH-}" ]; then
    export DAPHNE_TIMING_ENDPOINT_PATH
  fi
}

daphne_legacy_support_source_list() {
  root_dir="$1"
  manifest_path="$(daphne_legacy_support_manifest_path "$root_dir")"

  if [ ! -f "$manifest_path" ]; then
    echo "ERROR: expected legacy support manifest at $manifest_path." >&2
    exit 2
  fi

  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest_path"
}
