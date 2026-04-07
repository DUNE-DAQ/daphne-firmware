library ieee;
use ieee.std_logic_1164.all;

entity k26c_board_analog_control_plane is
port(
    fan_tach: in std_logic_vector(1 downto 0);
    fan_ctrl: out std_logic;
    hvbias_en: out std_logic;
    mux_en: out std_logic_vector(1 downto 0);
    mux_a: out std_logic_vector(1 downto 0);
    stat_led: out std_logic_vector(5 downto 0);
    version: in std_logic_vector(27 downto 0);
    adhoc: out std_logic_vector(7 downto 0);
    core_chan_enable: out std_logic_vector(39 downto 0);
    filter_output_selector: out std_logic_vector(1 downto 0);
    afe_comp_enable: out std_logic_vector(39 downto 0);
    invert_enable: out std_logic_vector(39 downto 0);
    st_config: out std_logic_vector(13 downto 0);
    signal_delay: out std_logic_vector(4 downto 0);
    reset_st_counters: out std_logic;

    dac_sclk: out std_logic;
    dac_din: out std_logic;
    dac_sync_n: out std_logic;
    dac_ldac_n: out std_logic;

    afe_rst: out std_logic;
    afe_pdn: out std_logic;
    afe0_miso: in std_logic;
    afe0_sclk: out std_logic;
    afe0_mosi: out std_logic;
    afe12_miso: in std_logic;
    afe12_sclk: out std_logic;
    afe12_mosi: out std_logic;
    afe34_miso: in std_logic;
    afe34_sclk: out std_logic;
    afe34_mosi: out std_logic;
    afe_sen: out std_logic_vector(4 downto 0);
    trim_sync_n: out std_logic_vector(4 downto 0);
    trim_ldac_n: out std_logic_vector(4 downto 0);
    offset_sync_n: out std_logic_vector(4 downto 0);
    offset_ldac_n: out std_logic_vector(4 downto 0);

    afe_spi_s_axi_aclk: in std_logic;
    afe_spi_s_axi_aresetn: in std_logic;
    afe_spi_s_axi_awaddr: in std_logic_vector(31 downto 0);
    afe_spi_s_axi_awprot: in std_logic_vector(2 downto 0);
    afe_spi_s_axi_awvalid: in std_logic;
    afe_spi_s_axi_awready: out std_logic;
    afe_spi_s_axi_wdata: in std_logic_vector(31 downto 0);
    afe_spi_s_axi_wstrb: in std_logic_vector(3 downto 0);
    afe_spi_s_axi_wvalid: in std_logic;
    afe_spi_s_axi_wready: out std_logic;
    afe_spi_s_axi_bresp: out std_logic_vector(1 downto 0);
    afe_spi_s_axi_bvalid: out std_logic;
    afe_spi_s_axi_bready: in std_logic;
    afe_spi_s_axi_araddr: in std_logic_vector(31 downto 0);
    afe_spi_s_axi_arprot: in std_logic_vector(2 downto 0);
    afe_spi_s_axi_arvalid: in std_logic;
    afe_spi_s_axi_arready: out std_logic;
    afe_spi_s_axi_rdata: out std_logic_vector(31 downto 0);
    afe_spi_s_axi_rresp: out std_logic_vector(1 downto 0);
    afe_spi_s_axi_rvalid: out std_logic;
    afe_spi_s_axi_rready: in std_logic;

    spi_dac_s_axi_aclk: in std_logic;
    spi_dac_s_axi_aresetn: in std_logic;
    spi_dac_s_axi_awaddr: in std_logic_vector(31 downto 0);
    spi_dac_s_axi_awprot: in std_logic_vector(2 downto 0);
    spi_dac_s_axi_awvalid: in std_logic;
    spi_dac_s_axi_awready: out std_logic;
    spi_dac_s_axi_wdata: in std_logic_vector(31 downto 0);
    spi_dac_s_axi_wstrb: in std_logic_vector(3 downto 0);
    spi_dac_s_axi_wvalid: in std_logic;
    spi_dac_s_axi_wready: out std_logic;
    spi_dac_s_axi_bresp: out std_logic_vector(1 downto 0);
    spi_dac_s_axi_bvalid: out std_logic;
    spi_dac_s_axi_bready: in std_logic;
    spi_dac_s_axi_araddr: in std_logic_vector(31 downto 0);
    spi_dac_s_axi_arprot: in std_logic_vector(2 downto 0);
    spi_dac_s_axi_arvalid: in std_logic;
    spi_dac_s_axi_arready: out std_logic;
    spi_dac_s_axi_rdata: out std_logic_vector(31 downto 0);
    spi_dac_s_axi_rresp: out std_logic_vector(1 downto 0);
    spi_dac_s_axi_rvalid: out std_logic;
    spi_dac_s_axi_rready: in std_logic;

    stuff_s_axi_aclk: in std_logic;
    stuff_s_axi_aresetn: in std_logic;
    stuff_s_axi_awaddr: in std_logic_vector(31 downto 0);
    stuff_s_axi_awprot: in std_logic_vector(2 downto 0);
    stuff_s_axi_awvalid: in std_logic;
    stuff_s_axi_awready: out std_logic;
    stuff_s_axi_wdata: in std_logic_vector(31 downto 0);
    stuff_s_axi_wstrb: in std_logic_vector(3 downto 0);
    stuff_s_axi_wvalid: in std_logic;
    stuff_s_axi_wready: out std_logic;
    stuff_s_axi_bresp: out std_logic_vector(1 downto 0);
    stuff_s_axi_bvalid: out std_logic;
    stuff_s_axi_bready: in std_logic;
    stuff_s_axi_araddr: in std_logic_vector(31 downto 0);
    stuff_s_axi_arprot: in std_logic_vector(2 downto 0);
    stuff_s_axi_arvalid: in std_logic;
    stuff_s_axi_arready: out std_logic;
    stuff_s_axi_rdata: out std_logic_vector(31 downto 0);
    stuff_s_axi_rresp: out std_logic_vector(1 downto 0);
    stuff_s_axi_rvalid: out std_logic;
    stuff_s_axi_rready: in std_logic
);
end entity k26c_board_analog_control_plane;

architecture rtl of k26c_board_analog_control_plane is
begin
  spim_afe_inst: entity work.spim_afe
    port map(
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
      afe_spi_s_axi_aclk   => afe_spi_s_axi_aclk,
      afe_spi_s_axi_aresetn => afe_spi_s_axi_aresetn,
      afe_spi_s_axi_awaddr => afe_spi_s_axi_awaddr,
      afe_spi_s_axi_awprot => afe_spi_s_axi_awprot,
      afe_spi_s_axi_awvalid => afe_spi_s_axi_awvalid,
      afe_spi_s_axi_awready => afe_spi_s_axi_awready,
      afe_spi_s_axi_wdata  => afe_spi_s_axi_wdata,
      afe_spi_s_axi_wstrb  => afe_spi_s_axi_wstrb,
      afe_spi_s_axi_wvalid => afe_spi_s_axi_wvalid,
      afe_spi_s_axi_wready => afe_spi_s_axi_wready,
      afe_spi_s_axi_bresp  => afe_spi_s_axi_bresp,
      afe_spi_s_axi_bvalid => afe_spi_s_axi_bvalid,
      afe_spi_s_axi_bready => afe_spi_s_axi_bready,
      afe_spi_s_axi_araddr => afe_spi_s_axi_araddr,
      afe_spi_s_axi_arprot => afe_spi_s_axi_arprot,
      afe_spi_s_axi_arvalid => afe_spi_s_axi_arvalid,
      afe_spi_s_axi_arready => afe_spi_s_axi_arready,
      afe_spi_s_axi_rdata  => afe_spi_s_axi_rdata,
      afe_spi_s_axi_rresp  => afe_spi_s_axi_rresp,
      afe_spi_s_axi_rvalid => afe_spi_s_axi_rvalid,
      afe_spi_s_axi_rready => afe_spi_s_axi_rready,
      S_AXI_ACLK            => afe_spi_s_axi_aclk,
      S_AXI_ARESETN         => afe_spi_s_axi_aresetn,
      S_AXI_AWADDR          => afe_spi_s_axi_awaddr,
      S_AXI_AWPROT          => afe_spi_s_axi_awprot,
      S_AXI_AWVALID         => afe_spi_s_axi_awvalid,
      S_AXI_AWREADY         => afe_spi_s_axi_awready,
      S_AXI_WDATA           => afe_spi_s_axi_wdata,
      S_AXI_WSTRB           => afe_spi_s_axi_wstrb,
      S_AXI_WVALID          => afe_spi_s_axi_wvalid,
      S_AXI_WREADY          => afe_spi_s_axi_wready,
      S_AXI_BRESP           => afe_spi_s_axi_bresp,
      S_AXI_BVALID          => afe_spi_s_axi_bvalid,
      S_AXI_BREADY          => afe_spi_s_axi_bready,
      S_AXI_ARADDR          => afe_spi_s_axi_araddr,
      S_AXI_ARPROT          => afe_spi_s_axi_arprot,
      S_AXI_ARVALID         => afe_spi_s_axi_arvalid,
      S_AXI_ARREADY         => afe_spi_s_axi_arready,
      S_AXI_RDATA           => afe_spi_s_axi_rdata,
      S_AXI_RRESP           => afe_spi_s_axi_rresp,
      S_AXI_RVALID          => afe_spi_s_axi_rvalid,
      S_AXI_RREADY          => afe_spi_s_axi_rready
    );

  spim_dac_inst: entity work.spim_dac
    port map(
      dac_sclk              => dac_sclk,
      dac_din               => dac_din,
      dac_sync_n            => dac_sync_n,
      dac_ldac_n            => dac_ldac_n,
      S_AXI_ACLK            => spi_dac_s_axi_aclk,
      S_AXI_ARESETN         => spi_dac_s_axi_aresetn,
      S_AXI_AWADDR          => spi_dac_s_axi_awaddr,
      S_AXI_AWPROT          => spi_dac_s_axi_awprot,
      S_AXI_AWVALID         => spi_dac_s_axi_awvalid,
      S_AXI_AWREADY         => spi_dac_s_axi_awready,
      S_AXI_WDATA           => spi_dac_s_axi_wdata,
      S_AXI_WSTRB           => spi_dac_s_axi_wstrb,
      S_AXI_WVALID          => spi_dac_s_axi_wvalid,
      S_AXI_WREADY          => spi_dac_s_axi_wready,
      S_AXI_BRESP           => spi_dac_s_axi_bresp,
      S_AXI_BVALID          => spi_dac_s_axi_bvalid,
      S_AXI_BREADY          => spi_dac_s_axi_bready,
      S_AXI_ARADDR          => spi_dac_s_axi_araddr,
      S_AXI_ARPROT          => spi_dac_s_axi_arprot,
      S_AXI_ARVALID         => spi_dac_s_axi_arvalid,
      S_AXI_ARREADY         => spi_dac_s_axi_arready,
      S_AXI_RDATA           => spi_dac_s_axi_rdata,
      S_AXI_RRESP           => spi_dac_s_axi_rresp,
      S_AXI_RVALID          => spi_dac_s_axi_rvalid,
      S_AXI_RREADY          => spi_dac_s_axi_rready
    );

  stuff_inst: entity work.stuff
    port map(
      fan_tach               => fan_tach,
      fan_ctrl               => fan_ctrl,
      hvbias_en              => hvbias_en,
      mux_en                 => mux_en,
      mux_a                  => mux_a,
      stat_led               => stat_led,
      version                => version,
      adhoc                  => adhoc,
      core_chan_enable       => core_chan_enable,
      filter_output_selector => filter_output_selector,
      afe_comp_enable        => afe_comp_enable,
      invert_enable          => invert_enable,
      st_config              => st_config,
      signal_delay           => signal_delay,
      reset_st_counters      => reset_st_counters,
      S_AXI_ACLK             => stuff_s_axi_aclk,
      S_AXI_ARESETN          => stuff_s_axi_aresetn,
      S_AXI_AWADDR           => stuff_s_axi_awaddr,
      S_AXI_AWPROT           => stuff_s_axi_awprot,
      S_AXI_AWVALID          => stuff_s_axi_awvalid,
      S_AXI_AWREADY          => stuff_s_axi_awready,
      S_AXI_WDATA            => stuff_s_axi_wdata,
      S_AXI_WSTRB            => stuff_s_axi_wstrb,
      S_AXI_WVALID           => stuff_s_axi_wvalid,
      S_AXI_WREADY           => stuff_s_axi_wready,
      S_AXI_BRESP            => stuff_s_axi_bresp,
      S_AXI_BVALID           => stuff_s_axi_bvalid,
      S_AXI_BREADY           => stuff_s_axi_bready,
      S_AXI_ARADDR           => stuff_s_axi_araddr,
      S_AXI_ARPROT           => stuff_s_axi_arprot,
      S_AXI_ARVALID          => stuff_s_axi_arvalid,
      S_AXI_ARREADY          => stuff_s_axi_arready,
      S_AXI_RDATA            => stuff_s_axi_rdata,
      S_AXI_RRESP            => stuff_s_axi_rresp,
      S_AXI_RVALID           => stuff_s_axi_rvalid,
      S_AXI_RREADY           => stuff_s_axi_rready
    );
end architecture rtl;
