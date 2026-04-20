# simple TCL code to generate Device Tree Overlay for Petalinux
# this code must run inside the XSCT Vitis environment
# call for this specific process to run first

# define the hardware description files
set hw      [lindex $argv 0]

# define output directory
set out_dir [lindex $argv 1]

# receive the git commit number
set git_sha [lindex $argv 2]
set build_name "daphne_fullstream_${git_sha}"
 
# open the generated hardware design XSA
hsi::open_hw_design $out_dir/${build_name}.xsa

# generate the device tree using the generated XSA
createdts -hw $hw -zocl -platform-name $build_name -git-branch xlnx_rel_v2022.2 -overlay -compile -out $out_dir/$build_name
 
# exit the process once done
exit
