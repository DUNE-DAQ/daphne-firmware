#!/bin/sh
set -eu

start_dfx_mgr() {
  for unit in dfx-mgr.service dfx-mgrd.service; do
    if systemctl list-unit-files "$unit" 2>/dev/null | awk '{print $1}' | grep -qx "$unit"; then
      systemctl is-active --quiet "$unit" || systemctl start "$unit"
      return 0
    fi
  done
  return 0
}

if command -v dfx-mgr-client >/dev/null 2>&1; then
  start_dfx_mgr
  dfx-mgr-client -remove || true
elif command -v xmutil >/dev/null 2>&1; then
  start_dfx_mgr
  xmutil unloadapp || true
elif command -v fpgautil >/dev/null 2>&1; then
  fpgautil -R -n full || true
fi

echo "FPGA state after stop: $(cat /sys/class/fpga_manager/fpga0/state 2>/dev/null || echo unknown)"
