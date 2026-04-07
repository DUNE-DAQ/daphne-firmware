library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity legacy_public_top_bridge is
  generic (
    version     : std_logic_vector(27 downto 0) := X"1234567";
    link_id     : std_logic_vector(5 downto 0)  := "000000";
    slot_id     : std_logic_vector(3 downto 0)  := X"2";
    crate_id    : std_logic_vector(9 downto 0)  := "0000000011";
    detector_id : std_logic_vector(5 downto 0)  := "000010";
    version_id  : std_logic_vector(5 downto 0)  := "000001"
  );
  port (
    sysclk100 : in std_logic;
    sysclk_p  : in std_logic;
    sysclk_n  : in std_logic;
    fan_tach  : in std_logic_vector(1 downto 0);
    fan_ctrl  : out std_logic;
    stat_led  : out std_logic_vector(5 downto 0);
    hvbias_en : out std_logic;
    mux_en    : out std_logic_vector(1 downto 0);
    mux_a     : out std_logic_vector(1 downto 0);

    sfp_tmg_los    : in std_logic;
    rx0_tmg_p      : in std_logic;
    rx0_tmg_n      : in std_logic;
    sfp_tmg_tx_dis : out std_logic;
    tx0_tmg_p      : out std_logic;
    tx0_tmg_n      : out std_logic;

    afe0_p : in std_logic_vector(8 downto 0);
    afe0_n : in std_logic_vector(8 downto 0);
    afe1_p : in std_logic_vector(8 downto 0);
    afe1_n : in std_logic_vector(8 downto 0);
    afe2_p : in std_logic_vector(8 downto 0);
    afe2_n : in std_logic_vector(8 downto 0);
    afe3_p : in std_logic_vector(8 downto 0);
    afe3_n : in std_logic_vector(8 downto 0);
    afe4_p : in std_logic_vector(8 downto 0);
    afe4_n : in std_logic_vector(8 downto 0);

    afe_clk_p : out std_logic;
    afe_clk_n : out std_logic;

    dac_sclk   : out std_logic;
    dac_din    : out std_logic;
    dac_sync_n : out std_logic;
    dac_ldac_n : out std_logic;

    afe_rst : out std_logic;
    afe_pdn : out std_logic;

    afe0_miso : in std_logic;
    afe0_sclk : out std_logic;
    afe0_mosi : out std_logic;

    afe12_miso : in std_logic;
    afe12_sclk : out std_logic;
    afe12_mosi : out std_logic;

    afe34_miso : in std_logic;
    afe34_sclk : out std_logic;
    afe34_mosi : out std_logic;

    afe_sen       : out std_logic_vector(4 downto 0);
    trim_sync_n   : out std_logic_vector(4 downto 0);
    trim_ldac_n   : out std_logic_vector(4 downto 0);
    offset_sync_n : out std_logic_vector(4 downto 0);
    offset_ldac_n : out std_logic_vector(4 downto 0);

    trig_IN                 : in std_logic;
    FRONT_END_S_AXI_ACLK    : in std_logic;
    FRONT_END_S_AXI_ARESETN : in std_logic;
    FRONT_END_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    FRONT_END_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    FRONT_END_S_AXI_AWVALID : in std_logic;
    FRONT_END_S_AXI_AWREADY : out std_logic;
    FRONT_END_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    FRONT_END_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    FRONT_END_S_AXI_WVALID  : in std_logic;
    FRONT_END_S_AXI_WREADY  : out std_logic;
    FRONT_END_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    FRONT_END_S_AXI_BVALID  : out std_logic;
    FRONT_END_S_AXI_BREADY  : in std_logic;
    FRONT_END_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    FRONT_END_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    FRONT_END_S_AXI_ARVALID : in std_logic;
    FRONT_END_S_AXI_ARREADY : out std_logic;
    FRONT_END_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    FRONT_END_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    FRONT_END_S_AXI_RVALID  : out std_logic;
    FRONT_END_S_AXI_RREADY  : in std_logic;

    SPY_BUF_S_S_AXI_ACLK    : in std_logic;
    SPY_BUF_S_S_AXI_ARESETN : in std_logic;
    SPY_BUF_S_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    SPY_BUF_S_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    SPY_BUF_S_S_AXI_AWVALID : in std_logic;
    SPY_BUF_S_S_AXI_AWREADY : out std_logic;
    SPY_BUF_S_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    SPY_BUF_S_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    SPY_BUF_S_S_AXI_WVALID  : in std_logic;
    SPY_BUF_S_S_AXI_WREADY  : out std_logic;
    SPY_BUF_S_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    SPY_BUF_S_S_AXI_BVALID  : out std_logic;
    SPY_BUF_S_S_AXI_BREADY  : in std_logic;
    SPY_BUF_S_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    SPY_BUF_S_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    SPY_BUF_S_S_AXI_ARVALID : in std_logic;
    SPY_BUF_S_S_AXI_ARREADY : out std_logic;
    SPY_BUF_S_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    SPY_BUF_S_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    SPY_BUF_S_S_AXI_RVALID  : out std_logic;
    SPY_BUF_S_S_AXI_RREADY  : in std_logic;

    END_P_S_AXI_ACLK    : in std_logic;
    END_P_S_AXI_ARESETN : in std_logic;
    END_P_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    END_P_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    END_P_S_AXI_AWVALID : in std_logic;
    END_P_S_AXI_AWREADY : out std_logic;
    END_P_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    END_P_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    END_P_S_AXI_WVALID  : in std_logic;
    END_P_S_AXI_WREADY  : out std_logic;
    END_P_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    END_P_S_AXI_BVALID  : out std_logic;
    END_P_S_AXI_BREADY  : in std_logic;
    END_P_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    END_P_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    END_P_S_AXI_ARVALID : in std_logic;
    END_P_S_AXI_ARREADY : out std_logic;
    END_P_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    END_P_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    END_P_S_AXI_RVALID  : out std_logic;
    END_P_S_AXI_RREADY  : in std_logic;

    SPI_DAC_S_AXI_ACLK    : in std_logic;
    SPI_DAC_S_AXI_ARESETN : in std_logic;
    SPI_DAC_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    SPI_DAC_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    SPI_DAC_S_AXI_AWVALID : in std_logic;
    SPI_DAC_S_AXI_AWREADY : out std_logic;
    SPI_DAC_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    SPI_DAC_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    SPI_DAC_S_AXI_WVALID  : in std_logic;
    SPI_DAC_S_AXI_WREADY  : out std_logic;
    SPI_DAC_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    SPI_DAC_S_AXI_BVALID  : out std_logic;
    SPI_DAC_S_AXI_BREADY  : in std_logic;
    SPI_DAC_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    SPI_DAC_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    SPI_DAC_S_AXI_ARVALID : in std_logic;
    SPI_DAC_S_AXI_ARREADY : out std_logic;
    SPI_DAC_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    SPI_DAC_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    SPI_DAC_S_AXI_RVALID  : out std_logic;
    SPI_DAC_S_AXI_RREADY  : in std_logic;

    AFE_SPI_S_AXI_ACLK    : in std_logic;
    AFE_SPI_S_AXI_ARESETN : in std_logic;
    AFE_SPI_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    AFE_SPI_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    AFE_SPI_S_AXI_AWVALID : in std_logic;
    AFE_SPI_S_AXI_AWREADY : out std_logic;
    AFE_SPI_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    AFE_SPI_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    AFE_SPI_S_AXI_WVALID  : in std_logic;
    AFE_SPI_S_AXI_WREADY  : out std_logic;
    AFE_SPI_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    AFE_SPI_S_AXI_BVALID  : out std_logic;
    AFE_SPI_S_AXI_BREADY  : in std_logic;
    AFE_SPI_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    AFE_SPI_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    AFE_SPI_S_AXI_ARVALID : in std_logic;
    AFE_SPI_S_AXI_ARREADY : out std_logic;
    AFE_SPI_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    AFE_SPI_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    AFE_SPI_S_AXI_RVALID  : out std_logic;
    AFE_SPI_S_AXI_RREADY  : in std_logic;

    TRIRG_S_AXI_ACLK    : in std_logic;
    TRIRG_S_AXI_ARESETN : in std_logic;
    TRIRG_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    TRIRG_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    TRIRG_S_AXI_AWVALID : in std_logic;
    TRIRG_S_AXI_AWREADY : out std_logic;
    TRIRG_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    TRIRG_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    TRIRG_S_AXI_WVALID  : in std_logic;
    TRIRG_S_AXI_WREADY  : out std_logic;
    TRIRG_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    TRIRG_S_AXI_BVALID  : out std_logic;
    TRIRG_S_AXI_BREADY  : in std_logic;
    TRIRG_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    TRIRG_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    TRIRG_S_AXI_ARVALID : in std_logic;
    TRIRG_S_AXI_ARREADY : out std_logic;
    TRIRG_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    TRIRG_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    TRIRG_S_AXI_RVALID  : out std_logic;
    TRIRG_S_AXI_RREADY  : in std_logic;

    STUFF_S_AXI_ACLK    : in std_logic;
    STUFF_S_AXI_ARESETN : in std_logic;
    STUFF_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    STUFF_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    STUFF_S_AXI_AWVALID : in std_logic;
    STUFF_S_AXI_AWREADY : out std_logic;
    STUFF_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    STUFF_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    STUFF_S_AXI_WVALID  : in std_logic;
    STUFF_S_AXI_WREADY  : out std_logic;
    STUFF_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    STUFF_S_AXI_BVALID  : out std_logic;
    STUFF_S_AXI_BREADY  : in std_logic;
    STUFF_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    STUFF_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    STUFF_S_AXI_ARVALID : in std_logic;
    STUFF_S_AXI_ARREADY : out std_logic;
    STUFF_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    STUFF_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    STUFF_S_AXI_RVALID  : out std_logic;
    STUFF_S_AXI_RREADY  : in std_logic;

    THRESH_S_AXI_ACLK    : in std_logic;
    THRESH_S_AXI_ARESETN : in std_logic;
    THRESH_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    THRESH_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    THRESH_S_AXI_AWVALID : in std_logic;
    THRESH_S_AXI_AWREADY : out std_logic;
    THRESH_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    THRESH_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    THRESH_S_AXI_WVALID  : in std_logic;
    THRESH_S_AXI_WREADY  : out std_logic;
    THRESH_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    THRESH_S_AXI_BVALID  : out std_logic;
    THRESH_S_AXI_BREADY  : in std_logic;
    THRESH_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    THRESH_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    THRESH_S_AXI_ARVALID : in std_logic;
    THRESH_S_AXI_ARREADY : out std_logic;
    THRESH_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    THRESH_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    THRESH_S_AXI_RVALID  : out std_logic;
    THRESH_S_AXI_RREADY  : in std_logic;

    OUTBUFF_S_AXI_ACLK    : in std_logic;
    OUTBUFF_S_AXI_ARESETN : in std_logic;
    OUTBUFF_S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    OUTBUFF_S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    OUTBUFF_S_AXI_AWVALID : in std_logic;
    OUTBUFF_S_AXI_AWREADY : out std_logic;
    OUTBUFF_S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    OUTBUFF_S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    OUTBUFF_S_AXI_WVALID  : in std_logic;
    OUTBUFF_S_AXI_WREADY  : out std_logic;
    OUTBUFF_S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    OUTBUFF_S_AXI_BVALID  : out std_logic;
    OUTBUFF_S_AXI_BREADY  : in std_logic;
    OUTBUFF_S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    OUTBUFF_S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    OUTBUFF_S_AXI_ARVALID : in std_logic;
    OUTBUFF_S_AXI_ARREADY : out std_logic;
    OUTBUFF_S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    OUTBUFF_S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    OUTBUFF_S_AXI_RVALID  : out std_logic;
    OUTBUFF_S_AXI_RREADY  : in std_logic;

    eth_clk_p : in std_logic;
    eth_clk_n : in std_logic;

    eth0_rx_p : in std_logic_vector(0 downto 0);
    eth0_rx_n : in std_logic_vector(0 downto 0);
    eth0_tx_p : out std_logic_vector(0 downto 0);
    eth0_tx_n : out std_logic_vector(0 downto 0);
    eth0_tx_dis : out std_logic_vector(0 downto 0);

    out_buff_trig : out std_logic;
    out_buff_clk  : out std_logic;
    out_buff_data : out std_logic_vector(63 downto 0);

    FORCE_TRIG     : in std_logic;
    DIN_DEBUG      : out std_logic_vector(13 downto 0);
    VALID_DEBUG    : out std_logic;
    LAST_DEBUG     : out std_logic;
    clock_gen_debug : out std_logic;
    mmcm0_100MHZ_CLK_debug : out std_logic;
    ep_62p5MHZ_CLK_debug : out std_logic;
    F_OK_DEBUG : out std_logic;
    SCTR_DEBUG : out std_logic_vector(15 downto 0);
    CCTR_DEBUG : out std_logic_vector(15 downto 0);
    Trigered_debug : out std_logic
  );
end entity legacy_public_top_bridge;

architecture rtl of legacy_public_top_bridge is
  signal din_full_array          : array_5x9x16_type;
  signal trig                    : std_logic;
  signal timestamp               : std_logic_vector(63 downto 0);
  signal clock                   : std_logic;
  signal clk125                  : std_logic;
  signal clk500                  : std_logic;
  signal core_chan_enable        : std_logic_vector(39 downto 0);
  signal ti_trigger_reg          : std_logic_vector(7 downto 0);
  signal ti_trigger_stbr_reg     : std_logic;
  signal adhoc                   : std_logic_vector(7 downto 0);
  signal filter_output_selector  : std_logic_vector(1 downto 0);
  signal invert_enable           : std_logic_vector(39 downto 0);
  signal afe_comp_enable         : std_logic_vector(39 downto 0);
  signal st_config               : std_logic_vector(13 downto 0);
  signal signal_delay            : std_logic_vector(4 downto 0);
  signal reset_st_counters       : std_logic;
  signal din_debug_reg           : std_logic_vector(13 downto 0);
  signal out_buff_trig_s         : std_logic;
begin
  frontend_plane_inst : entity work.legacy_frontend_plane_bridge
    port map (
      afe0_p              => afe0_p,
      afe0_n              => afe0_n,
      afe1_p              => afe1_p,
      afe1_n              => afe1_n,
      afe2_p              => afe2_p,
      afe2_n              => afe2_n,
      afe3_p              => afe3_p,
      afe3_n              => afe3_n,
      afe4_p              => afe4_p,
      afe4_n              => afe4_n,
      afe_clk_p           => afe_clk_p,
      afe_clk_n           => afe_clk_n,
      clock_i             => clock,
      clk125_i            => clk125,
      clk500_i            => clk500,
      trig_in_i           => trig_IN,
      frontend_dout_o     => din_full_array,
      frontend_trigger_o  => trig,
      din_debug_o         => din_debug_reg,
      s_axi_aclk          => FRONT_END_S_AXI_ACLK,
      s_axi_aresetn       => FRONT_END_S_AXI_ARESETN,
      s_axi_awaddr        => FRONT_END_S_AXI_AWADDR,
      s_axi_awprot        => FRONT_END_S_AXI_AWPROT,
      s_axi_awvalid       => FRONT_END_S_AXI_AWVALID,
      s_axi_awready       => FRONT_END_S_AXI_AWREADY,
      s_axi_wdata         => FRONT_END_S_AXI_WDATA,
      s_axi_wstrb         => FRONT_END_S_AXI_WSTRB,
      s_axi_wvalid        => FRONT_END_S_AXI_WVALID,
      s_axi_wready        => FRONT_END_S_AXI_WREADY,
      s_axi_bresp         => FRONT_END_S_AXI_BRESP,
      s_axi_bvalid        => FRONT_END_S_AXI_BVALID,
      s_axi_bready        => FRONT_END_S_AXI_BREADY,
      s_axi_araddr        => FRONT_END_S_AXI_ARADDR,
      s_axi_arprot        => FRONT_END_S_AXI_ARPROT,
      s_axi_arvalid       => FRONT_END_S_AXI_ARVALID,
      s_axi_arready       => FRONT_END_S_AXI_ARREADY,
      s_axi_rdata         => FRONT_END_S_AXI_RDATA,
      s_axi_rresp         => FRONT_END_S_AXI_RRESP,
      s_axi_rvalid        => FRONT_END_S_AXI_RVALID,
      s_axi_rready        => FRONT_END_S_AXI_RREADY
    );

  spy_capture_bridge_inst : entity work.legacy_spy_capture_bridge
    port map (
      clock_i             => clock,
      reset_i             => '0',
      frontend_trigger_i  => trig,
      afe_dout_i          => din_full_array,
      timestamp_i         => timestamp,
      adhoc_i             => adhoc,
      ti_trigger_i        => ti_trigger_reg,
      ti_trigger_stbr_i   => ti_trigger_stbr_reg,
      s_axi_aclk          => SPY_BUF_S_S_AXI_ACLK,
      s_axi_aresetn       => SPY_BUF_S_S_AXI_ARESETN,
      s_axi_awaddr        => SPY_BUF_S_S_AXI_AWADDR,
      s_axi_awprot        => SPY_BUF_S_S_AXI_AWPROT,
      s_axi_awvalid       => SPY_BUF_S_S_AXI_AWVALID,
      s_axi_awready       => SPY_BUF_S_S_AXI_AWREADY,
      s_axi_wdata         => SPY_BUF_S_S_AXI_WDATA,
      s_axi_wstrb         => SPY_BUF_S_S_AXI_WSTRB,
      s_axi_wvalid        => SPY_BUF_S_S_AXI_WVALID,
      s_axi_wready        => SPY_BUF_S_S_AXI_WREADY,
      s_axi_bresp         => SPY_BUF_S_S_AXI_BRESP,
      s_axi_bvalid        => SPY_BUF_S_S_AXI_BVALID,
      s_axi_bready        => SPY_BUF_S_S_AXI_BREADY,
      s_axi_araddr        => SPY_BUF_S_S_AXI_ARADDR,
      s_axi_arprot        => SPY_BUF_S_S_AXI_ARPROT,
      s_axi_arvalid       => SPY_BUF_S_S_AXI_ARVALID,
      s_axi_arready       => SPY_BUF_S_S_AXI_ARREADY,
      s_axi_rdata         => SPY_BUF_S_S_AXI_RDATA,
      s_axi_rresp         => SPY_BUF_S_S_AXI_RRESP,
      s_axi_rvalid        => SPY_BUF_S_S_AXI_RVALID,
      s_axi_rready        => SPY_BUF_S_S_AXI_RREADY
    );

  timing_bridge_inst : entity work.legacy_timing_plane_bridge
    port map (
      sysclk_p                => sysclk_p,
      sysclk_n                => sysclk_n,
      sfp_tmg_los             => sfp_tmg_los,
      rx0_tmg_p               => rx0_tmg_p,
      rx0_tmg_n               => rx0_tmg_n,
      sfp_tmg_tx_dis          => sfp_tmg_tx_dis,
      tx0_tmg_p               => tx0_tmg_p,
      tx0_tmg_n               => tx0_tmg_n,
      clock_gen_debug         => clock_gen_debug,
      mmcm0_100mhz_clk_debug  => mmcm0_100MHZ_CLK_debug,
      ep_62p5mhz_clk_debug    => ep_62p5MHZ_CLK_debug,
      f_ok_debug              => F_OK_DEBUG,
      sctr_debug              => SCTR_DEBUG,
      cctr_debug              => CCTR_DEBUG,
      clock_o                 => clock,
      clk500_o                => clk500,
      clk125_o                => clk125,
      timestamp_o             => timestamp,
      sync_o                  => ti_trigger_reg,
      sync_stb_o              => ti_trigger_stbr_reg,
      timing_stat_o           => open,
      s_axi_aclk              => END_P_S_AXI_ACLK,
      s_axi_aresetn           => END_P_S_AXI_ARESETN,
      s_axi_awaddr            => END_P_S_AXI_AWADDR,
      s_axi_awprot            => END_P_S_AXI_AWPROT,
      s_axi_awvalid           => END_P_S_AXI_AWVALID,
      s_axi_awready           => END_P_S_AXI_AWREADY,
      s_axi_wdata             => END_P_S_AXI_WDATA,
      s_axi_wstrb             => END_P_S_AXI_WSTRB,
      s_axi_wvalid            => END_P_S_AXI_WVALID,
      s_axi_wready            => END_P_S_AXI_WREADY,
      s_axi_bresp             => END_P_S_AXI_BRESP,
      s_axi_bvalid            => END_P_S_AXI_BVALID,
      s_axi_bready            => END_P_S_AXI_BREADY,
      s_axi_araddr            => END_P_S_AXI_ARADDR,
      s_axi_arprot            => END_P_S_AXI_ARPROT,
      s_axi_arvalid           => END_P_S_AXI_ARVALID,
      s_axi_arready           => END_P_S_AXI_ARREADY,
      s_axi_rdata             => END_P_S_AXI_RDATA,
      s_axi_rresp             => END_P_S_AXI_RRESP,
      s_axi_rvalid            => END_P_S_AXI_RVALID,
      s_axi_rready            => END_P_S_AXI_RREADY
    );

  analog_control_plane_inst : entity work.legacy_analog_control_plane_bridge
    port map (
      fan_tach             => fan_tach,
      fan_ctrl             => fan_ctrl,
      hvbias_en            => hvbias_en,
      mux_en               => mux_en,
      mux_a                => mux_a,
      stat_led             => stat_led,
      version              => version,
      adhoc                => adhoc,
      core_chan_enable     => core_chan_enable,
      filter_output_selector => filter_output_selector,
      afe_comp_enable      => afe_comp_enable,
      invert_enable        => invert_enable,
      st_config            => st_config,
      signal_delay         => signal_delay,
      reset_st_counters    => reset_st_counters,
      dac_sclk             => dac_sclk,
      dac_din              => dac_din,
      dac_sync_n           => dac_sync_n,
      dac_ldac_n           => dac_ldac_n,
      afe_rst              => afe_rst,
      afe_pdn              => afe_pdn,
      afe0_miso            => afe0_miso,
      afe0_sclk            => afe0_sclk,
      afe0_mosi            => afe0_mosi,
      afe12_miso           => afe12_miso,
      afe12_sclk           => afe12_sclk,
      afe12_mosi           => afe12_mosi,
      afe34_miso           => afe34_miso,
      afe34_sclk           => afe34_sclk,
      afe34_mosi           => afe34_mosi,
      afe_sen              => afe_sen,
      trim_sync_n          => trim_sync_n,
      trim_ldac_n          => trim_ldac_n,
      offset_sync_n        => offset_sync_n,
      offset_ldac_n        => offset_ldac_n,
      afe_spi_s_axi_aclk   => AFE_SPI_S_AXI_ACLK,
      afe_spi_s_axi_aresetn => AFE_SPI_S_AXI_ARESETN,
      afe_spi_s_axi_awaddr => AFE_SPI_S_AXI_AWADDR,
      afe_spi_s_axi_awprot => AFE_SPI_S_AXI_AWPROT,
      afe_spi_s_axi_awvalid => AFE_SPI_S_AXI_AWVALID,
      afe_spi_s_axi_awready => AFE_SPI_S_AXI_AWREADY,
      afe_spi_s_axi_wdata  => AFE_SPI_S_AXI_WDATA,
      afe_spi_s_axi_wstrb  => AFE_SPI_S_AXI_WSTRB,
      afe_spi_s_axi_wvalid => AFE_SPI_S_AXI_WVALID,
      afe_spi_s_axi_wready => AFE_SPI_S_AXI_WREADY,
      afe_spi_s_axi_bresp  => AFE_SPI_S_AXI_BRESP,
      afe_spi_s_axi_bvalid => AFE_SPI_S_AXI_BVALID,
      afe_spi_s_axi_bready => AFE_SPI_S_AXI_BREADY,
      afe_spi_s_axi_araddr => AFE_SPI_S_AXI_ARADDR,
      afe_spi_s_axi_arprot => AFE_SPI_S_AXI_ARPROT,
      afe_spi_s_axi_arvalid => AFE_SPI_S_AXI_ARVALID,
      afe_spi_s_axi_arready => AFE_SPI_S_AXI_ARREADY,
      afe_spi_s_axi_rdata  => AFE_SPI_S_AXI_RDATA,
      afe_spi_s_axi_rresp  => AFE_SPI_S_AXI_RRESP,
      afe_spi_s_axi_rvalid => AFE_SPI_S_AXI_RVALID,
      afe_spi_s_axi_rready => AFE_SPI_S_AXI_RREADY,
      spi_dac_s_axi_aclk   => SPI_DAC_S_AXI_ACLK,
      spi_dac_s_axi_aresetn => SPI_DAC_S_AXI_ARESETN,
      spi_dac_s_axi_awaddr => SPI_DAC_S_AXI_AWADDR,
      spi_dac_s_axi_awprot => SPI_DAC_S_AXI_AWPROT,
      spi_dac_s_axi_awvalid => SPI_DAC_S_AXI_AWVALID,
      spi_dac_s_axi_awready => SPI_DAC_S_AXI_AWREADY,
      spi_dac_s_axi_wdata  => SPI_DAC_S_AXI_WDATA,
      spi_dac_s_axi_wstrb  => SPI_DAC_S_AXI_WSTRB,
      spi_dac_s_axi_wvalid => SPI_DAC_S_AXI_WVALID,
      spi_dac_s_axi_wready => SPI_DAC_S_AXI_WREADY,
      spi_dac_s_axi_bresp  => SPI_DAC_S_AXI_BRESP,
      spi_dac_s_axi_bvalid => SPI_DAC_S_AXI_BVALID,
      spi_dac_s_axi_bready => SPI_DAC_S_AXI_BREADY,
      spi_dac_s_axi_araddr => SPI_DAC_S_AXI_ARADDR,
      spi_dac_s_axi_arprot => SPI_DAC_S_AXI_ARPROT,
      spi_dac_s_axi_arvalid => SPI_DAC_S_AXI_ARVALID,
      spi_dac_s_axi_arready => SPI_DAC_S_AXI_ARREADY,
      spi_dac_s_axi_rdata  => SPI_DAC_S_AXI_RDATA,
      spi_dac_s_axi_rresp  => SPI_DAC_S_AXI_RRESP,
      spi_dac_s_axi_rvalid => SPI_DAC_S_AXI_RVALID,
      spi_dac_s_axi_rready => SPI_DAC_S_AXI_RREADY,
      stuff_s_axi_aclk     => STUFF_S_AXI_ACLK,
      stuff_s_axi_aresetn  => STUFF_S_AXI_ARESETN,
      stuff_s_axi_awaddr   => STUFF_S_AXI_AWADDR,
      stuff_s_axi_awprot   => STUFF_S_AXI_AWPROT,
      stuff_s_axi_awvalid  => STUFF_S_AXI_AWVALID,
      stuff_s_axi_awready  => STUFF_S_AXI_AWREADY,
      stuff_s_axi_wdata    => STUFF_S_AXI_WDATA,
      stuff_s_axi_wstrb    => STUFF_S_AXI_WSTRB,
      stuff_s_axi_wvalid   => STUFF_S_AXI_WVALID,
      stuff_s_axi_wready   => STUFF_S_AXI_WREADY,
      stuff_s_axi_bresp    => STUFF_S_AXI_BRESP,
      stuff_s_axi_bvalid   => STUFF_S_AXI_BVALID,
      stuff_s_axi_bready   => STUFF_S_AXI_BREADY,
      stuff_s_axi_araddr   => STUFF_S_AXI_ARADDR,
      stuff_s_axi_arprot   => STUFF_S_AXI_ARPROT,
      stuff_s_axi_arvalid  => STUFF_S_AXI_ARVALID,
      stuff_s_axi_arready  => STUFF_S_AXI_ARREADY,
      stuff_s_axi_rdata    => STUFF_S_AXI_RDATA,
      stuff_s_axi_rresp    => STUFF_S_AXI_RRESP,
      stuff_s_axi_rvalid   => STUFF_S_AXI_RVALID,
      stuff_s_axi_rready   => STUFF_S_AXI_RREADY
    );

  selftrigger_plane_inst : entity work.legacy_selftrigger_plane_bridge
    port map (
      link_id              => link_id,
      slot_id              => slot_id,
      crate_id             => crate_id,
      detector_id          => detector_id,
      version              => version_id,
      filter_output_selector => filter_output_selector,
      afe_comp_enable      => afe_comp_enable,
      invert_enable        => invert_enable,
      st_config            => st_config,
      signal_delay         => signal_delay,
      clock                => clock,
      reset                => '0',
      reset_st_counters    => reset_st_counters,
      timestamp            => timestamp,
      din_core             => din_full_array,
      enable               => core_chan_enable,
      forcetrig            => FORCE_TRIG,
      st_trigger_signal    => open,
      adhoc                => adhoc,
      ti_trigger           => ti_trigger_reg,
      ti_trigger_stbr      => ti_trigger_stbr_reg,
      trirg_s_axi_aclk     => TRIRG_S_AXI_ACLK,
      trirg_s_axi_aresetn  => TRIRG_S_AXI_ARESETN,
      trirg_s_axi_awaddr   => TRIRG_S_AXI_AWADDR,
      trirg_s_axi_awprot   => TRIRG_S_AXI_AWPROT,
      trirg_s_axi_awvalid  => TRIRG_S_AXI_AWVALID,
      trirg_s_axi_awready  => TRIRG_S_AXI_AWREADY,
      trirg_s_axi_wdata    => TRIRG_S_AXI_WDATA,
      trirg_s_axi_wstrb    => TRIRG_S_AXI_WSTRB,
      trirg_s_axi_wvalid   => TRIRG_S_AXI_WVALID,
      trirg_s_axi_wready   => TRIRG_S_AXI_WREADY,
      trirg_s_axi_bresp    => TRIRG_S_AXI_BRESP,
      trirg_s_axi_bvalid   => TRIRG_S_AXI_BVALID,
      trirg_s_axi_bready   => TRIRG_S_AXI_BREADY,
      trirg_s_axi_araddr   => TRIRG_S_AXI_ARADDR,
      trirg_s_axi_arprot   => TRIRG_S_AXI_ARPROT,
      trirg_s_axi_arvalid  => TRIRG_S_AXI_ARVALID,
      trirg_s_axi_arready  => TRIRG_S_AXI_ARREADY,
      trirg_s_axi_rdata    => TRIRG_S_AXI_RDATA,
      trirg_s_axi_rresp    => TRIRG_S_AXI_RRESP,
      trirg_s_axi_rvalid   => TRIRG_S_AXI_RVALID,
      trirg_s_axi_rready   => TRIRG_S_AXI_RREADY,
      thresh_s_axi_aclk    => THRESH_S_AXI_ACLK,
      thresh_s_axi_aresetn => THRESH_S_AXI_ARESETN,
      thresh_s_axi_awaddr  => THRESH_S_AXI_AWADDR,
      thresh_s_axi_awprot  => THRESH_S_AXI_AWPROT,
      thresh_s_axi_awvalid => THRESH_S_AXI_AWVALID,
      thresh_s_axi_awready => THRESH_S_AXI_AWREADY,
      thresh_s_axi_wdata   => THRESH_S_AXI_WDATA,
      thresh_s_axi_wstrb   => THRESH_S_AXI_WSTRB,
      thresh_s_axi_wvalid  => THRESH_S_AXI_WVALID,
      thresh_s_axi_wready  => THRESH_S_AXI_WREADY,
      thresh_s_axi_bresp   => THRESH_S_AXI_BRESP,
      thresh_s_axi_bvalid  => THRESH_S_AXI_BVALID,
      thresh_s_axi_bready  => THRESH_S_AXI_BREADY,
      thresh_s_axi_araddr  => THRESH_S_AXI_ARADDR,
      thresh_s_axi_arprot  => THRESH_S_AXI_ARPROT,
      thresh_s_axi_arvalid => THRESH_S_AXI_ARVALID,
      thresh_s_axi_arready => THRESH_S_AXI_ARREADY,
      thresh_s_axi_rdata   => THRESH_S_AXI_RDATA,
      thresh_s_axi_rresp   => THRESH_S_AXI_RRESP,
      thresh_s_axi_rvalid  => THRESH_S_AXI_RVALID,
      thresh_s_axi_rready  => THRESH_S_AXI_RREADY,
      outbuff_s_axi_aclk   => OUTBUFF_S_AXI_ACLK,
      outbuff_s_axi_aresetn => OUTBUFF_S_AXI_ARESETN,
      outbuff_s_axi_awaddr => OUTBUFF_S_AXI_AWADDR,
      outbuff_s_axi_awprot => OUTBUFF_S_AXI_AWPROT,
      outbuff_s_axi_awvalid => OUTBUFF_S_AXI_AWVALID,
      outbuff_s_axi_awready => OUTBUFF_S_AXI_AWREADY,
      outbuff_s_axi_wdata  => OUTBUFF_S_AXI_WDATA,
      outbuff_s_axi_wstrb  => OUTBUFF_S_AXI_WSTRB,
      outbuff_s_axi_wvalid => OUTBUFF_S_AXI_WVALID,
      outbuff_s_axi_wready => OUTBUFF_S_AXI_WREADY,
      outbuff_s_axi_bresp  => OUTBUFF_S_AXI_BRESP,
      outbuff_s_axi_bvalid => OUTBUFF_S_AXI_BVALID,
      outbuff_s_axi_bready => OUTBUFF_S_AXI_BREADY,
      outbuff_s_axi_araddr => OUTBUFF_S_AXI_ARADDR,
      outbuff_s_axi_arprot => OUTBUFF_S_AXI_ARPROT,
      outbuff_s_axi_arvalid => OUTBUFF_S_AXI_ARVALID,
      outbuff_s_axi_arready => OUTBUFF_S_AXI_ARREADY,
      outbuff_s_axi_rdata  => OUTBUFF_S_AXI_RDATA,
      outbuff_s_axi_rresp  => OUTBUFF_S_AXI_RRESP,
      outbuff_s_axi_rvalid => OUTBUFF_S_AXI_RVALID,
      outbuff_s_axi_rready => OUTBUFF_S_AXI_RREADY,
      eth_clk_p            => eth_clk_p,
      eth_clk_n            => eth_clk_n,
      eth0_rx_p            => eth0_rx_p,
      eth0_rx_n            => eth0_rx_n,
      eth0_tx_p            => eth0_tx_p,
      eth0_tx_n            => eth0_tx_n,
      eth0_tx_dis          => eth0_tx_dis,
      out_buff_data        => out_buff_data,
      out_buff_trig        => out_buff_trig_s,
      valid_debug          => VALID_DEBUG,
      last_debug           => LAST_DEBUG
    );

  DIN_DEBUG    <= din_debug_reg;
  out_buff_trig <= out_buff_trig_s;
  out_buff_clk <= clock;
  Trigered_debug <= out_buff_trig_s;
end architecture rtl;
