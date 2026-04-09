# Shared Tcl helpers for the DAPHNE selftrigger Vivado batch flow.

source -notrace [file join [file dirname [file normalize [info script]]] "daphne_board_env.tcl"]

proc daphne_run_nonfatal {label command} {
    if {[catch {uplevel 1 $command} err]} {
        puts "WARNING: $label failed: $err"
    }
}

proc daphne_write_matching_objects {output_file object_kind patterns} {
    set fh [open $output_file "w"]
    foreach pattern $patterns {
        puts $fh "=== $pattern ==="
        if {$object_kind eq "pin"} {
            set objects [lsort -unique [get_pins -hier -quiet $pattern]]
        } elseif {$object_kind eq "net"} {
            set objects [lsort -unique [get_nets -hier -quiet $pattern]]
        } elseif {$object_kind eq "clock"} {
            set objects [lsort -unique [get_clocks -quiet $pattern]]
        } else {
            close $fh
            error "ERROR: unsupported object kind '$object_kind' for debug dump"
        }

        if {[llength $objects] == 0} {
            puts $fh "<none>"
        } else {
            foreach object_name $objects {
                puts $fh $object_name
            }
        }
        puts $fh ""
    }
    close $fh
}

proc daphne_dump_post_synth_debug {cfg_name} {
    upvar 1 $cfg_name cfg

    set debug_dir [file join $cfg(output_dir) "debug"]
    file mkdir $debug_dir

    daphne_run_nonfatal "post-synth report_clocks debug dump" \
        [list report_clocks -file [file join $debug_dir "post_synth_clocks_pre_constraints.rpt"]]

    daphne_run_nonfatal "endpoint pin inventory debug dump" \
        [list daphne_write_matching_objects [file join $debug_dir "endpoint_pins_pre_constraints.txt"] pin [list \
            "*timing_bridge_inst/endpoint_inst/*mmcm0_inst/CLKOUT0" \
            "*timing_bridge_inst/endpoint_inst/*mmcm0_inst/CLKOUT2" \
            "*timing_bridge_inst/endpoint_inst/*mmcm0_inst/CLKFBOUT" \
            "*timing_bridge_inst/endpoint_inst/*mmcm1_inst/CLKOUT0" \
            "*timing_bridge_inst/endpoint_inst/*mmcm1_inst/CLKOUT1" \
            "*timing_bridge_inst/endpoint_inst/*mmcm1_inst/CLKFBOUT" \
            "*timing_bridge_inst/endpoint_inst/*mmcm1_clk1_inst/O" \
            "*timing_bridge_inst/endpoint_inst/*mmcm1_clk2_inst/O" \
            "*timing_bridge_inst/endpoint_inst/*pdts_endpoint_inst/*rxcdr/mmcm/CLKOUT0" \
            "*timing_bridge_inst/endpoint_inst/*pdts_endpoint_inst/*rxcdr/mmcm/CLKOUT1" \
            "*timing_bridge_inst/endpoint_inst/*pdts_endpoint_inst/*rxcdr/mmcm/CLKFBOUT" \
        ]]

    daphne_run_nonfatal "endpoint net inventory debug dump" \
        [list daphne_write_matching_objects [file join $debug_dir "endpoint_nets_pre_constraints.txt"] net [list \
            "*timing_bridge_inst/endpoint_inst/*pdts_endpoint_inst/*rxcdr/bclk*" \
            "*timing_bridge_inst/endpoint_inst/*pdts_endpoint_inst/*rxcdr/clku*" \
            "*timing_bridge_inst/endpoint_inst/*clk125*" \
            "*timing_bridge_inst/endpoint_inst/*clk500*" \
        ]]
}

proc daphne_resolve_repo_relative_paths {repo_root raw_paths} {
    set resolved_paths {}
    foreach path_value [split $raw_paths ";"] {
        set trimmed_path [string trim $path_value]
        if {$trimmed_path ne ""} {
            lappend resolved_paths [daphne_resolve_repo_relative_path $repo_root $trimmed_path]
        }
    }
    return $resolved_paths
}

proc daphne_resolve_config {script_dir} {
    array set cfg {}

    set cfg(script_dir) $script_dir
    set cfg(repo_root) [file normalize [file join $script_dir ".."]]
    set board_profile [daphne_resolve_board_profile $cfg(repo_root)]
    set artifact_profile [daphne_resolve_artifact_profile $cfg(repo_root) $board_profile]
    set board_bd_name [daphne_board_profile_value_with_fallback $board_profile legacy_bd_name bd_name "daphne_selftrigger_bd"]
    set board_bd_wrapper_name [daphne_board_profile_value_with_fallback $board_profile legacy_bd_wrapper_name bd_wrapper_name "${board_bd_name}_wrapper"]
    set cfg(vivado_version) 2024.1
    set vitis_version [daphne_get_env_or_default DAPHNE_VITIS_VERSION $cfg(vivado_version)]
    set cfg(fpga_part) [daphne_get_env_or_default DAPHNE_FPGA_PART [dict get $board_profile fpga_part]]
    set cfg(board_part) [daphne_get_env_or_default DAPHNE_BOARD_PART [dict get $board_profile board_part]]
    set cfg(pfm_name) [daphne_get_env_or_default DAPHNE_PFM_NAME [dict get $board_profile pfm_name]]
    set cfg(max_threads) [daphne_get_env_or_default DAPHNE_MAX_THREADS "8"]
    set cfg(synth_directive) [daphne_get_env_or_default DAPHNE_SYNTH_DIRECTIVE "PerformanceOptimized"]
    set cfg(opt_directive) [daphne_get_env_or_default DAPHNE_OPT_DIRECTIVE "Explore"]
    set cfg(place_directive) [daphne_get_env_or_default DAPHNE_PLACE_DIRECTIVE "WLDrivenBlockPlacement"]
    set cfg(post_place_physopt_directive) [daphne_get_env_or_default DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE "AggressiveFanoutOpt"]
    set cfg(route_directive) [daphne_get_env_or_default DAPHNE_ROUTE_DIRECTIVE "AlternateCLBRouting"]
    set cfg(post_route_physopt_directive) [daphne_get_env_or_default DAPHNE_POST_ROUTE_PHYSOPT_DIRECTIVE "AggressiveExplore"]
    set cfg(dtg_git_branch) [daphne_get_env_or_default DAPHNE_DTG_GIT_BRANCH "xlnx_rel_v${vitis_version}"]
    set cfg(pre_place_power_opt) [daphne_get_env_or_default DAPHNE_PRE_PLACE_POWER_OPT "0"]
    set cfg(post_place_power_opt) [daphne_get_env_or_default DAPHNE_POST_PLACE_POWER_OPT "0"]
    set cfg(skip_post_place_checkpoint) [daphne_get_env_or_default DAPHNE_SKIP_POST_PLACE_CHECKPOINT "0"]
    set cfg(skip_post_synth_reports) [daphne_get_env_or_default DAPHNE_SKIP_POST_SYNTH_REPORTS "0"]
    set cfg(skip_post_synth_checkpoint) [daphne_get_env_or_default DAPHNE_SKIP_POST_SYNTH_CHECKPOINT "0"]
    set cfg(stop_after_synth) [daphne_get_env_or_default DAPHNE_STOP_AFTER_SYNTH "0"]
    set cfg(dump_post_synth_debug) [daphne_get_env_or_default DAPHNE_DUMP_POST_SYNTH_DEBUG $cfg(stop_after_synth)]
    set cfg(output_dir) [daphne_get_env_or_default DAPHNE_OUTPUT_DIR "./output"]

    if {[file pathtype $cfg(output_dir)] ne "absolute"} {
        set cfg(output_dir) [file normalize [file join $script_dir $cfg(output_dir)]]
    }

    set cfg(bd_name) [daphne_get_env_or_default DAPHNE_BD_NAME $board_bd_name]
    set cfg(bd_wrapper_name) [daphne_get_env_or_default DAPHNE_BD_WRAPPER_NAME $board_bd_wrapper_name]
    set cfg(build_name_prefix) [dict get $artifact_profile build_name_prefix]
    set cfg(overlay_name_prefix) [dict get $artifact_profile overlay_name_prefix]
    set cfg(bd_file) [file join $cfg(repo_root) "bd" $cfg(bd_name) "${cfg(bd_name)}.bd"]
    set cfg(bd_wrapper_vhd) [file join $cfg(repo_root) "bd" $cfg(bd_name) "hdl" "${cfg(bd_wrapper_name)}.vhd"]
    set board_constraint_files_raw [expr {[dict exists $board_profile constraint_files] ? [dict get $board_profile constraint_files] : [dict get $board_profile constraint_file]}]
    set board_required_constraint_files_raw [expr {[dict exists $board_profile required_constraint_files] ? [dict get $board_profile required_constraint_files] : ""}]
    set cfg(constraint_files) [daphne_resolve_repo_relative_paths $cfg(repo_root) [daphne_get_env_or_default DAPHNE_CONSTRAINT_FILES $board_constraint_files_raw]]
    if {[llength $cfg(constraint_files)] == 0} {
        error "ERROR: board profile did not resolve any constraint files."
    }
    daphne_require_resolved_paths "Board constraint files" $cfg(repo_root) $board_required_constraint_files_raw $cfg(constraint_files)
    set cfg(pinmap_xdc) [lindex $cfg(constraint_files) 0]
    set cfg(dtbo_gen_tcl) [file join $script_dir "daphne_dtbo_gen.tcl"]
    set cfg(axi_quad_spi_patch) [file join $script_dir "scripts" "axi_quad_spi_dtbo_patch.sed"]

    set cfg(git_sha) [dict get $artifact_profile git_sha]
    set cfg(v_git_sha) "28'h$cfg(git_sha)"
    set cfg(build_name) [dict get $artifact_profile build_name]
    set cfg(overlay_name) [dict get $artifact_profile overlay_name]

    foreach {env_name key} {
        DAPHNE_TIMING_ENDPOINT_PATH timing_endpoint_path
        DAPHNE_TIMING_PLANE_PATH timing_plane_path
        DAPHNE_AFE_CAPTURE_INPUT_DELAY_ENABLE afe_capture_input_delay_enable
        DAPHNE_AFE_CAPTURE_VIRTUAL_LAUNCH_PERIOD_NS afe_capture_virtual_launch_period_ns
        DAPHNE_AFE_CAPTURE_INPUT_DELAY_MIN_NS afe_capture_input_delay_min_ns
        DAPHNE_AFE_CAPTURE_INPUT_DELAY_MAX_NS afe_capture_input_delay_max_ns
    } {
        daphne_seed_env_from_board_profile $board_profile $env_name $key
    }

    return [array get cfg]
}

proc daphne_check_vivado_version {cfg_name} {
    upvar 1 $cfg_name cfg
    set currentVivadoVersion [version -short]

    if {[string first $cfg(vivado_version) $currentVivadoVersion] == -1} {
        puts ""
        if {[string compare $cfg(vivado_version) $currentVivadoVersion] > 0} {
            catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" "This script was written using Vivado <$cfg(vivado_version)> and is being run in <$currentVivadoVersion> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}
            return -code error "Vivado version mismatch"
        } else {
            catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "WARNING" "This script was written using Vivado <$cfg(vivado_version)> and is being run in <$currentVivadoVersion> of Vivado. Please run the script in Vivado <$cfg(vivado_version)> or update the script according to Vivado <$currentVivadoVersion> version commands using -help."}
            puts "WARNING: Running script built with Vivado $cfg(vivado_version) in newer version Vivado $currentVivadoVersion."
        }
    }
}

proc daphne_prepare_project {cfg_name} {
    upvar 1 $cfg_name cfg

    set_param general.maxThreads $cfg(max_threads)

    if {[file exists $cfg(output_dir)]} {
        puts "INFO: Output directory already exists at $cfg(output_dir)."
        puts "INFO: Deleting older version of output files."
        file delete -force $cfg(output_dir)
    }
    file mkdir $cfg(output_dir)

    set_part $cfg(fpga_part)
    set_property BOARD_PART $cfg(board_part) [current_project]
    set_property TARGET_LANGUAGE VHDL [current_project]
    set_property DEFAULT_LIB work [current_project]
    set ::env(DAPHNE_PFM_NAME) $cfg(pfm_name)

    puts "INFO: Running Vivado batch for part <$cfg(fpga_part)> board_part <$cfg(board_part)> pfm <$cfg(pfm_name)>."
    puts "INFO: Threads=$cfg(max_threads) synth=$cfg(synth_directive) opt=$cfg(opt_directive) place=$cfg(place_directive) route=$cfg(route_directive)."
    puts "INFO: Pre-place power opt=$cfg(pre_place_power_opt) post-place power opt=$cfg(post_place_power_opt)."
    puts "INFO: Device-tree generator branch=$cfg(dtg_git_branch)."
    puts "INFO: Post-synth reports skipped=$cfg(skip_post_synth_reports) checkpoint skipped=$cfg(skip_post_synth_checkpoint)."
    puts "INFO: Post-place checkpoint skipped=$cfg(skip_post_place_checkpoint)."
    puts "INFO: Stop after synth=$cfg(stop_after_synth)."
    puts "INFO: Dump post-synth debug=$cfg(dump_post_synth_debug)."
    puts "INFO: passing git commit number $cfg(v_git_sha) to top level generic"
}

proc daphne_create_block_design {cfg_name} {
    upvar 1 $cfg_name cfg

    set v_git_sha $cfg(v_git_sha)
    source -notrace [file join $cfg(script_dir) "daphne_bd_gen.tcl"]
    set bd_file_obj [get_files -quiet $cfg(bd_file)]
    if {[llength $bd_file_obj] == 0} {
        read_bd $cfg(bd_file)
        set bd_file_obj [get_files -quiet $cfg(bd_file)]
    }
    make_wrapper -top -files $bd_file_obj
    read_vhdl $cfg(bd_wrapper_vhd)
    set cfg(post_synth_constraint_files) {}
    foreach constraint_file $cfg(constraint_files) {
        set constraint_basename [file tail $constraint_file]
        if {$constraint_basename in {"afe_capture_timing.tcl" "frontend_control_cdc.tcl"}} {
            lappend cfg(post_synth_constraint_files) $constraint_file
        } else {
            read_xdc -verbose $constraint_file
        }
    }
    set_property synth_checkpoint_mode None $bd_file_obj
    generate_target all $bd_file_obj

    # BD-owned child IP must only be generated through the parent BD target.
    set project_ips [get_ips -quiet -filter "NAME !~ ${cfg(bd_name)}_*"]
    if {[llength $project_ips] > 0} {
        generate_target all $project_ips
        daphne_run_nonfatal "export_ip_user_files" [list export_ip_user_files -of_objects $project_ips -no_script -sync -force -quiet]
    }
}

proc daphne_run_synth {cfg_name} {
    upvar 1 $cfg_name cfg

    synth_design -top $cfg(bd_wrapper_name) -directive $cfg(synth_directive)
    if {[string tolower $cfg(dump_post_synth_debug)] in {"1" "true" "yes" "on"}} {
        puts "INFO: Dumping post-synth clock/object debug reports before Tcl-backed timing constraints."
        daphne_dump_post_synth_debug cfg
    }
    foreach constraint_file $cfg(post_synth_constraint_files) {
        puts "INFO: Loading post-synth unmanaged Tcl-backed constraint script $constraint_file"
        read_xdc -unmanaged $constraint_file
    }
    if {$cfg(skip_post_synth_reports) eq "1"} {
        puts "INFO: Skipping post-synth reports by request."
    } else {
        daphne_run_nonfatal "post-synth report_clocks" [list report_clocks -file [file join $cfg(output_dir) "clocks.rpt"]]
        daphne_run_nonfatal "post-synth report_timing_summary" [list report_timing_summary -file [file join $cfg(output_dir) "post_synth_timing_summary.rpt"]]
        daphne_run_nonfatal "post-synth report_power" [list report_power -file [file join $cfg(output_dir) "post_synth_power.rpt"]]
        daphne_run_nonfatal "post-synth report_utilization" [list report_utilization -file [file join $cfg(output_dir) "post_synth_util.rpt"]]
    }
    if {$cfg(skip_post_synth_checkpoint) eq "1"} {
        puts "INFO: Skipping post-synth checkpoint by request."
    } else {
        write_checkpoint -force [file join $cfg(output_dir) "${cfg(bd_name)}_synth.dcp"]
    }
}

proc daphne_run_impl {cfg_name} {
    upvar 1 $cfg_name cfg

    opt_design -directive $cfg(opt_directive)
    if {[string tolower $cfg(pre_place_power_opt)] in {"1" "true" "yes" "on"}} {
        power_opt_design
    }
    place_design -directive $cfg(place_directive)
    if {[string tolower $cfg(post_place_power_opt)] in {"1" "true" "yes" "on"}} {
        power_opt_design
    }
    phys_opt_design -directive $cfg(post_place_physopt_directive)
    if {$cfg(skip_post_place_checkpoint) eq "1"} {
        puts "INFO: Skipping post-place checkpoint by request."
    } else {
        write_checkpoint -force [file join $cfg(output_dir) "${cfg(bd_name)}_post_place.dcp"]
    }
    report_timing_summary -file [file join $cfg(output_dir) "post_place_timing_summary.rpt"]
    report_timing -sort_by group -max_paths 100 -path_type summary -file [file join $cfg(output_dir) "post_place_timing.rpt"]
    report_clock_utilization -file [file join $cfg(output_dir) "post_place_clock_util.rpt"]
    daphne_run_nonfatal "post-place report_power" [list report_power -file [file join $cfg(output_dir) "post_place_power.rpt"]]

    route_design -directive $cfg(route_directive)
    phys_opt_design -directive $cfg(post_route_physopt_directive)
    write_checkpoint -force [file join $cfg(output_dir) "${cfg(bd_name)}_post_route.dcp"]

    report_timing_summary -file [file join $cfg(output_dir) "post_route_timing_summary.rpt"]
    report_timing -sort_by group -max_paths 100 -path_type summary -file [file join $cfg(output_dir) "post_route_timing.rpt"]
    report_clock_utilization -file [file join $cfg(output_dir) "clock_util.rpt"]
    report_utilization -file [file join $cfg(output_dir) "post_route_util.rpt"]
    report_power -file [file join $cfg(output_dir) "post_route_power.rpt"]
    report_drc -file [file join $cfg(output_dir) "post_imp_drc.rpt"]
    report_io -file [file join $cfg(output_dir) "io.rpt"]
    write_checkpoint -force [file join $cfg(output_dir) "${cfg(bd_name)}_post_impl.dcp"]
}

proc daphne_write_bitstream_and_xsa {cfg_name} {
    upvar 1 $cfg_name cfg

    write_bitstream -force -bin_file [file join $cfg(output_dir) "${cfg(build_name)}.bit"]
    write_hw_platform -fixed -force -include_bit -file [file join $cfg(output_dir) "${cfg(build_name)}.xsa"]
}

proc daphne_package_overlay_linux {cfg_name} {
    upvar 1 $cfg_name cfg

    set overlay_dir [file join $cfg(output_dir) $cfg(overlay_name)]
    file mkdir $overlay_dir

    if {![info exists ::env(XILINX_VITIS)]} {
        error "ERROR: XILINX_VITIS is not set. Please source settings64.bat/.sh first."
    }

    set vitis_path $::env(XILINX_VITIS)
    puts "INFO: Found Vitis at $vitis_path."
    set xsct_exe [file join $vitis_path "bin" "xsct"]

    puts "INFO: Generating Device Tree files."
    if {[catch {exec $xsct_exe $cfg(dtbo_gen_tcl) [file join $cfg(output_dir) "${cfg(build_name)}.xsa"] $cfg(output_dir) $cfg(git_sha) 2>@1} result]} {
        error "ERROR: xsct command failed:\n$result"
    }
    puts "INFO: Device Tree files have been generated."

    set pl_dtsi_path [glob -nocomplain -types f [file join $cfg(output_dir) $cfg(build_name) "*" "*" "*" "*" "*" "*" "pl.dtsi"]]
    puts "INFO: Adding missing lines for AXI Quad SPI module in the dtsi file."
    exec sed -i -f $cfg(axi_quad_spi_patch) $pl_dtsi_path
    puts "INFO: Finished adding missing lines for dtsi file."

    puts "INFO: Compiling Device Tree."
    if {[catch {exec dtc -@ -O dtb -o [file join $cfg(output_dir) "${cfg(build_name)}.dtbo"] $pl_dtsi_path 2>@1} result]} {
        error "ERROR: dtc command failed:\n$result"
    }
    puts "INFO: Device Tree files have been compiled."

    puts "INFO: Creating json file."
    exec echo { { "shell_type" : "XRT_FLAT", "num_slots": "1" } } > [file join $cfg(output_dir) "shell.json"]
    puts "INFO: Json file has been generated."

    puts "INFO: Creating Overlay folder."
    file rename -force [file join $cfg(output_dir) "${cfg(build_name)}.dtbo"] [file join $overlay_dir "${cfg(overlay_name)}.dtbo"]
    file rename -force [file join $cfg(output_dir) "${cfg(build_name)}.bin"] [file join $overlay_dir "${cfg(overlay_name)}.bin"]
    file rename -force [file join $cfg(output_dir) "shell.json"] [file join $overlay_dir "shell.json"]

    set old_dir [pwd]
    cd $cfg(output_dir)
    exec zip -r "${cfg(overlay_name)}.zip" $cfg(overlay_name)
    cd $old_dir
    puts "INFO: Successfully generated Device Tree Overlay folder."
}

proc daphne_export_dt_windows {cfg_name} {
    upvar 1 $cfg_name cfg

    if {![info exists ::env(XILINX_VITIS)]} {
        puts "WARNING: XILINX_VITIS is not set. Skipping Windows device-tree helper step."
        puts "INFO: Hardware build completed with outputs in $cfg(output_dir)."
        return
    }

    set vitis_path $::env(XILINX_VITIS)
    puts "INFO: Found Vitis at $vitis_path."
    set xsct_exe [file join $vitis_path "bin" "xsct.bat"]
    if {![file exists $xsct_exe]} {
        set xsct_exe [file join $vitis_path "bin" "xsct"]
    }

    puts "INFO: Generating Device Tree files."
    if {[catch {exec $xsct_exe -eval "hsi::open_hw_design [file join $cfg(output_dir) ${cfg(build_name)}.xsa]; createdts -hw [file join $cfg(output_dir) ${cfg(build_name)}.xsa] -zocl -platform-name $cfg(build_name) -git-branch $cfg(dtg_git_branch) -overlay -out [file join $cfg(output_dir) $cfg(build_name)]; exit" 2>@1} result]} {
        error "ERROR: xsct command failed:\n$result"
    }
    puts "INFO: Device Tree files have been generated."
    puts "INFO: Please make sure to edit .dtsi file with the proper lines for AXI Quad SPI Module, and run the dtc command to compile the design."
}

proc daphne_run_post_build {cfg_name} {
    upvar 1 $cfg_name cfg

    if {$::tcl_platform(os) eq "Linux"} {
        puts "INFO: Running current TCL script on $::tcl_platform(os)."
        daphne_package_overlay_linux cfg
    } elseif {$::tcl_platform(os) eq "Windows NT"} {
        puts "INFO: Running current TCL script on $::tcl_platform(os)."
        puts "WARNING: Device Tree Overlay can not be automatically produced on Windows."
        puts "WARNING: Please make sure to use the .xsa File to manually generate the necessary outputs."
        daphne_export_dt_windows cfg
    } else {
        puts "WARNING: Unknown OS $::tcl_platform(os)."
    }
}

proc daphne_run_full_build {script_dir} {
    array set cfg [daphne_resolve_config $script_dir]
    daphne_check_vivado_version cfg
    daphne_prepare_project cfg
    daphne_create_block_design cfg
    daphne_run_synth cfg
    if {[string tolower $cfg(stop_after_synth)] in {"1" "true" "yes" "on"}} {
        puts "INFO: Stopping after synthesis and post-synth constraint application by request."
        exit
    }
    daphne_run_impl cfg
    daphne_write_bitstream_and_xsa cfg
    daphne_run_post_build cfg
    puts "INFO: Finished design building."
    exit
}
