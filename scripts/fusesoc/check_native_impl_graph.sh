#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
BOARD="${DAPHNE_BOARD:-k26c}"
WORK_ROOT="${DAPHNE_IMPL_AUDIT_ROOT:-}"
CREATED_WORK_ROOT=0

. "$ROOT_DIR/scripts/fusesoc/board_env.sh"
daphne_resolve_board_defaults "$ROOT_DIR" "$BOARD"

PLATFORM_CORE="${DAPHNE_PLATFORM_CORE:-$(daphne_default_platform_core "$ROOT_DIR" "$BOARD")}"
TARGET="${DAPHNE_PLATFORM_TARGET:-$(daphne_default_platform_target "$ROOT_DIR" "$BOARD" "$PLATFORM_CORE")}"
NATIVE_TARGET="${DAPHNE_NATIVE_IMPL_TARGET:-impl_board_shell_flow}"

if [ "$TARGET" != "$NATIVE_TARGET" ]; then
  echo "ERROR: check_native_impl_graph.sh only supports the explicit native board-shell target ($NATIVE_TARGET)." >&2
  exit 2
fi

if [ -z "$WORK_ROOT" ]; then
  WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/daphne-native-impl.XXXXXX")"
  CREATED_WORK_ROOT=1
fi

cleanup() {
  if [ "$CREATED_WORK_ROOT" -eq 1 ] && [ -n "$WORK_ROOT" ] && [ -d "$WORK_ROOT" ]; then
    rm -rf "$WORK_ROOT"
  fi
}
trap cleanup EXIT INT TERM HUP

echo "INFO: Auditing native impl graph for $PLATFORM_CORE target=$TARGET board=$BOARD"

cd "$ROOT_DIR"
if daphne_platform_requires_packaged_ip_preflight "$ROOT_DIR" "$BOARD" "$PLATFORM_CORE" "$TARGET"; then
  echo "INFO: Running packaged-IP preflight before native impl graph audit."
  "$ROOT_DIR/scripts/fusesoc/preflight_vivado_build.sh"
  export DAPHNE_PACKAGED_IP_PREFLIGHT_DONE=1
fi

sh "$ROOT_DIR/scripts/fusesoc/check_board_shell_planes.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_analog_control_plane_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_afe_timing_constraint_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_board_timing_path_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_frontend_plane_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_selftrigger_plane_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_transport_plane_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_spy_trigger_plane_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_spy_buffer_plane_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_spy_capture_plane_contract.sh" >/dev/null
sh "$ROOT_DIR/scripts/fusesoc/check_timing_plane_contract.sh" >/dev/null
./scripts/fusesoc/fusesoc.sh run \
  --setup \
  --clean \
  --build-root "$WORK_ROOT" \
  --target "$TARGET" \
  "$PLATFORM_CORE" >/dev/null

EDA_YML="$(find "$WORK_ROOT" -name '*.eda.yml' | head -n 1)"

if [ -z "$EDA_YML" ] || [ ! -f "$EDA_YML" ]; then
  echo "ERROR: expected staged EDA description at $EDA_YML" >&2
  exit 2
fi

if ! rg -Fq 'toplevel: k26c_board_shell' "$EDA_YML"; then
  echo "ERROR: native impl graph no longer resolves k26c_board_shell as its toplevel." >&2
  exit 1
fi

legacy_hits="$(rg -n 'dune-daq:daphne:legacy-[^:]+' "$EDA_YML" || true)"
if [ -n "$legacy_hits" ]; then
  echo "ERROR: native impl graph still contains legacy core names:" >&2
  printf '%s\n' "$legacy_hits" >&2
  exit 1
fi

required_paths="$DAPHNE_CONSTRAINT_FILE"
if [ -n "${DAPHNE_REQUIRED_CONSTRAINT_FILES-}" ]; then
  required_paths="$required_paths;$DAPHNE_REQUIRED_CONSTRAINT_FILES"
fi

old_ifs="$IFS"
IFS=';'
set -- $required_paths
IFS="$old_ifs"
for required_path in "$@"; do
  required_path="$(printf '%s' "$required_path" | tr -d '[:space:]')"
  [ -n "$required_path" ] || continue
  if ! rg -Fq "$required_path" "$EDA_YML"; then
    echo "ERROR: native impl graph is missing required constraint $required_path" >&2
    exit 1
  fi
done

echo "INFO: Native impl graph is board-shell-owned, legacy-free, and carries the required AFE timing constraints."
echo "INFO: Board shell remains limited to explicit board-plane dependencies."
echo "INFO: Analog-control plane remains limited to imported AFE/DAC/control endpoints."
echo "INFO: AFE timing Tcl remains aligned with the live endpoint clocking and Vivado 2024.1 unmanaged-constraint flow."
echo "INFO: Board timing-path defaults still cover both native and packaged-IP hierarchy roots."
echo "INFO: Frontend plane remains limited to a single frontend-island boundary."
echo "INFO: Self-trigger plane remains limited to explicit datapath and transport subplanes."
echo "INFO: Transport plane remains limited to explicit Hermes and outbuffer subplanes."
echo "INFO: Spy-trigger plane remains self-contained and board-local."
echo "INFO: Spy-buffer plane remains limited to the spy boundary and live spy buffer."
echo "INFO: Spy-capture plane remains limited to explicit spy-trigger and spy-buffer subplanes."
echo "INFO: Timing plane remains limited to a single endpoint boundary."
echo "INFO: EDA description: $EDA_YML"
