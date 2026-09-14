#!/usr/bin/env bash
set -eo pipefail
trap 'result=$?; printf "%s\n" "$result" > exit-code.txt; date -u +%FT%TZ > finished.txt' EXIT
export XILINXD_LICENSE_FILE=/opt/Xilinx/2026.1/data/ip/core_licenses:2100@xilinx-lic
export LM_LICENSE_FILE=2100@xilinx-lic
source /opt/Xilinx/2026.1/Vivado/settings64.sh
date -u +%FT%TZ > started.txt
vivado -mode batch -source ../../scripts/verification/audit_synth_checkpoint.tcl -tclargs ../../xilinx/output-1bae1c8-typefixes/daphne_selftrigger_bd_synth.dcp ../checkpoint-audit-8ae5f81
