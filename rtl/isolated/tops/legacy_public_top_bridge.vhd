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
begin
  k26c_board_shell_inst : entity work.k26c_board_shell
    generic map (
      version     => version,
      link_id     => link_id,
      slot_id     => slot_id,
      crate_id    => crate_id,
      detector_id => detector_id,
      version_id  => version_id
    )
    port map (
      sysclk100               => sysclk100,
      sysclk_p                => sysclk_p,
      sysclk_n                => sysclk_n,
      fan_tach                => fan_tach,
      fan_ctrl                => fan_ctrl,
      stat_led                => stat_led,
      hvbias_en               => hvbias_en,
      mux_en                  => mux_en,
      mux_a                   => mux_a,
      sfp_tmg_los             => sfp_tmg_los,
      rx0_tmg_p               => rx0_tmg_p,
      rx0_tmg_n               => rx0_tmg_n,
      sfp_tmg_tx_dis          => sfp_tmg_tx_dis,
      tx0_tmg_p               => tx0_tmg_p,
      tx0_tmg_n               => tx0_tmg_n,
      afe0_p                  => afe0_p,
      afe0_n                  => afe0_n,
      afe1_p                  => afe1_p,
      afe1_n                  => afe1_n,
      afe2_p                  => afe2_p,
      afe2_n                  => afe2_n,
      afe3_p                  => afe3_p,
      afe3_n                  => afe3_n,
      afe4_p                  => afe4_p,
      afe4_n                  => afe4_n,
      afe_clk_p               => afe_clk_p,
      afe_clk_n               => afe_clk_n,
      dac_sclk                => dac_sclk,
      dac_din                 => dac_din,
      dac_sync_n              => dac_sync_n,
      dac_ldac_n              => dac_ldac_n,
      afe_rst                 => afe_rst,
      afe_pdn                 => afe_pdn,
      afe0_miso               => afe0_miso,
      afe0_sclk               => afe0_sclk,
      afe0_mosi               => afe0_mosi,
      afe12_miso              => afe12_miso,
      afe12_sclk              => afe12_sclk,
      afe12_mosi              => afe12_mosi,
      afe34_miso              => afe34_miso,
      afe34_sclk              => afe34_sclk,
      afe34_mosi              => afe34_mosi,
      afe_sen                 => afe_sen,
      trim_sync_n             => trim_sync_n,
      trim_ldac_n             => trim_ldac_n,
      offset_sync_n           => offset_sync_n,
      offset_ldac_n           => offset_ldac_n,
      trig_IN                 => trig_IN,
      FRONT_END_S_AXI_ACLK    => FRONT_END_S_AXI_ACLK,
      FRONT_END_S_AXI_ARESETN => FRONT_END_S_AXI_ARESETN,
      FRONT_END_S_AXI_AWADDR  => FRONT_END_S_AXI_AWADDR,
      FRONT_END_S_AXI_AWPROT  => FRONT_END_S_AXI_AWPROT,
      FRONT_END_S_AXI_AWVALID => FRONT_END_S_AXI_AWVALID,
      FRONT_END_S_AXI_AWREADY => FRONT_END_S_AXI_AWREADY,
      FRONT_END_S_AXI_WDATA   => FRONT_END_S_AXI_WDATA,
      FRONT_END_S_AXI_WSTRB   => FRONT_END_S_AXI_WSTRB,
      FRONT_END_S_AXI_WVALID  => FRONT_END_S_AXI_WVALID,
      FRONT_END_S_AXI_WREADY  => FRONT_END_S_AXI_WREADY,
      FRONT_END_S_AXI_BRESP   => FRONT_END_S_AXI_BRESP,
      FRONT_END_S_AXI_BVALID  => FRONT_END_S_AXI_BVALID,
      FRONT_END_S_AXI_BREADY  => FRONT_END_S_AXI_BREADY,
      FRONT_END_S_AXI_ARADDR  => FRONT_END_S_AXI_ARADDR,
      FRONT_END_S_AXI_ARPROT  => FRONT_END_S_AXI_ARPROT,
      FRONT_END_S_AXI_ARVALID => FRONT_END_S_AXI_ARVALID,
      FRONT_END_S_AXI_ARREADY => FRONT_END_S_AXI_ARREADY,
      FRONT_END_S_AXI_RDATA   => FRONT_END_S_AXI_RDATA,
      FRONT_END_S_AXI_RRESP   => FRONT_END_S_AXI_RRESP,
      FRONT_END_S_AXI_RVALID  => FRONT_END_S_AXI_RVALID,
      FRONT_END_S_AXI_RREADY  => FRONT_END_S_AXI_RREADY,
      SPY_BUF_S_S_AXI_ACLK    => SPY_BUF_S_S_AXI_ACLK,
      SPY_BUF_S_S_AXI_ARESETN => SPY_BUF_S_S_AXI_ARESETN,
      SPY_BUF_S_S_AXI_AWADDR  => SPY_BUF_S_S_AXI_AWADDR,
      SPY_BUF_S_S_AXI_AWPROT  => SPY_BUF_S_S_AXI_AWPROT,
      SPY_BUF_S_S_AXI_AWVALID => SPY_BUF_S_S_AXI_AWVALID,
      SPY_BUF_S_S_AXI_AWREADY => SPY_BUF_S_S_AXI_AWREADY,
      SPY_BUF_S_S_AXI_WDATA   => SPY_BUF_S_S_AXI_WDATA,
      SPY_BUF_S_S_AXI_WSTRB   => SPY_BUF_S_S_AXI_WSTRB,
      SPY_BUF_S_S_AXI_WVALID  => SPY_BUF_S_S_AXI_WVALID,
      SPY_BUF_S_S_AXI_WREADY  => SPY_BUF_S_S_AXI_WREADY,
      SPY_BUF_S_S_AXI_BRESP   => SPY_BUF_S_S_AXI_BRESP,
      SPY_BUF_S_S_AXI_BVALID  => SPY_BUF_S_S_AXI_BVALID,
      SPY_BUF_S_S_AXI_BREADY  => SPY_BUF_S_S_AXI_BREADY,
      SPY_BUF_S_S_AXI_ARADDR  => SPY_BUF_S_S_AXI_ARADDR,
      SPY_BUF_S_S_AXI_ARPROT  => SPY_BUF_S_S_AXI_ARPROT,
      SPY_BUF_S_S_AXI_ARVALID => SPY_BUF_S_S_AXI_ARVALID,
      SPY_BUF_S_S_AXI_ARREADY => SPY_BUF_S_S_AXI_ARREADY,
      SPY_BUF_S_S_AXI_RDATA   => SPY_BUF_S_S_AXI_RDATA,
      SPY_BUF_S_S_AXI_RRESP   => SPY_BUF_S_S_AXI_RRESP,
      SPY_BUF_S_S_AXI_RVALID  => SPY_BUF_S_S_AXI_RVALID,
      SPY_BUF_S_S_AXI_RREADY  => SPY_BUF_S_S_AXI_RREADY,
      END_P_S_AXI_ACLK        => END_P_S_AXI_ACLK,
      END_P_S_AXI_ARESETN     => END_P_S_AXI_ARESETN,
      END_P_S_AXI_AWADDR      => END_P_S_AXI_AWADDR,
      END_P_S_AXI_AWPROT      => END_P_S_AXI_AWPROT,
      END_P_S_AXI_AWVALID     => END_P_S_AXI_AWVALID,
      END_P_S_AXI_AWREADY     => END_P_S_AXI_AWREADY,
      END_P_S_AXI_WDATA       => END_P_S_AXI_WDATA,
      END_P_S_AXI_WSTRB       => END_P_S_AXI_WSTRB,
      END_P_S_AXI_WVALID      => END_P_S_AXI_WVALID,
      END_P_S_AXI_WREADY      => END_P_S_AXI_WREADY,
      END_P_S_AXI_BRESP       => END_P_S_AXI_BRESP,
      END_P_S_AXI_BVALID      => END_P_S_AXI_BVALID,
      END_P_S_AXI_BREADY      => END_P_S_AXI_BREADY,
      END_P_S_AXI_ARADDR      => END_P_S_AXI_ARADDR,
      END_P_S_AXI_ARPROT      => END_P_S_AXI_ARPROT,
      END_P_S_AXI_ARVALID     => END_P_S_AXI_ARVALID,
      END_P_S_AXI_ARREADY     => END_P_S_AXI_ARREADY,
      END_P_S_AXI_RDATA       => END_P_S_AXI_RDATA,
      END_P_S_AXI_RRESP       => END_P_S_AXI_RRESP,
      END_P_S_AXI_RVALID      => END_P_S_AXI_RVALID,
      END_P_S_AXI_RREADY      => END_P_S_AXI_RREADY,
      SPI_DAC_S_AXI_ACLK      => SPI_DAC_S_AXI_ACLK,
      SPI_DAC_S_AXI_ARESETN   => SPI_DAC_S_AXI_ARESETN,
      SPI_DAC_S_AXI_AWADDR    => SPI_DAC_S_AXI_AWADDR,
      SPI_DAC_S_AXI_AWPROT    => SPI_DAC_S_AXI_AWPROT,
      SPI_DAC_S_AXI_AWVALID   => SPI_DAC_S_AXI_AWVALID,
      SPI_DAC_S_AXI_AWREADY   => SPI_DAC_S_AXI_AWREADY,
      SPI_DAC_S_AXI_WDATA     => SPI_DAC_S_AXI_WDATA,
      SPI_DAC_S_AXI_WSTRB     => SPI_DAC_S_AXI_WSTRB,
      SPI_DAC_S_AXI_WVALID    => SPI_DAC_S_AXI_WVALID,
      SPI_DAC_S_AXI_WREADY    => SPI_DAC_S_AXI_WREADY,
      SPI_DAC_S_AXI_BRESP     => SPI_DAC_S_AXI_BRESP,
      SPI_DAC_S_AXI_BVALID    => SPI_DAC_S_AXI_BVALID,
      SPI_DAC_S_AXI_BREADY    => SPI_DAC_S_AXI_BREADY,
      SPI_DAC_S_AXI_ARADDR    => SPI_DAC_S_AXI_ARADDR,
      SPI_DAC_S_AXI_ARPROT    => SPI_DAC_S_AXI_ARPROT,
      SPI_DAC_S_AXI_ARVALID   => SPI_DAC_S_AXI_ARVALID,
      SPI_DAC_S_AXI_ARREADY   => SPI_DAC_S_AXI_ARREADY,
      SPI_DAC_S_AXI_RDATA     => SPI_DAC_S_AXI_RDATA,
      SPI_DAC_S_AXI_RRESP     => SPI_DAC_S_AXI_RRESP,
      SPI_DAC_S_AXI_RVALID    => SPI_DAC_S_AXI_RVALID,
      SPI_DAC_S_AXI_RREADY    => SPI_DAC_S_AXI_RREADY,
      AFE_SPI_S_AXI_ACLK      => AFE_SPI_S_AXI_ACLK,
      AFE_SPI_S_AXI_ARESETN   => AFE_SPI_S_AXI_ARESETN,
      AFE_SPI_S_AXI_AWADDR    => AFE_SPI_S_AXI_AWADDR,
      AFE_SPI_S_AXI_AWPROT    => AFE_SPI_S_AXI_AWPROT,
      AFE_SPI_S_AXI_AWVALID   => AFE_SPI_S_AXI_AWVALID,
      AFE_SPI_S_AXI_AWREADY   => AFE_SPI_S_AXI_AWREADY,
      AFE_SPI_S_AXI_WDATA     => AFE_SPI_S_AXI_WDATA,
      AFE_SPI_S_AXI_WSTRB     => AFE_SPI_S_AXI_WSTRB,
      AFE_SPI_S_AXI_WVALID    => AFE_SPI_S_AXI_WVALID,
      AFE_SPI_S_AXI_WREADY    => AFE_SPI_S_AXI_WREADY,
      AFE_SPI_S_AXI_BRESP     => AFE_SPI_S_AXI_BRESP,
      AFE_SPI_S_AXI_BVALID    => AFE_SPI_S_AXI_BVALID,
      AFE_SPI_S_AXI_BREADY    => AFE_SPI_S_AXI_BREADY,
      AFE_SPI_S_AXI_ARADDR    => AFE_SPI_S_AXI_ARADDR,
      AFE_SPI_S_AXI_ARPROT    => AFE_SPI_S_AXI_ARPROT,
      AFE_SPI_S_AXI_ARVALID   => AFE_SPI_S_AXI_ARVALID,
      AFE_SPI_S_AXI_ARREADY   => AFE_SPI_S_AXI_ARREADY,
      AFE_SPI_S_AXI_RDATA     => AFE_SPI_S_AXI_RDATA,
      AFE_SPI_S_AXI_RRESP     => AFE_SPI_S_AXI_RRESP,
      AFE_SPI_S_AXI_RVALID    => AFE_SPI_S_AXI_RVALID,
      AFE_SPI_S_AXI_RREADY    => AFE_SPI_S_AXI_RREADY,
      TRIRG_S_AXI_ACLK        => TRIRG_S_AXI_ACLK,
      TRIRG_S_AXI_ARESETN     => TRIRG_S_AXI_ARESETN,
      TRIRG_S_AXI_AWADDR      => TRIRG_S_AXI_AWADDR,
      TRIRG_S_AXI_AWPROT      => TRIRG_S_AXI_AWPROT,
      TRIRG_S_AXI_AWVALID     => TRIRG_S_AXI_AWVALID,
      TRIRG_S_AXI_AWREADY     => TRIRG_S_AXI_AWREADY,
      TRIRG_S_AXI_WDATA       => TRIRG_S_AXI_WDATA,
      TRIRG_S_AXI_WSTRB       => TRIRG_S_AXI_WSTRB,
      TRIRG_S_AXI_WVALID      => TRIRG_S_AXI_WVALID,
      TRIRG_S_AXI_WREADY      => TRIRG_S_AXI_WREADY,
      TRIRG_S_AXI_BRESP       => TRIRG_S_AXI_BRESP,
      TRIRG_S_AXI_BVALID      => TRIRG_S_AXI_BVALID,
      TRIRG_S_AXI_BREADY      => TRIRG_S_AXI_BREADY,
      TRIRG_S_AXI_ARADDR      => TRIRG_S_AXI_ARADDR,
      TRIRG_S_AXI_ARPROT      => TRIRG_S_AXI_ARPROT,
      TRIRG_S_AXI_ARVALID     => TRIRG_S_AXI_ARVALID,
      TRIRG_S_AXI_ARREADY     => TRIRG_S_AXI_ARREADY,
      TRIRG_S_AXI_RDATA       => TRIRG_S_AXI_RDATA,
      TRIRG_S_AXI_RRESP       => TRIRG_S_AXI_RRESP,
      TRIRG_S_AXI_RVALID      => TRIRG_S_AXI_RVALID,
      TRIRG_S_AXI_RREADY      => TRIRG_S_AXI_RREADY,
      STUFF_S_AXI_ACLK        => STUFF_S_AXI_ACLK,
      STUFF_S_AXI_ARESETN     => STUFF_S_AXI_ARESETN,
      STUFF_S_AXI_AWADDR      => STUFF_S_AXI_AWADDR,
      STUFF_S_AXI_AWPROT      => STUFF_S_AXI_AWPROT,
      STUFF_S_AXI_AWVALID     => STUFF_S_AXI_AWVALID,
      STUFF_S_AXI_AWREADY     => STUFF_S_AXI_AWREADY,
      STUFF_S_AXI_WDATA       => STUFF_S_AXI_WDATA,
      STUFF_S_AXI_WSTRB       => STUFF_S_AXI_WSTRB,
      STUFF_S_AXI_WVALID      => STUFF_S_AXI_WVALID,
      STUFF_S_AXI_WREADY      => STUFF_S_AXI_WREADY,
      STUFF_S_AXI_BRESP       => STUFF_S_AXI_BRESP,
      STUFF_S_AXI_BVALID      => STUFF_S_AXI_BVALID,
      STUFF_S_AXI_BREADY      => STUFF_S_AXI_BREADY,
      STUFF_S_AXI_ARADDR      => STUFF_S_AXI_ARADDR,
      STUFF_S_AXI_ARPROT      => STUFF_S_AXI_ARPROT,
      STUFF_S_AXI_ARVALID     => STUFF_S_AXI_ARVALID,
      STUFF_S_AXI_ARREADY     => STUFF_S_AXI_ARREADY,
      STUFF_S_AXI_RDATA       => STUFF_S_AXI_RDATA,
      STUFF_S_AXI_RRESP       => STUFF_S_AXI_RRESP,
      STUFF_S_AXI_RVALID      => STUFF_S_AXI_RVALID,
      STUFF_S_AXI_RREADY      => STUFF_S_AXI_RREADY,
      THRESH_S_AXI_ACLK       => THRESH_S_AXI_ACLK,
      THRESH_S_AXI_ARESETN    => THRESH_S_AXI_ARESETN,
      THRESH_S_AXI_AWADDR     => THRESH_S_AXI_AWADDR,
      THRESH_S_AXI_AWPROT     => THRESH_S_AXI_AWPROT,
      THRESH_S_AXI_AWVALID    => THRESH_S_AXI_AWVALID,
      THRESH_S_AXI_AWREADY    => THRESH_S_AXI_AWREADY,
      THRESH_S_AXI_WDATA      => THRESH_S_AXI_WDATA,
      THRESH_S_AXI_WSTRB      => THRESH_S_AXI_WSTRB,
      THRESH_S_AXI_WVALID     => THRESH_S_AXI_WVALID,
      THRESH_S_AXI_WREADY     => THRESH_S_AXI_WREADY,
      THRESH_S_AXI_BRESP      => THRESH_S_AXI_BRESP,
      THRESH_S_AXI_BVALID     => THRESH_S_AXI_BVALID,
      THRESH_S_AXI_BREADY     => THRESH_S_AXI_BREADY,
      THRESH_S_AXI_ARADDR     => THRESH_S_AXI_ARADDR,
      THRESH_S_AXI_ARPROT     => THRESH_S_AXI_ARPROT,
      THRESH_S_AXI_ARVALID    => THRESH_S_AXI_ARVALID,
      THRESH_S_AXI_ARREADY    => THRESH_S_AXI_ARREADY,
      THRESH_S_AXI_RDATA      => THRESH_S_AXI_RDATA,
      THRESH_S_AXI_RRESP      => THRESH_S_AXI_RRESP,
      THRESH_S_AXI_RVALID     => THRESH_S_AXI_RVALID,
      THRESH_S_AXI_RREADY     => THRESH_S_AXI_RREADY,
      OUTBUFF_S_AXI_ACLK      => OUTBUFF_S_AXI_ACLK,
      OUTBUFF_S_AXI_ARESETN   => OUTBUFF_S_AXI_ARESETN,
      OUTBUFF_S_AXI_AWADDR    => OUTBUFF_S_AXI_AWADDR,
      OUTBUFF_S_AXI_AWPROT    => OUTBUFF_S_AXI_AWPROT,
      OUTBUFF_S_AXI_AWVALID   => OUTBUFF_S_AXI_AWVALID,
      OUTBUFF_S_AXI_AWREADY   => OUTBUFF_S_AXI_AWREADY,
      OUTBUFF_S_AXI_WDATA     => OUTBUFF_S_AXI_WDATA,
      OUTBUFF_S_AXI_WSTRB     => OUTBUFF_S_AXI_WSTRB,
      OUTBUFF_S_AXI_WVALID    => OUTBUFF_S_AXI_WVALID,
      OUTBUFF_S_AXI_WREADY    => OUTBUFF_S_AXI_WREADY,
      OUTBUFF_S_AXI_BRESP     => OUTBUFF_S_AXI_BRESP,
      OUTBUFF_S_AXI_BVALID    => OUTBUFF_S_AXI_BVALID,
      OUTBUFF_S_AXI_BREADY    => OUTBUFF_S_AXI_BREADY,
      OUTBUFF_S_AXI_ARADDR    => OUTBUFF_S_AXI_ARADDR,
      OUTBUFF_S_AXI_ARPROT    => OUTBUFF_S_AXI_ARPROT,
      OUTBUFF_S_AXI_ARVALID   => OUTBUFF_S_AXI_ARVALID,
      OUTBUFF_S_AXI_ARREADY   => OUTBUFF_S_AXI_ARREADY,
      OUTBUFF_S_AXI_RDATA     => OUTBUFF_S_AXI_RDATA,
      OUTBUFF_S_AXI_RRESP     => OUTBUFF_S_AXI_RRESP,
      OUTBUFF_S_AXI_RVALID    => OUTBUFF_S_AXI_RVALID,
      OUTBUFF_S_AXI_RREADY    => OUTBUFF_S_AXI_RREADY,
      eth_clk_p               => eth_clk_p,
      eth_clk_n               => eth_clk_n,
      eth0_rx_p               => eth0_rx_p,
      eth0_rx_n               => eth0_rx_n,
      eth0_tx_p               => eth0_tx_p,
      eth0_tx_n               => eth0_tx_n,
      eth0_tx_dis             => eth0_tx_dis,
      out_buff_trig           => out_buff_trig,
      out_buff_clk            => out_buff_clk,
      out_buff_data           => out_buff_data,
      FORCE_TRIG              => FORCE_TRIG,
      DIN_DEBUG               => DIN_DEBUG,
      VALID_DEBUG             => VALID_DEBUG,
      LAST_DEBUG              => LAST_DEBUG,
      clock_gen_debug         => clock_gen_debug,
      mmcm0_100MHZ_CLK_debug  => mmcm0_100MHZ_CLK_debug,
      ep_62p5MHZ_CLK_debug    => ep_62p5MHZ_CLK_debug,
      F_OK_DEBUG              => F_OK_DEBUG,
      SCTR_DEBUG              => SCTR_DEBUG,
      CCTR_DEBUG              => CCTR_DEBUG,
      Trigered_debug          => Trigered_debug
    );
end architecture rtl;
