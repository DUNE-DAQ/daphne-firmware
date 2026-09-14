# Apply after synth_design, after all generated/scoped XXV IP XDC files.
# The one-channel XXV IP is reused four times; its generated LOC=X0Y4 must
# therefore be replaced per instance. One shared COMMON serves all four lanes.
#
# K26 sfvc784 package mapping, verified against Vivado 2026.1
# data/parts/xilinx/zynquplus/public/bsdl/xck26_sfvc784.bsd:985-1004:
# quad 224 channels 0/1/2/3 RX P=Y2/V2/T2/P2, TX P=W4/U4/R4/N4.
# Board SFP 2 and SFP 3 connect to quad channels 3 and 2 respectively.
proc daphne_apply_four_sfp_gt_locations {} {
    set port_count 0
    foreach sfp {0 1 2 3} {
        incr port_count [llength [get_ports -quiet [format {TX%d_GTH_P*} $sfp]]]
    }
    # Other board profiles can still provide the historical single-link shell.
    if {$port_count <= 1} { return }
    if {$port_count != 4} { error "Expected four DAQ SFP TX ports, found $port_count" }

    set sites [dict create 0 GTHE4_CHANNEL_X0Y4 1 GTHE4_CHANNEL_X0Y5 \
                          2 GTHE4_CHANNEL_X0Y7 3 GTHE4_CHANNEL_X0Y6]
    set rx_pins [dict create 0 Y2 1 V2 2 P2 3 T2]
    set tx_pins [dict create 0 W4 1 U4 2 N4 3 R4]
    set channels [get_cells -hierarchical -filter {REF_NAME == GTHE4_CHANNEL}]
    if {[llength $channels] != 4} {
        error "Expected four synthesized GTHE4_CHANNEL primitives, found [llength $channels]"
    }
    set seen {}
    foreach channel $channels {
        set name [get_property NAME $channel]
        if {![regexp {(^|/)phy_gen\[([0-3])\]\.phy_10gbe/} $name unused prefix sfp]} {
            error "Cannot identify Hermes SFP index for GT primitive $name"
        }
        if {[dict exists $seen $sfp]} { error "Multiple GT primitives for SFP$sfp" }
        dict set seen $sfp 1
        foreach direction {RX TX} pins [list $rx_pins $tx_pins] {
            set ports [get_ports -quiet [format {%s%d_GTH_P*} $direction $sfp]]
            if {[llength $ports] != 1 || [get_property PACKAGE_PIN $ports] ne [dict get $pins $sfp]} {
                error "SFP$sfp $direction pin constraint does not match the K26 channel mapping"
            }
        }
        set site [dict get $sites $sfp]
        set_property LOC $site $channel
        puts "INFO: SFP$sfp uses $site ($name)."
    }
    set common [get_cells -hierarchical -filter {REF_NAME == GTHE4_COMMON}]
    if {[llength $common] != 1} {
        error "Expected one shared GTHE4_COMMON primitive, found [llength $common]"
    }
    set_property LOC GTHE4_COMMON_X0Y1 $common
    puts "INFO: Four DAQ SFP links share GTHE4_COMMON_X0Y1 and the 156.25 MHz reference on Y6/Y5."
}
daphne_apply_four_sfp_gt_locations
