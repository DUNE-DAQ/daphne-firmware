# simple TCL code to generate Device Tree Overlay for Petalinux
# this code must run inside the XSCT Vitis environment
# call for this specific process to run first

# Normalize WSL/Windows path strings for XSCT on Windows.
# In particular, createdts is stricter than hsi::open_hw_design about UNC
# paths with backslashes, so canonicalize everything to forward-slash form.
proc daphne_normalize_path {path_value} {
    return [file normalize [string map {\\ /} $path_value]]
}

# define the hardware description files
set hw_arg   [daphne_normalize_path [lindex $argv 0]]

# define output directory
set out_dir  [daphne_normalize_path [lindex $argv 1]]

# receive the git commit number
set git_sha [lindex $argv 2]
 
# Prefer the explicit HW argument. createdts only treats paths starting with
# "/" as absolute, so on WSL the converted //wsl.localhost/... form must be
# preserved for -hw. Fall back to the output-dir-derived XSA only if needed.
set hw_xsa $hw_arg
if {$hw_xsa eq ""} {
    set hw_xsa [file join $out_dir daphne_selftrigger_$git_sha.xsa]
}

# generate the device tree using the generated XSA
if {$hw_arg ne "" && $hw_arg ne $hw_xsa} {
    puts "INFO: normalized HW path differs from argv; using canonical XSA path $hw_xsa"
}
createdts -hw $hw_xsa -zocl -platform-name daphne_selftrigger_$git_sha -git-branch xlnx_rel_v2022.2 -overlay -out [file join $out_dir daphne_selftrigger_$git_sha]
 
# exit the process once done
exit
