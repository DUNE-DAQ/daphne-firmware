#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"

require_candidate() {
  key_name="$1"
  raw_value="$2"
  required_candidate="$3"

  case ";$raw_value;" in
    *";$required_candidate;"*) ;;
    *)
      echo "ERROR: board '$BOARD' key '$key_name' is missing required candidate '$required_candidate'." >&2
      echo "INFO: actual value: $raw_value" >&2
      exit 1
      ;;
  esac
}

timing_endpoint_candidates="${DAPHNE_TIMING_ENDPOINT_PATH:-}"
timing_plane_candidates="${DAPHNE_TIMING_PLANE_PATH:-}"

if [ -z "$timing_endpoint_candidates" ] || [ -z "$timing_plane_candidates" ]; then
  echo "ERROR: board timing-path defaults are not resolved." >&2
  exit 2
fi

require_candidate "timing_endpoint_path" "$timing_endpoint_candidates" "timing_bridge_inst/endpoint_inst"
require_candidate "timing_endpoint_path" "$timing_endpoint_candidates" "daphne_selftrigger_bd_i/*/k26c_board_shell_inst/timing_bridge_inst/endpoint_inst"
require_candidate "timing_plane_path" "$timing_plane_candidates" "timing_bridge_inst"
require_candidate "timing_plane_path" "$timing_plane_candidates" "daphne_selftrigger_bd_i/*/k26c_board_shell_inst/timing_bridge_inst"

echo "INFO: Board timing-path defaults cover both native board-shell and packaged-IP hierarchy roots."
