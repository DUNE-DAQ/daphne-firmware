#!/usr/bin/env bash
set -euo pipefail
source_root="$(realpath "${1:?source root}")"
sim_root="${2:?new simulation directory}"
mkdir "$sim_root"
sim_root="$(realpath "$sim_root")"
export PATH="/tools/2026.1/Vivado/bin:/usr/local/bin:/usr/bin:/bin:/tools/petalinux/sysroots/x86_64-petalinux-linux/usr/bin"
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONHOME PYTHONPATH
export XILINX_VIVADO=/tools/2026.1/Vivado
xpm_root="$XILINX_VIVADO/data/ip/xpm"
hermes="$source_root/ip_repo/daphne_ip/src/dune.daq_user_hermes_daphne_1.0/src"
cd "$sim_root"
trap 'result=$?; printf "%s\n" "$result" > exit-code.txt' EXIT
mkdir xpm
xpm_library="xpm=$sim_root/xpm"
git -C "$source_root" rev-parse HEAD > source-commit.txt
sha256sum "$hermes/deimos/tx_mux_ibuf.vhd" "$source_root/tests/logic/hermes_packet_admission_tb.vhd" "$xpm_root/xpm_fifo/hdl/xpm_fifo.sv" > sources.sha256
xvhdl --2008 --work "$xpm_library" "$xpm_root/xpm_VCOMP.vhd" --log compile-xpm-vhdl.log
xvlog --sv --work "$xpm_library" "$xpm_root/xpm_cdc/hdl/xpm_cdc.sv" "$xpm_root/xpm_memory/hdl/xpm_memory.sv" "$xpm_root/xpm_fifo/hdl/xpm_fifo.sv" --log compile-xpm-verilog.log
xvlog --work work "$XILINX_VIVADO/data/verilog/src/glbl.v" --log compile-glbl.log
xvhdl --2008 --work work "$hermes/ipbus/ipbus_package.vhd" "$hermes/ipbus/ipbus_reg_types.vhd" "$hermes/ipbus/ipbus_ctrlreg_v.vhd" "$hermes/deimos/tx_mux_decl.vhd" "$hermes/deimos/tx_mux_ibuf.vhd" "$source_root/tests/logic/hermes_packet_admission_tb.vhd" --log compile-design.log
xelab --debug typical --relax -L "$xpm_library" -L unisims_ver work.hermes_packet_admission_tb work.glbl --snapshot admission --log elaborate.log
xsim admission --runall --log simulate.log
grep -F 'hermes_packet_admission_tb PASS' simulate.log
printf 'PASS\n' > result.txt
