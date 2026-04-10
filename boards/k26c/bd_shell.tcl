# K26C-specific block-design shell helpers for the transitional DAPHNE build.
#
# Optional future hooks:
# - daphne_connect_board_user_ip
# - daphne_assign_board_user_ip_addresses
#
# If a board defines those procedures, daphne_bd_gen.tcl will call them instead
# of the generic DAPHNE user-IP hookup/address defaults.

proc daphne_create_board_support_cells {} {
    set smartconnect_0 [create_bd_cell -vlnv xilinx.com:ip:smartconnect:1.0 -type IP smartconnect_0]
    set_property -dict [list \
        CONFIG.NUM_CLKS {2} \
        CONFIG.NUM_MI {12} \
        CONFIG.NUM_SI {2} \
    ] $smartconnect_0

    create_bd_cell -vlnv xilinx.com:ip:proc_sys_reset:5.0 -type IP SYSTEM_RESET
    create_bd_cell -vlnv xilinx.com:ip:proc_sys_reset:5.0 -type IP IIC_RESET
    create_bd_cell -vlnv xilinx.com:ip:axi_iic:2.1 -type IP axi_iic_0

    set axi_quad_spi_0 [create_bd_cell -vlnv xilinx.com:ip:axi_quad_spi:3.2 -type ip axi_quad_spi_0]
    set_property CONFIG.C_BYTE_LEVEL_INTERRUPT_EN {0} $axi_quad_spi_0

    set axi_intc_0 [create_bd_cell -vlnv xilinx.com:ip:axi_intc:4.1 -type IP axi_intc_0]
    set_property CONFIG.C_IRQ_CONNECTION {1} $axi_intc_0

    create_bd_cell -vlnv xilinx.com:ip:xlconcat:2.1 -type IP xlconcat_0
}

proc daphne_connect_board_support {block_cell_name} {
    connect_bd_intf_net -intf_net axi_iic_0_IIC [get_bd_intf_ports IIC_0] [get_bd_intf_pins axi_iic_0/IIC]
    connect_bd_intf_net -intf_net smartconnect_0_M01_AXI [get_bd_intf_pins smartconnect_0/M01_AXI] [get_bd_intf_pins axi_iic_0/S_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M04_AXI [get_bd_intf_pins smartconnect_0/M04_AXI] [get_bd_intf_pins axi_quad_spi_0/AXI_LITE]
    connect_bd_intf_net -intf_net smartconnect_0_M09_AXI [get_bd_intf_pins axi_intc_0/s_axi] [get_bd_intf_pins smartconnect_0/M09_AXI]
    connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins smartconnect_0/S01_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]
    connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_LPD [get_bd_intf_pins smartconnect_0/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD]

    connect_bd_net -net [daphne_bd_net_label $block_cell_name cm_csn] [get_bd_pins axi_quad_spi_0/ss_o] [get_bd_ports CM_CSn]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name cm_din] [get_bd_pins axi_quad_spi_0/io0_o] [get_bd_ports CM_DIN]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name cm_sclk] [get_bd_pins axi_quad_spi_0/sck_o] [get_bd_ports CM_SCLK]
    connect_bd_net -net IIC_RESET_peripheral_aresetn [get_bd_pins IIC_RESET/peripheral_aresetn] [get_bd_pins axi_iic_0/s_axi_aresetn]
    connect_bd_net -net axi_iic_0_iic2intc_irpt [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_0/In0]
    connect_bd_net -net axi_intc_0_irq [get_bd_pins axi_intc_0/irq] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
    connect_bd_net -net axi_quad_spi_0_ip2intc_irpt [get_bd_pins axi_quad_spi_0/ip2intc_irpt] [get_bd_pins xlconcat_0/In1]
    connect_bd_net -net cm_dout_0_1 [get_bd_ports CM_DOUT] [get_bd_pins axi_quad_spi_0/io1_i]
    connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins axi_intc_0/intr]
    connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins zynq_ultra_ps_e_0/pl_clk1] [get_bd_pins smartconnect_0/aclk1] [get_bd_pins IIC_RESET/slowest_sync_clk] [get_bd_pins axi_iic_0/s_axi_aclk] [get_bd_pins axi_quad_spi_0/ext_spi_clk]
    connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins SYSTEM_RESET/ext_reset_in]
    connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn1 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn1] [get_bd_pins IIC_RESET/ext_reset_in]
}

proc daphne_connect_board_user_ip {block_cell_name} {
    connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins smartconnect_0/M00_AXI] [daphne_bd_intf_pin $block_cell_name AFE_SPI_S_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M02_AXI [get_bd_intf_pins smartconnect_0/M02_AXI] [daphne_bd_intf_pin $block_cell_name END_P_S_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M03_AXI [get_bd_intf_pins smartconnect_0/M03_AXI] [daphne_bd_intf_pin $block_cell_name FRONT_END_S_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M05_AXI [get_bd_intf_pins smartconnect_0/M05_AXI] [daphne_bd_intf_pin $block_cell_name SPI_DAC_S_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M06_AXI [get_bd_intf_pins smartconnect_0/M06_AXI] [daphne_bd_intf_pin $block_cell_name SPY_BUF_S_S_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M07_AXI [get_bd_intf_pins smartconnect_0/M07_AXI] [daphne_bd_intf_pin $block_cell_name STUFF_S_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M08_AXI [get_bd_intf_pins smartconnect_0/M08_AXI] [daphne_bd_intf_pin $block_cell_name TRIRG_S_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M10_AXI [daphne_bd_intf_pin $block_cell_name OUTBUFF_S_AXI] [get_bd_intf_pins smartconnect_0/M10_AXI]
    connect_bd_intf_net -intf_net smartconnect_0_M11_AXI [daphne_bd_intf_pin $block_cell_name THRESH_S_AXI] [get_bd_intf_pins smartconnect_0/M11_AXI]

    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe0_mosi] [daphne_bd_pin $block_cell_name afe0_mosi] [get_bd_ports AFE0_SDATA]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe0_sclk] [daphne_bd_pin $block_cell_name afe0_sclk] [get_bd_ports AFE0_SCLK]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe12_mosi] [daphne_bd_pin $block_cell_name afe12_mosi] [get_bd_ports AFE12_SDATA]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe12_sclk] [daphne_bd_pin $block_cell_name afe12_sclk] [get_bd_ports AFE12_SCLK]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe34_mosi] [daphne_bd_pin $block_cell_name afe34_mosi] [get_bd_ports AFE34_SDATA]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe34_sclk] [daphne_bd_pin $block_cell_name afe34_sclk] [get_bd_ports AFE34_SCLK]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe_clk_n] [daphne_bd_pin $block_cell_name afe_clk_n] [get_bd_ports afe_clk_n]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe_clk_p] [daphne_bd_pin $block_cell_name afe_clk_p] [get_bd_ports afe_clk_p]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe_pdn] [daphne_bd_pin $block_cell_name afe_pdn] [get_bd_ports AFE_PD]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe_rst] [daphne_bd_pin $block_cell_name afe_rst] [get_bd_ports AFE_RST]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name afe_sen] [daphne_bd_pin $block_cell_name afe_sen] [get_bd_ports afe_sen]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name dac_din] [daphne_bd_pin $block_cell_name dac_din] [get_bd_ports DACS_MOSI]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name dac_ldac_n] [daphne_bd_pin $block_cell_name dac_ldac_n] [get_bd_ports DACS_LDACN]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name dac_sclk] [daphne_bd_pin $block_cell_name dac_sclk] [get_bd_ports DACS_SCLK]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name dac_sync_n] [daphne_bd_pin $block_cell_name dac_sync_n] [get_bd_ports DACS_CS]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name eth0_tx_dis] [daphne_bd_pin $block_cell_name eth0_tx_dis] [get_bd_ports SFP_GTH0_TX_DIS]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name eth0_tx_n] [daphne_bd_pin $block_cell_name eth0_tx_n] [get_bd_ports TX0_GTH_N]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name eth0_tx_p] [daphne_bd_pin $block_cell_name eth0_tx_p] [get_bd_ports TX0_GTH_P]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name fan_ctrl] [daphne_bd_pin $block_cell_name fan_ctrl] [get_bd_ports FAN_CONTROL]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name hvbias_en] [daphne_bd_pin $block_cell_name hvbias_en] [get_bd_ports VBIAS_EN]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name mux_a] [daphne_bd_pin $block_cell_name mux_a] [get_bd_ports MUXA]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name mux_en] [daphne_bd_pin $block_cell_name mux_en] [get_bd_ports MUX_EN]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name offset_ldac_n] [daphne_bd_pin $block_cell_name offset_ldac_n] [get_bd_ports offset_ldac_n]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name offset_sync_n] [daphne_bd_pin $block_cell_name offset_sync_n] [get_bd_ports offset_sync_n]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name sfp_tmg_tx_dis] [daphne_bd_pin $block_cell_name sfp_tmg_tx_dis] [get_bd_ports sfp_tmg_tx_dis]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name trim_ldac_n] [daphne_bd_pin $block_cell_name trim_ldac_n] [get_bd_ports trim_ldac_n]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name trim_sync_n] [daphne_bd_pin $block_cell_name trim_sync_n] [get_bd_ports trim_sync_n]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name tx0_tmg_n] [daphne_bd_pin $block_cell_name tx0_tmg_n] [get_bd_ports tx0_tmg_n]
    connect_bd_net -net [daphne_bd_net_label $block_cell_name tx0_tmg_p] [daphne_bd_pin $block_cell_name tx0_tmg_p] [get_bd_ports tx0_tmg_p]
    connect_bd_net -net Net1 [get_bd_pins SYSTEM_RESET/peripheral_aresetn] [get_bd_pins smartconnect_0/aresetn] [get_bd_pins axi_quad_spi_0/s_axi_aresetn] [get_bd_pins axi_intc_0/s_axi_aresetn] [daphne_bd_pin $block_cell_name FRONT_END_S_AXI_ARESETN] [daphne_bd_pin $block_cell_name SPY_BUF_S_S_AXI_ARESETN] [daphne_bd_pin $block_cell_name END_P_S_AXI_ARESETN] [daphne_bd_pin $block_cell_name SPI_DAC_S_AXI_ARESETN] [daphne_bd_pin $block_cell_name AFE_SPI_S_AXI_ARESETN] [daphne_bd_pin $block_cell_name TRIRG_S_AXI_ARESETN] [daphne_bd_pin $block_cell_name STUFF_S_AXI_ARESETN] [daphne_bd_pin $block_cell_name THRESH_S_AXI_ARESETN] [daphne_bd_pin $block_cell_name OUTBUFF_S_AXI_ARESETN]
    connect_bd_net -net afe0_miso_0_1 [get_bd_ports AFE0_MISO] [daphne_bd_pin $block_cell_name afe0_miso]
    connect_bd_net -net afe0_n_0_1 [get_bd_ports afe0_n] [daphne_bd_pin $block_cell_name afe0_n]
    connect_bd_net -net afe0_p_0_1 [get_bd_ports afe0_p] [daphne_bd_pin $block_cell_name afe0_p]
    connect_bd_net -net afe12_miso_0_1 [get_bd_ports AFE12_AFE_MISO] [daphne_bd_pin $block_cell_name afe12_miso]
    connect_bd_net -net afe1_n_0_1 [get_bd_ports afe1_n] [daphne_bd_pin $block_cell_name afe1_n]
    connect_bd_net -net afe1_p_0_1 [get_bd_ports afe1_p] [daphne_bd_pin $block_cell_name afe1_p]
    connect_bd_net -net afe2_n_0_1 [get_bd_ports afe2_n] [daphne_bd_pin $block_cell_name afe2_n]
    connect_bd_net -net afe2_p_0_1 [get_bd_ports afe2_p] [daphne_bd_pin $block_cell_name afe2_p]
    connect_bd_net -net afe34_miso_0_1 [get_bd_ports AFE34_AFE_MISO] [daphne_bd_pin $block_cell_name afe34_miso]
    connect_bd_net -net afe3_n_0_1 [get_bd_ports afe3_n] [daphne_bd_pin $block_cell_name afe3_n]
    connect_bd_net -net afe3_p_0_1 [get_bd_ports afe3_p] [daphne_bd_pin $block_cell_name afe3_p]
    connect_bd_net -net afe4_n_0_1 [get_bd_ports afe4_n] [daphne_bd_pin $block_cell_name afe4_n]
    connect_bd_net -net afe4_p_0_1 [get_bd_ports afe4_p] [daphne_bd_pin $block_cell_name afe4_p]
    connect_bd_net -net eth0_rx_n_0_1 [get_bd_ports RX0_GTH_N] [daphne_bd_pin $block_cell_name eth0_rx_n]
    connect_bd_net -net eth0_rx_p_0_1 [get_bd_ports RX0_GTH_P] [daphne_bd_pin $block_cell_name eth0_rx_p]
    connect_bd_net -net eth_clk_n_0_1 [get_bd_ports GTH0_REFCLK_N] [daphne_bd_pin $block_cell_name eth_clk_n]
    connect_bd_net -net eth_clk_p_0_1 [get_bd_ports GTH0_REFCLK_P] [daphne_bd_pin $block_cell_name eth_clk_p]
    connect_bd_net -net fan_tach_0_1 [get_bd_ports fan_tach] [daphne_bd_pin $block_cell_name fan_tach]
    connect_bd_net -net rx0_tmg_n_0_1 [get_bd_ports rx0_tmg_n] [daphne_bd_pin $block_cell_name rx0_tmg_n]
    connect_bd_net -net rx0_tmg_p_0_1 [get_bd_ports rx0_tmg_p] [daphne_bd_pin $block_cell_name rx0_tmg_p]
    connect_bd_net -net sfp_tmg_los_0_1 [get_bd_ports sfp_tmg_los] [daphne_bd_pin $block_cell_name sfp_tmg_los]
    connect_bd_net -net sysclk_n_0_1 [get_bd_ports sysclk_n] [daphne_bd_pin $block_cell_name sysclk_n]
    connect_bd_net -net sysclk_p_0_1 [get_bd_ports sysclk_p] [daphne_bd_pin $block_cell_name sysclk_p]
    connect_bd_net -net trig_IN_0_1 [get_bd_ports trig_IN] [daphne_bd_pin $block_cell_name trig_IN] [daphne_bd_pin $block_cell_name FORCE_TRIG]
    connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins SYSTEM_RESET/slowest_sync_clk] [get_bd_pins smartconnect_0/aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk] [get_bd_pins axi_quad_spi_0/s_axi_aclk] [get_bd_pins axi_intc_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [daphne_bd_pin $block_cell_name FRONT_END_S_AXI_ACLK] [daphne_bd_pin $block_cell_name SPY_BUF_S_S_AXI_ACLK] [daphne_bd_pin $block_cell_name END_P_S_AXI_ACLK] [daphne_bd_pin $block_cell_name SPI_DAC_S_AXI_ACLK] [daphne_bd_pin $block_cell_name AFE_SPI_S_AXI_ACLK] [daphne_bd_pin $block_cell_name TRIRG_S_AXI_ACLK] [daphne_bd_pin $block_cell_name STUFF_S_AXI_ACLK] [daphne_bd_pin $block_cell_name THRESH_S_AXI_ACLK] [daphne_bd_pin $block_cell_name OUTBUFF_S_AXI_ACLK]
    connect_bd_net -net zynq_ultra_ps_e_0_pl_clk3 [get_bd_pins zynq_ultra_ps_e_0/pl_clk3] [daphne_bd_pin $block_cell_name sysclk100]
}

proc daphne_assign_board_support_addresses {} {
    assign_bd_address -offset 0x9C000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_iic_0/S_AXI/Reg] -force
    assign_bd_address -offset 0x9C010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
    assign_bd_address -offset 0x9C020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg] -force
}

proc daphne_assign_board_user_ip_addresses {block_cell_name} {
    assign_bd_address -offset 0x80000000 -range 0x04000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name AFE_SPI_S_AXI/reg0] -force
    assign_bd_address -offset 0x84000000 -range 0x04000000 -with_name [daphne_bd_addr_seg_label $block_cell_name 1] -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name END_P_S_AXI/reg0] -force
    assign_bd_address -offset 0x88000000 -range 0x04000000 -with_name [daphne_bd_addr_seg_label $block_cell_name 2] -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name FRONT_END_S_AXI/reg0] -force
    assign_bd_address -offset 0xA0000000 -range 0x00010000 -with_name [daphne_bd_addr_seg_label $block_cell_name 3] -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name OUTBUFF_S_AXI/reg0] -force
    assign_bd_address -offset 0x8C000000 -range 0x04000000 -with_name [daphne_bd_addr_seg_label $block_cell_name 4] -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name SPI_DAC_S_AXI/reg0] -force
    assign_bd_address -offset 0x90000000 -range 0x04000000 -with_name [daphne_bd_addr_seg_label $block_cell_name 5] -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name SPY_BUF_S_S_AXI/reg0] -force
    assign_bd_address -offset 0x94000000 -range 0x04000000 -with_name [daphne_bd_addr_seg_label $block_cell_name 6] -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name STUFF_S_AXI/reg0] -force
    assign_bd_address -offset 0xA0010000 -range 0x00010000 -with_name [daphne_bd_addr_seg_label $block_cell_name 7] -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name THRESH_S_AXI/reg0] -force
    assign_bd_address -offset 0x98000000 -range 0x04000000 -with_name [daphne_bd_addr_seg_label $block_cell_name 8] -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [daphne_bd_addr_seg $block_cell_name TRIRG_S_AXI/reg0] -force
}

proc daphne_apply_platform_metadata {pfm_name} {
    set_property PFM_NAME $pfm_name [get_files [current_bd_design].bd]
    set_property PFM.AXI_PORT {M_AXI_HPM1_FPD { memport "M_AXI_GP" sptag "" memory "" is_range "false" } S_AXI_HP0_FPD { memport "S_AXI_HP" sptag "HP0" memory "" is_range "false" } S_AXI_HP1_FPD { memport "S_AXI_HP" sptag "HP1" memory "" is_range "false" } S_AXI_HP2_FPD { memport "S_AXI_HP" sptag "HP2" memory "" is_range "false" } S_AXI_HP3_FPD { memport "S_AXI_HP" sptag "HP3" memory "" is_range "false" } S_AXI_HPC0_FPD { memport "S_AXI_HPC" sptag "HPC0" memory "" is_range "false" } S_AXI_HPC1_FPD { memport "S_AXI_HPC" sptag "HPC1" memory "" is_range "false" } S_AXI_LPD { memport "MIG" sptag "" memory "" is_range "false" } } [get_bd_cells /zynq_ultra_ps_e_0]
    set_property PFM.CLOCK {pl_clk0 {id "2" is_default "true" proc_sys_reset "/SYSTEM_RESET" status "fixed" freq_hz "99999001"}} [get_bd_cells /zynq_ultra_ps_e_0]
}
