#!/bin/sh
set -eu

ROOT_DIR="${DAPHNE_FIRMWARE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"

. "$ROOT_DIR/scripts/wsl/setup_windows_xilinx.sh"

if uname -r | grep -qiE 'microsoft|wsl'; then
echo "INFO: WSL kernel detected: $(uname -r)"
else
  echo "WARNING: This does not look like WSL: $(uname -r)" >&2
fi

echo "INFO: Vivado batch launcher: $DAPHNE_WSL_VIVADO_BAT"
echo "INFO: XSCT batch launcher: $DAPHNE_WSL_XSCT_BAT"
printf 'INFO: XILINX_VITIS=%s\n' "${XILINX_VITIS-}"
echo "INFO: PATH wrapper dir: $DAPHNE_WSL_XILINX_WRAPPER_DIR"

vivado_version_log=$(mktemp)
trap 'rm -f "$vivado_version_log"' EXIT INT TERM HUP

if vivado -version >"$vivado_version_log" 2>&1; then
  cat "$vivado_version_log"
else
  vivado_rc=$?
  cat "$vivado_version_log"
  if grep -qi '^vivado v' "$vivado_version_log"; then
    echo "INFO: Vivado responded to -version but returned exit code $vivado_rc." >&2
  else
    exit "$vivado_rc"
  fi
fi

if command -v xsct >/dev/null 2>&1; then
  if xsct -help >/dev/null 2>&1; then
    echo "INFO: XSCT is callable from WSL."
  else
    xsct_rc=$?
    echo "WARNING: XSCT wrapper returned exit code $xsct_rc." >&2
    echo "WARNING: Device-tree helper steps may still need manual verification." >&2
  fi
else
  echo "WARNING: XSCT is not available from WSL." >&2
  echo "WARNING: This is acceptable for bitstream/XSA generation." >&2
  echo "WARNING: Device-tree helper steps will be skipped until Vitis/XSCT is reachable." >&2
fi

echo "INFO: Vivado is callable from WSL."
