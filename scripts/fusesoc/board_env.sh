#!/bin/sh

daphne_board_manifest_path() {
  root_dir="$1"
  board_name="$2"
  printf '%s/boards/%s/board.yml' "$root_dir" "$board_name"
}

daphne_board_manifest_value() {
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

daphne_resolve_board_defaults() {
  root_dir="$1"
  board_name="${2:-${DAPHNE_BOARD:-k26c}}"
  manifest_path="$(daphne_board_manifest_path "$root_dir" "$board_name")"

  if [ ! -f "$manifest_path" ]; then
    echo "ERROR: unknown board '$board_name'." >&2
    echo "Expected board manifest at $manifest_path." >&2
    exit 2
  fi

  supported="$(daphne_board_manifest_value "$manifest_path" supported)"
  inherits="$(daphne_board_manifest_value "$manifest_path" inherits)"
  fpga_part="$(daphne_board_manifest_value "$manifest_path" fpga_part)"
  board_part="$(daphne_board_manifest_value "$manifest_path" board_part)"
  pfm_name="$(daphne_board_manifest_value "$manifest_path" pfm_name)"
  constraint_file="$(daphne_board_manifest_value "$manifest_path" constraint_file)"

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
  DAPHNE_BOARD="$board_name"

  export DAPHNE_BOARD
  export DAPHNE_FPGA_PART
  export DAPHNE_BOARD_PART
  export DAPHNE_PFM_NAME
  export DAPHNE_CONSTRAINT_FILE
}
