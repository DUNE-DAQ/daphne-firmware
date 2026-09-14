#!/usr/bin/env bash
set -eo pipefail
cd /home/marroyav/work/daphne-grouped32-1bae1c8-20260914/build/checkpoint-audit-5e86a75-launcher
trap 'result=$?; printf "%s\n" "$result" > exit-code.txt; date -u +%FT%TZ > finished.txt' EXIT
export XILINXD_LICENSE_FILE=/opt/Xilinx/2026.1/data/ip/core_licenses:2100@xilinx-lic
export LM_LICENSE_FILE=2100@xilinx-lic
source /opt/Xilinx/2026.1/Vivado/settings64.sh
date -u +%FT%TZ > started.txt
vivado -mode batch -source audit_synth_checkpoint.tcl -tclargs /home/marroyav/work/daphne-grouped32-5e86a75-synth-20260914/xilinx/output-5e86a75/daphne_selftrigger_bd_synth.dcp /home/marroyav/work/daphne-grouped32-1bae1c8-20260914/build/checkpoint-audit-5e86a75
