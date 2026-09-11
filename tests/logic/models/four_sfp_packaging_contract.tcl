# Execute the real packager through port inference, recording its file groups.
# Vivado API calls are interface fixtures; filesystem staging and source-list
# selection run unchanged. This does not model Vivado IP generation or routing.
set root [lindex $argv 0]
set stage [lindex $argv 1]
set ports [lindex $argv 2]
set ::env(DAPHNE_IP_REPO_ROOT) $stage
set ::env(DAPHNE_ETH_MODE) create_ip
set ::env(DAPHNE_BOARD) k26c
rename source tcl_source
proc source {args} {uplevel 1 [list tcl_source [lindex $args end]]}
proc set_part {args} {}
proc current_project {} {return project}
proc current_fileset {} {return fileset}
proc set_property {key value object} {
    if {$key eq "MODEL_NAME"} {dict set ::models $object $value}
}
proc get_ipdefs {args} {return [string map {* 1.0} [lindex $args end]]}
proc get_ips {args} {return [lindex $args end]}
proc generate_target {args} {}
proc create_ip {args} {
    set name [lindex $args [expr {[lsearch $args -module_name] + 1}]]
    set directory [lindex $args [expr {[lsearch $args -dir] + 1}]]
    file mkdir [file join $directory $name]
    close [open [file join $directory $name ${name}.xci] w]
    return $name
}
namespace eval ipx {
    proc create_core {args} {return core}
    proc add_file_group {name args} {return $name}
    proc add_subcore {args} {return subcore}
    proc get_file_groups {name args} {return $name}
    proc get_files {args} {return file_object}
    proc update_checksums {args} {}
    proc add_file {args} {
        set path [lindex $args [expr {[lsearch $args -name] + 1}]]
        set group [lindex $args [expr {[lsearch $args -file_group] + 1}]]
        dict lappend ::files $group $path
        return $path
    }
    proc add_ports_from_hdl {args} {
        set ::selected_top [lindex $args [expr {[lsearch $args -top_level_hdl_file] + 1}]]
        return $::ports
    }
    proc get_ports {name args} {
        if {$name in $::ports} {return $name}
        return {}
    }
    proc add_model_parameters_from_hdl {args} {error CONTRACT_PORTS_COMPLETE}
}
set result [catch {source [file join $root xilinx daphne_ip_gen.tcl]} message options]
if {!$result || $message ne "CONTRACT_PORTS_COMPLETE"} {
    puts stderr "Actual packager fixture failed: $message"
    exit 1
}
set manifest [open [file join $stage packaging-files.tsv] w]
foreach group {xilinx_anylanguagesynthesis xilinx_anylanguagebehavioralsimulation} {
    puts $manifest "MODEL\t$group\t[dict get $models $group]"
    foreach path [dict get $files $group] {puts $manifest "FILE\t$group\t$path"}
}
puts $manifest "TOP\tselected\t$selected_top"
close $manifest

# Load the actual BD pin helpers (the prefix ends immediately before the
# remainder of the Vivado-dependent block-design creation body).
set handle [open [file join $root xilinx daphne_bd_gen.tcl] r]
set bd [read $handle]
close $handle
set start [string first {proc daphne_bd_pin } $bd]
set end [string first {proc daphne_connect_default_user_ip } $bd]
if {$start < 0 || $end <= $start} {error "Cannot locate BD helper procedures"}
eval [string range $bd $start [expr {$end - 1}]]
proc get_bd_pins {args} {
    set name [lindex $args end]
    if {[string match "user/eth*" $name] && [file tail $name] ni $::ports} {return {}}
    return $name
}
proc get_bd_intf_pins {name} {return $name}
proc get_bd_intf_ports {name} {return $name}
proc get_bd_ports {name} {return $name}
proc connect_bd_intf_net {args} {}
proc connect_bd_net {args} {
    foreach name $args {
        if {[regexp {^user/(eth[0-3]_(?:rx_[pn]|tx_[pn]|tx_dis))$} $name -> pin]} {
            dict lappend ::connections $pin $args
        }
    }
}
source [file join $root boards k26c bd_shell.tcl]
daphne_connect_board_user_ip user
foreach sfp {0 1 2 3} {
    foreach {suffix external} {rx_p RX%d_GTH_P rx_n RX%d_GTH_N tx_p TX%d_GTH_P tx_n TX%d_GTH_N tx_dis SFP_GTH%d_TX_DIS} {
        set pin eth${sfp}_${suffix}
        set expected [format $external $sfp]
        if {![dict exists $connections $pin] || [llength [dict get $connections $pin]] != 1} {
            error "Missing or duplicate board hookup for $pin"
        }
        if {$expected ni [lindex [dict get $connections $pin] 0]} {error "Wrong SFP mapping for $pin"}
    }
}
# Missing package metadata must fail admission to BD construction, rather than
# leaving a one-ended net that validate_bd_design can silently tie off.
set ports [lsearch -all -inline -not -exact $ports eth3_rx_p]
if {![catch {daphne_bd_pin user eth3_rx_p} message] || ![string match "*required user-IP pin*" $message]} {
    error "Missing SFP pin did not fail explicitly"
}
puts "PASS actual board hook: all 20 SFP connections and missing-pin rejection"
