#!/bin/sh
set -eu

APP="${APP:-daphne_selftrigger_ol_a389fcd}"

if systemctl list-unit-files dfx-mgrd.service >/dev/null 2>&1; then
  systemctl is-active --quiet dfx-mgrd || systemctl start dfx-mgrd
fi

if command -v dfx-mgr-client >/dev/null 2>&1; then
  echo "Loading ${APP} via dfx-mgr-client ..."
  dfx-mgr-client -load "${APP}"
elif command -v xmutil >/dev/null 2>&1; then
  echo "Loading ${APP} via xmutil ..."
  xmutil loadapp "${APP}"
else
  echo "Neither dfx-mgr-client nor xmutil is available." >&2
  exit 1
fi

for i in $(seq 1 50); do
  st=$(cat /sys/class/fpga_manager/fpga0/state 2>/dev/null || echo unknown)
  [ "$st" = "operating" ] && break
  sleep 0.2
done
echo "FPGA state: $(cat /sys/class/fpga_manager/fpga0/state 2>/dev/null || echo unknown)"
