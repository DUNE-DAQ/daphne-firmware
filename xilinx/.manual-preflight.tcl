set script_dir "\\\\wsl.localhost\\Debian\\home\\neutrino\\work\\daphne-firmware-build\\xilinx"
create_project -in_memory -part "xck26-sfvc784-2LV-c"
set ::env(DAPHNE_FPGA_PART) "xck26-sfvc784-2LV-c"
set ::env(DAPHNE_BOARD_PART) "xilinx.com:k26c:part0:1.4"
set ::env(DAPHNE_PFM_NAME) "xilinx:k26c:name:0.0"
set ::env(DAPHNE_BOARD) "k26c"
set ::env(DAPHNE_ETH_MODE) "create_ip"
set ::env(DAPHNE_GIT_SHA) "1f10fc0"
source -notrace [file join $script_dir "daphne_ip_gen.tcl"]
exit
