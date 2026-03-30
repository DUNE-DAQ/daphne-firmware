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
echo "INFO: XILINX_VITIS=$XILINX_VITIS"
echo "INFO: PATH wrapper dir: $DAPHNE_WSL_XILINX_WRAPPER_DIR"

vivado -version
xsct -help >/dev/null

echo "INFO: Vivado and XSCT are callable from WSL."
