#!/usr/bin/env bash
# Focused mixed-language verification against installed AMD XPM memory models.
set -euo pipefail
source_root="${1:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
source_root="$(CDPATH= cd -- "$source_root" && pwd)"
sim_root="${2:?usage: cooper_vendor_memory_sim.sh SOURCE_ROOT NEW_SIM_DIRECTORY}"
mkdir "$sim_root"
sim_root="$(CDPATH= cd -- "$sim_root" && pwd)"
export PATH="/tools/2026.1/Vivado/bin:/usr/local/bin:/usr/bin:/bin:/tools/petalinux/sysroots/x86_64-petalinux-linux/usr/bin"
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONHOME PYTHONPATH
export XILINX_VIVADO=/tools/2026.1/Vivado
xpm_root="$XILINX_VIVADO/data/ip/xpm"
cd "$sim_root"
mkdir xpm
xpm_library="xpm=$sim_root/xpm"
date -u +%FT%TZ > started.txt
trap 'result=$?; printf "%s\n" "$result" > exit-code.txt; date -u +%FT%TZ > finished.txt' EXIT
git -C "$source_root" rev-parse HEAD > source-commit.txt
sha256sum "$xpm_root/xpm_memory/hdl/xpm_memory.sv" "$xpm_root/xpm_VCOMP.vhd" > vendor-sources.sha256
xvhdl --2008 --work "$xpm_library" "$xpm_root/xpm_VCOMP.vhd" --log compile-xpm-vhdl.log
xvlog --sv --work "$xpm_library" "$xpm_root/xpm_cdc/hdl/xpm_cdc.sv" "$xpm_root/xpm_memory/hdl/xpm_memory.sv" --log compile-xpm-verilog.log
xvhdl --2008 --work work \
  "$source_root/ip_repo/daphne_ip/rtl/daphne_package.vhd" \
  "$source_root/rtl/isolated/common/daphne_subsystem_pkg.vhd" \
  "$source_root/rtl/isolated/subsystems/trigger/fragment_peak_descriptors.vhd" \
  "$source_root/rtl/isolated/common/primitives/sample_ring_buffer.vhd" \
  "$source_root/rtl/isolated/common/primitives/packet_frame_store.vhd" \
  "$source_root/rtl/isolated/subsystems/trigger/stc3_record_builder.vhd" \
  "$source_root/rtl/isolated/subsystems/readout/two_lane_readout_mux.vhd" \
  "$source_root/tests/logic/stc3_continuation_tb.vhd" \
  "$source_root/tests/logic/stc3_continuation_edges_tb.vhd" \
  --log compile-design.log
for odd_start in 0 1; do
  snapshot="continuation_odd_$odd_start"
  xelab --debug typical --relax -L "$xpm_library" -L unisims_ver \
    --generic_top "ODD_START_G=$odd_start" work.stc3_continuation_tb \
    --snapshot "$snapshot" --log "elaborate-$snapshot.log"
  xsim "$snapshot" --runall --log "simulate-$snapshot.log"
  grep -F "stc3_continuation_tb PASS odd=$odd_start" "simulate-$snapshot.log"
done
xelab --debug typical --relax -L "$xpm_library" -L unisims_ver work.stc3_continuation_edges_tb \
  --snapshot continuation_edges --log elaborate-continuation_edges.log
xsim continuation_edges --runall --log simulate-continuation_edges.log
grep -F 'stc3_continuation_edges_tb PASS' simulate-continuation_edges.log
printf 'PASS: real AMD XPM models; consecutive payloads, even/odd ring starts, boundaries.\n' > result.txt
