#!/usr/bin/env bash
# The Tcl helper can be supplied externally to keep a pinned clone unchanged.
set -euo pipefail
source_root="${1:?usage: cooper_ooc_synth.sh SOURCE_ROOT NEW_RUN_DIRECTORY [builder|descriptor|registers|both|all]}"
source_root="$(CDPATH= cd -- "$source_root" && pwd)"
run_root="${2:?a new run directory is required}"
selection="${3:-both}"
helper_directory="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
script_path="$helper_directory/$(basename -- "$0")"
tcl_helper="${DAPHNE_OOC_TCL:-$helper_directory/cooper_ooc_synth.tcl}"
mkdir "$run_root"
run_root="$(CDPATH= cd -- "$run_root" && pwd)"
export PATH="/tools/2026.1/Vivado/bin:/usr/local/bin:/usr/bin:/bin:/tools/petalinux/sysroots/x86_64-petalinux-linux/usr/bin"
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONHOME PYTHONPATH
export XILINX_VIVADO=/tools/2026.1/Vivado
cd "$run_root"
date -u +%FT%TZ > started.txt
trap 'result=$?; printf "%s\n" "$result" > exit-code.txt; date -u +%FT%TZ > finished.txt' EXIT
git -C "$source_root" rev-parse HEAD > source-commit.txt
git -C "$source_root" status --porcelain=v1 > source-status.txt
sha256sum "$tcl_helper" "$script_path" > helper-sources.sha256
source_files=(
  ip_repo/daphne_ip/rtl/daphne_package.vhd
  rtl/isolated/common/daphne_subsystem_pkg.vhd
)
if [[ "$selection" != registers ]]; then
  source_files+=(rtl/isolated/subsystems/trigger/fragment_peak_descriptors.vhd)
fi
if [[ "$selection" == builder || "$selection" == both || "$selection" == all ]]; then
  source_files+=(
    rtl/isolated/common/primitives/sample_ring_buffer.vhd
    rtl/isolated/common/primitives/packet_frame_store.vhd
    rtl/isolated/subsystems/trigger/stc3_record_builder.vhd
  )
fi
if [[ "$selection" == registers || "$selection" == all ]]; then
  source_files+=(rtl/isolated/subsystems/control/selftrigger_register_bank.vhd)
fi
(cd "$source_root" && sha256sum "${source_files[@]}") > rtl-sources.sha256
sha256sum "$XILINX_VIVADO/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
  "$XILINX_VIVADO/data/ip/xpm/xpm_VCOMP.vhd" > vendor-sources.sha256
vivado -mode batch -source "$tcl_helper" -tclargs "$source_root" "$run_root/reports" "$selection" \
  2>&1 | tee run.log
grep -F "DAPHNE_OOC_SYNTH_PASS: $selection" run.log
