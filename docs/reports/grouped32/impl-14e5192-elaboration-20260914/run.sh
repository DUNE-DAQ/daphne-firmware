#!/usr/bin/env bash
set -euo pipefail
cd /home/marroyav/work/daphne-grouped32-1bae1c8-20260914/build/candidate-14e5192-impl-launcher
printf '%s\n' "$$" > pid.txt
trap 'result=$?; printf "%s\n" "$result" > exit-code.txt; date -u +%FT%TZ > finished.txt' EXIT
for daphne_var in ${!DAPHNE_@}; do unset "$daphne_var"; done
export XILINXD_LICENSE_FILE=/opt/Xilinx/2026.1/data/ip/core_licenses:2100@xilinx-lic
export LM_LICENSE_FILE=2100@xilinx-lic
export XILINX_SETTINGS_SH=/opt/Xilinx/2026.1/Vivado/settings64.sh
export DAPHNE_FIRMWARE_ROOT=/home/marroyav/work/daphne-grouped32-14e5192-impl-20260914
export DAPHNE_BOARD=k26c
export DAPHNE_ETH_MODE=create_ip
export DAPHNE_MAX_THREADS=8
export DAPHNE_PLATFORM_CORE=dune-daq:daphne:k26c-composable-platform:0.1.0
export DAPHNE_PLATFORM_TARGET=impl
export DAPHNE_GIT_SHA=14e5192
export DAPHNE_REMOTE_RUN_ID=impl-14e5192-20260914b
export DAPHNE_OUTPUT_DIR=/home/marroyav/work/daphne-grouped32-14e5192-impl-20260914/xilinx/output-14e5192
export DAPHNE_STOP_AFTER_SYNTH=0
export DAPHNE_DUMP_POST_SYNTH_DEBUG=1
date -u +%FT%TZ > started.txt
bash "$DAPHNE_FIRMWARE_ROOT/scripts/remote/run_remote_vivado_chain.sh"
