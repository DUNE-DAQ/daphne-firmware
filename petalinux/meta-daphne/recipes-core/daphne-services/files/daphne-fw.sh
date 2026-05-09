#!/bin/sh
set -eu

APP="${APP:-daphne_selftrigger_ol_a389fcd}"
APP_DIR="${ACCEL_CONFIG_PATH:-/lib/firmware/xilinx}/${APP}"
APP_BIN="${APP_DIR}/${APP}.bin"
APP_DTBO="${APP_DIR}/${APP}.dtbo"

if command -v fpgautil >/dev/null 2>&1; then
  if [ ! -r "${APP_BIN}" ]; then
    echo "Missing bitstream: ${APP_BIN}" >&2
    exit 1
  fi
  if [ ! -r "${APP_DTBO}" ]; then
    echo "Missing dtbo: ${APP_DTBO}" >&2
    exit 1
  fi
  echo "Loading ${APP} via fpgautil ..."
  fpgautil -b "${APP_BIN}" -o "${APP_DTBO}" -f Full -n full
elif command -v dfx-mgr-client >/dev/null 2>&1; then
  if systemctl list-unit-files dfx-mgrd.service >/dev/null 2>&1; then
    systemctl is-active --quiet dfx-mgrd || systemctl start dfx-mgrd
  fi
  echo "Loading ${APP} via dfx-mgr-client ..."
  dfx-mgr-client -load "${APP}"
elif command -v xmutil >/dev/null 2>&1; then
  if systemctl list-unit-files dfx-mgrd.service >/dev/null 2>&1; then
    systemctl is-active --quiet dfx-mgrd || systemctl start dfx-mgrd
  fi
  echo "Loading ${APP} via xmutil ..."
  xmutil loadapp "${APP}"
else
  echo "Neither fpgautil, dfx-mgr-client, nor xmutil is available." >&2
  exit 1
fi

for i in $(seq 1 50); do
  st=$(cat /sys/class/fpga_manager/fpga0/state 2>/dev/null || echo unknown)
  [ "$st" = "operating" ] && break
  sleep 0.2
done
echo "FPGA state: $(cat /sys/class/fpga_manager/fpga0/state 2>/dev/null || echo unknown)"
