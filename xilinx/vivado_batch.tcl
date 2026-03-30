# TCL script to build DAPHNE3 vivado design
# Daniel Avila Gomez <daniel.avila@eia.edu.co - daniel.avila.gomez@cern.ch> and Jamieson Olsen <jamieson@fnal.gov>
#
# run: vivado -mode tcl -source vivado_batch.tcl

# check if script is running in correct Vivado version
set scriptsVivadoVersion 2024.1
set currentVivadoVersion [version -short]
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set bd_file [file join $repo_root "bd" "DAPHNE_MEZ_SELFTRIGGER_V1" "DAPHNE_MEZ_SELFTRIGGER_V1.bd"]
set bd_wrapper_vhd [file join $repo_root "bd" "DAPHNE_MEZ_SELFTRIGGER_V1" "hdl" "DAPHNE_MEZ_SELFTRIGGER_V1_wrapper.vhd"]
set pinmap_xdc [file join $script_dir "DAPHNE_V3_PIN_MAP.xdc"]
set dtbo_gen_tcl [file join $script_dir "daphne3_dtbo_gen.tcl"]
set axi_quad_spi_patch [file join $script_dir "scripts" "axi_quad_spi_dtbo_patch.sed"]

if { [string first $scriptsVivadoVersion $currentVivadoVersion] == -1 } {
    puts ""
    if { [string compare $scriptsVivadoVersion $currentVivadoVersion] > 0 } {
        catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" "This script was written using Vivado <$scriptsVivadoVersion> and is being run in <$currentVivadoVersion> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}
        return 1
    } else {
        catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "WARNING" "This script was written using Vivado <$scriptsVivadoVersion> and is being run in <$currentVivadoVersion> of Vivado. Please run the script in Vivado <$scriptsVivadoVersion> or update the script according to Vivado <$currentVivadoVersion> version commands using -help."}
        puts "WARNING: Running script built with Vivado $scriptsVivadoVersion in newer version Vivado $currentVivadoVersion."
    }
}

# general setup stuff
source -notrace [file join $script_dir "daphne_board_env.tcl"]
set daphne_fpga_part [daphne_get_env_or_default DAPHNE_FPGA_PART "xck26-sfvc784-2LV-c"]
set daphne_board_part [daphne_get_env_or_default DAPHNE_BOARD_PART "xilinx.com:k26c:part0:1.4"]
set daphne_pfm_name [daphne_get_env_or_default DAPHNE_PFM_NAME "xilinx:k26c:name:0.0"]
set daphne_max_threads [daphne_get_env_or_default DAPHNE_MAX_THREADS "8"]
set daphne_synth_directive [daphne_get_env_or_default DAPHNE_SYNTH_DIRECTIVE "PerformanceOptimized"]
set daphne_opt_directive [daphne_get_env_or_default DAPHNE_OPT_DIRECTIVE "Explore"]
set daphne_place_directive [daphne_get_env_or_default DAPHNE_PLACE_DIRECTIVE "WLDrivenBlockPlacement"]
set daphne_post_place_physopt_directive [daphne_get_env_or_default DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE "AggressiveFanoutOpt"]
set daphne_route_directive [daphne_get_env_or_default DAPHNE_ROUTE_DIRECTIVE "AlternateCLBRouting"]
set daphne_post_route_physopt_directive [daphne_get_env_or_default DAPHNE_POST_ROUTE_PHYSOPT_DIRECTIVE "AggressiveExplore"]
set daphne_skip_post_synth_reports [daphne_get_env_or_default DAPHNE_SKIP_POST_SYNTH_REPORTS "0"]
set daphne_skip_post_synth_checkpoint [daphne_get_env_or_default DAPHNE_SKIP_POST_SYNTH_CHECKPOINT "0"]

proc daphne_run_nonfatal {label command} {
    if {[catch {uplevel 1 $command} err]} {
        puts "WARNING: $label failed: $err"
    }
}

set_param general.maxThreads $daphne_max_threads
set outputDir [daphne_get_env_or_default DAPHNE_OUTPUT_DIR "./output"]
if {[file pathtype $outputDir] ne "absolute"} {
    set outputDir [file normalize [file join $script_dir $outputDir]]
}
# verify if the output folder has already been created
if {[file exists $outputDir]} {
    # output folder already exists, therefore delete it and its contents
    puts "INFO: Output directory already exists at $outputDir."
    puts "INFO: Deleting older version of output files."
    file delete -force $outputDir
}
# create the new folder to populate later with the results of the process
file mkdir $outputDir 
set_part $daphne_fpga_part
set_property BOARD_PART $daphne_board_part [current_project]
set_property TARGET_LANGUAGE VHDL [current_project]
set_property DEFAULT_LIB work [current_project]
set ::env(DAPHNE_PFM_NAME) $daphne_pfm_name
puts "INFO: Running Vivado batch for part <$daphne_fpga_part> board_part <$daphne_board_part> pfm <$daphne_pfm_name>."
puts "INFO: Threads=$daphne_max_threads synth=$daphne_synth_directive opt=$daphne_opt_directive place=$daphne_place_directive route=$daphne_route_directive."
puts "INFO: Post-synth reports skipped=$daphne_skip_post_synth_reports checkpoint skipped=$daphne_skip_post_synth_checkpoint."

# # get the git SHA hash (commit id) and pass it to the top level source
# # keep it simple just use the short form of the long SHA-1 number.
# # Note this is a 7 character HEX string, e.g. 28 bits, but Vivado requires 
# # this number to be in Verilog notation, even if the top level source is VHDL.

set git_sha_override [daphne_get_env_or_default DAPHNE_GIT_SHA ""]
if {$git_sha_override ne ""} {
    set git_sha $git_sha_override
    puts "INFO: Using git SHA override from DAPHNE_GIT_SHA=$git_sha"
} else {
    if {[catch {exec git rev-parse --short=7 HEAD} git_sha]} {
        set git_sha "0000000"
        puts "WARNING: Could not resolve git HEAD. Falling back to git SHA $git_sha."
    }
}
set v_git_sha "28'h$git_sha"
puts "INFO: passing git commit number $v_git_sha to top level generic"

# create the block design
# this command also verifies if the block design already exists, if so, it deletes it in order to generate a newer version
source -notrace [file join $script_dir "daphne3_bd_gen.tcl"]
read_bd $bd_file

# # verify if the block design exists, if not, create it
# set bdFile ../bd/DAPHNE_MEZ_SELFTRIGGER_V1/DAPHNE_MEZ_SELFTRIGGER_V1.bd
# if {![file exists $bdFile]} {
#     # the file does not exist, create it, then read it
#     # since sourcing the tcl file updates the IP catalog, we don't have to do it here
#     source ./daphne3_bd_gen.tcl
#     read_bd ../bd/DAPHNE_MEZ_SELFTRIGGER_V1/DAPHNE_MEZ_SELFTRIGGER_V1.bd
# } else {
#     # the file exist
#     # re package the IP to consider possible changes to its source files
#     # running this command also updates the IP repo path and the Vivado IP catalog
#     # this ensures that the block design is properly read
#     source daphne3_ip_gen.tcl

#     # update IP catalog
#     set_property IP_REPO_PATHS ../ip_repo [current_project]
#     update_ip_catalog 

#     # read the block design
#     read_bd ../bd/DAPHNE_MEZ_SELFTRIGGER_V1/DAPHNE_MEZ_SELFTRIGGER_V1.bd

#     # open the block design
#     open_bd_design ../bd/DAPHNE_MEZ_SELFTRIGGER_V1/DAPHNE_MEZ_SELFTRIGGER_V1.bd

#     # upgrade the DAPHNE IP
#     upgrade_ip [get_ips DAPHNE_MEZ_SELFTRIGGER_V1]

#     # re configure the version parameter of the IP with the current git commit number
#     set_property CONFIG.version $v_git_sha [get_ips DAPHNE_MEZ_SELFTRIGGER_V1]

#     # regenerate layout so it looks cleaner
#     regenerate_bd_layout

#     # check the integrity of the block design
#     validate_bd_design

#     # save it 
#     save_bd_design

#     # close the file
#     close_bd_design [current_bd_design]
# }

# make the wrapper of the block design needed for later synthesis and implementation
make_wrapper -top -files [get_files $bd_file]
read_vhdl $bd_wrapper_vhd

# load general placement constraints...
read_xdc -verbose $pinmap_xdc

# generate the output products of the Block Design needed for synthesis and implementation
set_property synth_checkpoint_mode None [get_files $bd_file]
generate_target all [get_files $bd_file]

# synth design...
synth_design -top DAPHNE_MEZ_SELFTRIGGER_V1_wrapper -directive $daphne_synth_directive
if {$daphne_skip_post_synth_reports eq "1"} {
    puts "INFO: Skipping post-synth reports by request."
} else {
    daphne_run_nonfatal "post-synth report_clocks" [list report_clocks -file $outputDir/clocks.rpt]
    daphne_run_nonfatal "post-synth report_timing_summary" [list report_timing_summary -file $outputDir/post_synth_timing_summary.rpt]
    daphne_run_nonfatal "post-synth report_power" [list report_power -file $outputDir/post_synth_power.rpt]
    daphne_run_nonfatal "post-synth report_utilization" [list report_utilization -file $outputDir/post_synth_util.rpt]
}
if {$daphne_skip_post_synth_checkpoint eq "1"} {
    puts "INFO: Skipping post-synth checkpoint by request."
} else {
    write_checkpoint -force $outputDir/DAPHNE_MEZ_SELFTRIGGER_V1_synth.dcp
}

# place...
opt_design -directive $daphne_opt_directive
place_design -directive $daphne_place_directive
phys_opt_design -directive $daphne_post_place_physopt_directive
# write_checkpoint -force $outputDir/post_place
report_timing_summary -file $outputDir/post_place_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/post_place_timing.rpt

# route...
route_design -directive $daphne_route_directive
phys_opt_design -directive $daphne_post_route_physopt_directive
write_checkpoint -force $outputDir/DAPHNE_MEZ_SELFTRIGGER_V1_post_route.dcp

# generate reports...
report_timing_summary -file $outputDir/post_route_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/post_route_timing.rpt
report_clock_utilization -file $outputDir/clock_util.rpt
report_utilization -file $outputDir/post_route_util.rpt
report_power -file $outputDir/post_route_power.rpt
report_drc -file $outputDir/post_imp_drc.rpt
report_io -file $outputDir/io.rpt
write_checkpoint -force $outputDir/DAPHNE_MEZ_SELFTRIGGER_V1_post_impl.dcp

# generate bitstream...
write_bitstream -force -bin_file $outputDir/daphne3_st_$git_sha.bit
# write_bitstream -force -bin_file $outputDir/daphne3.bit

# write out ILA debug probes file
# write_debug_probes -force $outputDir/probes.ltx

# export the implemented hardware system to the Vitis environment
write_hw_platform -fixed -force -include_bit -file $outputDir/daphne3_st_$git_sha.xsa
# write_hw_platform -fixed -force -file $outputDir/daphne3.xsa
 
# define if the script is running on Windows or Linux
if {$tcl_platform(os) eq "Linux"} {
    puts "INFO: Running current TCL script on $tcl_platform(os)."
 
    # since we are running on Linux, we can generate everything up to the overlay folder
    # including .bin .dtbo and .json files
    # now package the overlay needed files
    set overlayDir [file join $outputDir "daphne3_st_OL_$git_sha"]
    file mkdir $overlayDir
 
    # check if vitis is on PATH
    if {![info exists ::env(XILINX_VITIS)]} {
        # tell the user that vitis is not on PATH and must source its environment first
        error "ERROR: XILINX_VITIS is not set. Please source settings64.bat/.sh first."
    } else {
        # as vitis is on PATH, we can do everything
        set vitis_path $::env(XILINX_VITIS)
        puts "INFO: Found Vitis at $vitis_path."
 
        # set the XSCT path
        set xsct_exe [file join $vitis_path bin xsct]
 
        # run the XSCT script
        puts "INFO: Generating Device Tree files."
        if {[catch {exec $xsct_exe $dtbo_gen_tcl "$outputDir/daphne3_st_$git_sha.xsa" $outputDir $git_sha 2>@1} result]} {
            error "ERROR: xsct command failed:\n$result"
        }
        puts "INFO: Device Tree files have been generated."
 
        # locate the DTSI file
        set pl_dtsi_path [glob -nocomplain -types f "$outputDir/daphne3_st_$git_sha/*/*/*/*/*/*/pl.dtsi"]
 
        # add missing lines for AXI Quad SPI module
        puts "INFO: Adding missing lines for AXI Quad SPI module in the dtsi file."
        exec sed -i -f $axi_quad_spi_patch $pl_dtsi_path
        puts "INFO: Finished adding missing lines for dtsi file."
 
        # compile the Device Tree
        puts "INFO: Compiling Device Tree."
        if {[catch {exec dtc -@ -O dtb -o $outputDir/daphne3_st_$git_sha.dtbo $pl_dtsi_path 2>@1} result]} {
            error "ERROR: dtc command failed:\n$result"
        }        
        puts "INFO: Device Tree files have been compiled."
 
        # create the shell.json file
        puts "INFO: Creating json file."
        exec echo { { "shell_type" : "XRT_FLAT", "num_slots": "1" } } > $outputDir/shell.json
        puts "INFO: Json file has been generated."
 
        # now, move all the necessary files to the overlay folder
        puts "INFO: Creating Overlay folder."
        file rename -force $outputDir/daphne3_st_$git_sha.dtbo $overlayDir/daphne3_st_OL_$git_sha.dtbo
        file rename -force $outputDir/daphne3_st_$git_sha.bin $overlayDir/daphne3_st_OL_$git_sha.bin
        file rename -force $outputDir/shell.json $overlayDir/shell.json
 
        # zip the resulting folder 
        cd $outputDir
        exec zip -r daphne3_st_OL_$git_sha.zip daphne3_st_OL_$git_sha
        puts "INFO: Successfully generated Device Tree Overlay folder."
 
        # finally, we're ready to go, so we can exit Vivado
        puts "INFO: Finished design building."
        exit
    }
} elseif {$tcl_platform(os) eq "Windows NT"} {
    puts "INFO: Running current TCL script on $tcl_platform(os)."

    # since we are running on Windows, we cannot generate everything up to the overlay folder
    # we would need to do everything on a separate script using WSL commands
    puts "WARNING: Device Tree Overlay can not be automatically produced on Windows."
    puts "WARNING: Please make sure to use the .xsa File to manually generate the necessary outputs."

    # check if vitis is on PATH
    if {![info exists ::env(XILINX_VITIS)]} {
        puts "WARNING: XILINX_VITIS is not set. Skipping Windows device-tree helper step."
        puts "INFO: Hardware build completed with outputs in $outputDir."
        exit
    } else {
        # as vitis is on PATH, we can generate .dts .dtsi files
        set vitis_path $::env(XILINX_VITIS)
        puts "INFO: Found Vitis at $vitis_path."

        # set the XSCT path
        set xsct_exe [file join $vitis_path bin xsct]
 
        # run the XSCT script
        puts "INFO: Generating Device Tree files."
        if {[catch {exec $xsct_exe -eval "hsi::open_hw_design $outputDir/daphne3_st_$git_sha.xsa; createdts -hw $outputDir/daphne3_st_$git_sha.xsa -zocl -platform-name daphne3_st_$git_sha -git-branch xlnx_rel_v2022.2 -overlay -out $outputDir/daphne3_st_$git_sha; exit" 2>@1} result]} {
            error "ERROR: xsct command failed:\n$result"
        }
        puts "INFO: Device Tree files have been generated."
 
        # tell the user that from this point, everything must be run manually
        puts "INFO: Please make sure to edit .dtsi file with the proper lines for AXI Quad SPI Module, and run the dtc command to compile the design."
        exit
    } 
} else {
    puts "WARNING: Unknown OS $tcl_platform(os)."
}
