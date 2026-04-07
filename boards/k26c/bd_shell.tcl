# K26C-specific block-design shell helpers for the transitional DAPHNE build.

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

proc daphne_assign_board_support_addresses {} {
    assign_bd_address -offset 0x9C000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_iic_0/S_AXI/Reg] -force
    assign_bd_address -offset 0x9C010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
    assign_bd_address -offset 0x9C020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg] -force
}

proc daphne_apply_platform_metadata {pfm_name} {
    set_property PFM_NAME $pfm_name [get_files [current_bd_design].bd]
    set_property PFM.AXI_PORT {M_AXI_HPM1_FPD { memport "M_AXI_GP" sptag "" memory "" is_range "false" } S_AXI_HP0_FPD { memport "S_AXI_HP" sptag "HP0" memory "" is_range "false" } S_AXI_HP1_FPD { memport "S_AXI_HP" sptag "HP1" memory "" is_range "false" } S_AXI_HP2_FPD { memport "S_AXI_HP" sptag "HP2" memory "" is_range "false" } S_AXI_HP3_FPD { memport "S_AXI_HP" sptag "HP3" memory "" is_range "false" } S_AXI_HPC0_FPD { memport "S_AXI_HPC" sptag "HPC0" memory "" is_range "false" } S_AXI_HPC1_FPD { memport "S_AXI_HPC" sptag "HPC1" memory "" is_range "false" } S_AXI_LPD { memport "MIG" sptag "" memory "" is_range "false" } } [get_bd_cells /zynq_ultra_ps_e_0]
    set_property PFM.CLOCK {pl_clk0 {id "2" is_default "true" proc_sys_reset "/SYSTEM_RESET" status "fixed" freq_hz "99999001"}} [get_bd_cells /zynq_ultra_ps_e_0]
}
