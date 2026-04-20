# Shared Tcl helpers for the fullstream Vivado batch flow.

proc daphne_fullstream_get_env {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default_value
}

proc daphne_fullstream_resolve_git_sha {} {
    set git_sha [daphne_fullstream_get_env DAPHNE_GIT_SHA ""]
    if {$git_sha ne ""} {
        return $git_sha
    }
    if {[catch {exec git rev-parse --short=7 HEAD} git_sha]} {
        return "0000000"
    }
    return $git_sha
}

proc daphne_fullstream_resolve_config {script_dir} {
    array set cfg {}

    set cfg(script_dir) $script_dir
    set cfg(vivado_version) 2024.1
    set cfg(max_threads) [daphne_fullstream_get_env DAPHNE_MAX_THREADS 4]
    set cfg(output_dir) [daphne_fullstream_get_env DAPHNE_OUTPUT_DIR ./output]
    set cfg(fpga_part) [daphne_fullstream_get_env DAPHNE_FPGA_PART xck26-sfvc784-2LV-c]
    set cfg(board_part) [daphne_fullstream_get_env DAPHNE_BOARD_PART xilinx.com:k26c:part0:1.4]
    set cfg(target_language) VHDL
    set cfg(default_lib) work
    set cfg(synth_directive) [daphne_fullstream_get_env DAPHNE_SYNTH_DIRECTIVE PerformanceOptimized]
    set cfg(opt_directive) [daphne_fullstream_get_env DAPHNE_OPT_DIRECTIVE Explore]
    set cfg(place_directive) [daphne_fullstream_get_env DAPHNE_PLACE_DIRECTIVE WLDrivenBlockPlacement]
    set cfg(post_place_physopt_directive) [daphne_fullstream_get_env DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE AggressiveFanoutOpt]
    set cfg(route_directive) [daphne_fullstream_get_env DAPHNE_ROUTE_DIRECTIVE AlternateCLBRouting]
    set cfg(post_route_physopt_directive) [daphne_fullstream_get_env DAPHNE_POST_ROUTE_PHYSOPT_DIRECTIVE AggressiveExplore]
    set cfg(skip_post_synth_reports) [daphne_fullstream_get_env DAPHNE_SKIP_POST_SYNTH_REPORTS 0]
    set cfg(skip_post_synth_checkpoint) [daphne_fullstream_get_env DAPHNE_SKIP_POST_SYNTH_CHECKPOINT 0]

    set cfg(git_sha) [daphne_fullstream_resolve_git_sha]
    set cfg(v_git_sha) "28'h$cfg(git_sha)"
    set cfg(min_git_sha) [string range $cfg(git_sha) 0 0]
    set cfg(bd_git_sha) "4'h$cfg(min_git_sha)"
    set cfg(bd_name) daphne_fullstream_bd
    set cfg(bd_wrapper_name) "${cfg(bd_name)}_wrapper"
    set cfg(build_name) "daphne_fullstream_$cfg(git_sha)"
    set cfg(overlay_name) "daphne_fullstream_ol_$cfg(git_sha)"

    return [array get cfg]
}

proc daphne_fullstream_check_vivado_version {cfg_name} {
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

proc daphne_fullstream_prepare_project {cfg_name} {
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
    set_property TARGET_LANGUAGE $cfg(target_language) [current_project]
    set_property DEFAULT_LIB $cfg(default_lib) [current_project]

    puts "INFO: passing git commit number $cfg(v_git_sha) to top level generic"
}

proc daphne_fullstream_create_block_design {cfg_name} {
    upvar 1 $cfg_name cfg

    source -notrace [file join $cfg(script_dir) "daphne_fullstream_bd_gen.tcl"]
    read_bd [file join ".." "bd" $cfg(bd_name) "$cfg(bd_name).bd"]
    make_wrapper -top -files [get_files [file join ".." "bd" $cfg(bd_name) "$cfg(bd_name).bd"]]
    read_vhdl [file join ".." "bd" $cfg(bd_name) "hdl" "$cfg(bd_wrapper_name).vhd"]
    read_xdc -verbose [file join $cfg(script_dir) "daphne_fullstream_pin_map.xdc"]
    set_property synth_checkpoint_mode None [get_files [file join ".." "bd" $cfg(bd_name) "$cfg(bd_name).bd"]]
    generate_target all [get_files [file join ".." "bd" $cfg(bd_name) "$cfg(bd_name).bd"]]
}

proc daphne_fullstream_run_synth {cfg_name} {
    upvar 1 $cfg_name cfg

    synth_design -top $cfg(bd_wrapper_name) -directive $cfg(synth_directive)

    if {!$cfg(skip_post_synth_reports)} {
        report_clocks -file [file join $cfg(output_dir) clocks.rpt]
        report_timing_summary -file [file join $cfg(output_dir) post_synth_timing_summary.rpt]
        report_power -file [file join $cfg(output_dir) post_synth_power.rpt]
        report_utilization -file [file join $cfg(output_dir) post_synth_util.rpt]
    }

    if {!$cfg(skip_post_synth_checkpoint)} {
        write_checkpoint -force [file join $cfg(output_dir) "${cfg(build_name)}_synth.dcp"]
    }
}

proc daphne_fullstream_run_impl {cfg_name} {
    upvar 1 $cfg_name cfg

    opt_design -directive $cfg(opt_directive)
    place_design -directive $cfg(place_directive)
    phys_opt_design -directive $cfg(post_place_physopt_directive)
    report_timing_summary -file [file join $cfg(output_dir) post_place_timing_summary.rpt]
    report_timing -sort_by group -max_paths 100 -path_type summary -file [file join $cfg(output_dir) post_place_timing.rpt]

    route_design -directive $cfg(route_directive)
    phys_opt_design -directive $cfg(post_route_physopt_directive)
    write_checkpoint -force [file join $cfg(output_dir) "${cfg(build_name)}_post_route.dcp"]

    report_timing_summary -file [file join $cfg(output_dir) post_route_timing_summary.rpt]
    report_timing -sort_by group -max_paths 100 -path_type summary -file [file join $cfg(output_dir) post_route_timing.rpt]
    report_clock_utilization -file [file join $cfg(output_dir) clock_util.rpt]
    report_utilization -file [file join $cfg(output_dir) post_route_util.rpt]
    report_power -file [file join $cfg(output_dir) post_route_power.rpt]
    report_drc -file [file join $cfg(output_dir) post_imp_drc.rpt]
    report_io -file [file join $cfg(output_dir) io.rpt]
    write_checkpoint -force [file join $cfg(output_dir) "${cfg(build_name)}_post_impl.dcp"]
}

proc daphne_fullstream_write_bitstream_and_xsa {cfg_name} {
    upvar 1 $cfg_name cfg

    write_bitstream -force -bin_file [file join $cfg(output_dir) "${cfg(build_name)}.bit"]
    write_debug_probes -force [file join $cfg(output_dir) probes.ltx]
    write_hw_platform -fixed -force -include_bit -file [file join $cfg(output_dir) "${cfg(build_name)}.xsa"]
}

proc daphne_fullstream_package_overlay_linux {cfg_name} {
    upvar 1 $cfg_name cfg

    set overlay_dir [file join $cfg(output_dir) $cfg(overlay_name)]
    file mkdir $overlay_dir

    if {![info exists ::env(XILINX_VITIS)]} {
        error "ERROR: XILINX_VITIS is not set. Please source settings64.bat/.sh first."
    }

    set vitis_path $::env(XILINX_VITIS)
    puts "INFO: Found Vitis at $vitis_path."

    set xsct_exe [file join $vitis_path bin xsct]

    puts "INFO: Generating Device Tree files."
    if {[catch {exec $xsct_exe [file join $cfg(script_dir) "daphne_fullstream_dtbo_gen.tcl"] "[file join $cfg(output_dir) ${cfg(build_name)}.xsa]" $cfg(output_dir) $cfg(git_sha) 2>@1} result]} {
        error "ERROR: xsct command failed:\n$result"
    }
    puts "INFO: Device Tree files have been generated."

    set pl_dtsi_path [glob -nocomplain -types f "[file join $cfg(output_dir) $cfg(build_name)]/*/*/*/*/*/*/pl.dtsi"]
    puts "INFO: Adding missing lines for AXI Quad SPI module in the dtsi file."
    exec sed -i -f [file join $cfg(script_dir) scripts axi_quad_spi_dtbo_patch.sed] $pl_dtsi_path
    puts "INFO: Finished adding missing lines for dtsi file."

    puts "INFO: Compiling Device Tree."
    if {[catch {exec dtc -@ -O dtb -o [file join $cfg(output_dir) "${cfg(build_name)}.dtbo"] $pl_dtsi_path 2>@1} result]} {
        error "ERROR: dtc command failed:\n$result"
    }
    puts "INFO: Device Tree files have been compiled."

    puts "INFO: Creating json file."
    exec echo { { "shell_type" : "XRT_FLAT", "num_slots": "1" } } > [file join $cfg(output_dir) shell.json]
    puts "INFO: Json file has been generated."

    puts "INFO: Creating Overlay folder."
    file rename -force [file join $cfg(output_dir) "${cfg(build_name)}.dtbo"] [file join $overlay_dir "${cfg(overlay_name)}.dtbo"]
    file rename -force [file join $cfg(output_dir) "${cfg(build_name)}.bin"] [file join $overlay_dir "${cfg(overlay_name)}.bin"]
    file rename -force [file join $cfg(output_dir) shell.json] [file join $overlay_dir shell.json]

    set old_dir [pwd]
    cd $cfg(output_dir)
    exec zip -r "${cfg(overlay_name)}.zip" $cfg(overlay_name)
    cd $old_dir
    puts "INFO: Successfully generated Device Tree Overlay folder."
}

proc daphne_fullstream_export_dt_windows {cfg_name} {
    upvar 1 $cfg_name cfg

    if {![info exists ::env(XILINX_VITIS)]} {
        error "ERROR: XILINX_VITIS is not set. Please source settings64.bat/.sh first."
    }

    set vitis_path $::env(XILINX_VITIS)
    puts "INFO: Found Vitis at $vitis_path."
    set xsct_exe [file join $vitis_path bin xsct]

    puts "INFO: Generating Device Tree files."
    if {[catch {exec $xsct_exe -eval "hsi::open_hw_design [file join $cfg(output_dir) ${cfg(build_name)}.xsa]; createdts -hw [file join $cfg(output_dir) ${cfg(build_name)}.xsa] -zocl -platform-name $cfg(build_name) -git-branch xlnx_rel_v2022.2 -overlay -out [file join $cfg(output_dir) $cfg(build_name)]; exit" 2>@1} result]} {
        error "ERROR: xsct command failed:\n$result"
    }
    puts "INFO: Device Tree files have been generated."
    puts "INFO: Please make sure to edit .dtsi file with the proper lines for AXI Quad SPI Module, and run the dtc command to compile the design."
}

proc daphne_fullstream_run_post_build {cfg_name} {
    upvar 1 $cfg_name cfg

    if {$::tcl_platform(os) eq "Linux"} {
        puts "INFO: Running current TCL script on $::tcl_platform(os)."
        daphne_fullstream_package_overlay_linux cfg
    } elseif {$::tcl_platform(os) eq "Windows NT"} {
        puts "INFO: Running current TCL script on $::tcl_platform(os)."
        puts "WARNING: Device Tree Overlay can not be automatically produced on Windows."
        puts "WARNING: Please make sure to use the .xsa File to manually generate the necessary outputs."
        daphne_fullstream_export_dt_windows cfg
    } else {
        puts "WARNING: Unknown OS $::tcl_platform(os)."
    }
}

proc daphne_fullstream_run_full_build {script_dir} {
    array set cfg [daphne_fullstream_resolve_config $script_dir]
    daphne_fullstream_check_vivado_version cfg
    daphne_fullstream_prepare_project cfg
    daphne_fullstream_create_block_design cfg
    daphne_fullstream_run_synth cfg
    daphne_fullstream_run_impl cfg
    daphne_fullstream_write_bitstream_and_xsa cfg
    daphne_fullstream_run_post_build cfg
    puts "INFO: Finished design building."
    exit
}
