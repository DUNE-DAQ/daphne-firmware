# simple TCL code to generate Device Tree Overlay for Petalinux
# this code must run inside the XSCT Vitis environment
# call for this specific process to run first

# Normalize WSL/Windows path strings for XSCT on Windows.
# In particular, createdts is stricter than hsi::open_hw_design about UNC
# paths with backslashes, so canonicalize everything to forward-slash form.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
source [file join $script_dir "daphne_board_env.tcl"]
set daphne_board_profile [daphne_resolve_board_profile $repo_root]
set default_vitis_version [daphne_get_env_or_default DAPHNE_VITIS_VERSION "2024.1"]
set dtg_git_branch [daphne_get_env_or_default DAPHNE_DTG_GIT_BRANCH "xlnx_rel_v${default_vitis_version}"]

proc daphne_normalize_path {path_value} {
    return [file normalize [string map {\\ /} $path_value]]
}

# define the hardware description files
set hw_arg   [daphne_normalize_path [lindex $argv 0]]

# define output directory
set out_dir  [daphne_normalize_path [lindex $argv 1]]

# receive the git commit number
set git_sha [lindex $argv 2]
set artifact_prefix [lindex $argv 3]
set overlay_prefix [lindex $argv 4]
set default_artifact_prefix [expr {[dict exists $daphne_board_profile build_name_prefix] ? [dict get $daphne_board_profile build_name_prefix] : "daphne_selftrigger"}]
set default_overlay_prefix [expr {[dict exists $daphne_board_profile overlay_name_prefix] ? [dict get $daphne_board_profile overlay_name_prefix] : "${default_artifact_prefix}_ol"}]

if {$artifact_prefix eq ""} {
    set artifact_prefix [daphne_get_env_or_default DAPHNE_BUILD_NAME_PREFIX $default_artifact_prefix]
}
if {$overlay_prefix eq ""} {
    set overlay_prefix [daphne_get_env_or_default DAPHNE_OVERLAY_NAME_PREFIX $default_overlay_prefix]
}
 
# Prefer the explicit HW argument. createdts only treats paths starting with
# "/" as absolute, so on WSL the converted //wsl.localhost/... form must be
# preserved for -hw. Fall back to the output-dir-derived XSA only if needed.
set hw_xsa $hw_arg
if {$hw_xsa eq ""} {
    set hw_xsa [file join $out_dir ${artifact_prefix}_$git_sha.xsa]
}

if {![file exists $hw_xsa]} {
    error "ERROR: expected hardware handoff at $hw_xsa"
}

# generate the device tree using the generated XSA
if {$hw_arg ne "" && $hw_arg ne $hw_xsa} {
    puts "INFO: normalized HW path differs from argv; using canonical XSA path $hw_xsa"
}
hsi::open_hw_design $hw_xsa
createdts -hw $hw_xsa -zocl -platform-name ${artifact_prefix}_$git_sha -git-branch $dtg_git_branch -overlay -out [file join $out_dir ${artifact_prefix}_$git_sha]
 
# exit the process once done
exit
