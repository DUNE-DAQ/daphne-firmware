#!/bin/sh
set -eu

if command -v fpgautil >/dev/null 2>&1; then
  fpgautil -R -n full || true
elif command -v dfx-mgr-client >/dev/null 2>&1; then
  dfx-mgr-client -remove || true
elif command -v xmutil >/dev/null 2>&1; then
  xmutil unloadapp || true
fi

echo "FPGA state after stop: $(cat /sys/class/fpga_manager/fpga0/state 2>/dev/null || echo unknown)"
