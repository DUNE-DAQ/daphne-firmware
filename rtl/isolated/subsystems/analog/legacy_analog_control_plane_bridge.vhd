library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity legacy_analog_control_plane_bridge is
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
end entity legacy_analog_control_plane_bridge;

architecture rtl of legacy_analog_control_plane_bridge is
  signal afe_axi_awaddr:  std_logic_vector(31 downto 0);
  signal afe_axi_awprot:  std_logic_vector(2 downto 0);
  signal afe_axi_awvalid: std_logic;
  signal afe_axi_awready: std_logic;
  signal afe_axi_wdata:   std_logic_vector(31 downto 0);
  signal afe_axi_wstrb:   std_logic_vector(3 downto 0);
  signal afe_axi_wvalid:  std_logic;
  signal afe_axi_wready:  std_logic;
  signal afe_axi_bresp:   std_logic_vector(1 downto 0);
  signal afe_axi_bvalid:  std_logic;
  signal afe_axi_bready:  std_logic;
  signal afe_axi_araddr:  std_logic_vector(31 downto 0);
  signal afe_axi_arprot:  std_logic_vector(2 downto 0);
  signal afe_axi_arvalid: std_logic;
  signal afe_axi_arready: std_logic;
  signal afe_axi_rdata:   std_logic_vector(31 downto 0);
  signal afe_axi_rresp:   std_logic_vector(1 downto 0);
  signal afe_axi_rvalid:  std_logic;
  signal afe_axi_rready:  std_logic;

  signal dac_axi_awaddr:  std_logic_vector(31 downto 0);
  signal dac_axi_awprot:  std_logic_vector(2 downto 0);
  signal dac_axi_awvalid: std_logic;
  signal dac_axi_awready: std_logic;
  signal dac_axi_wdata:   std_logic_vector(31 downto 0);
  signal dac_axi_wstrb:   std_logic_vector(3 downto 0);
  signal dac_axi_wvalid:  std_logic;
  signal dac_axi_wready:  std_logic;
  signal dac_axi_bresp:   std_logic_vector(1 downto 0);
  signal dac_axi_bvalid:  std_logic;
  signal dac_axi_bready:  std_logic;
  signal dac_axi_araddr:  std_logic_vector(31 downto 0);
  signal dac_axi_arprot:  std_logic_vector(2 downto 0);
  signal dac_axi_arvalid: std_logic;
  signal dac_axi_arready: std_logic;
  signal dac_axi_rdata:   std_logic_vector(31 downto 0);
  signal dac_axi_rresp:   std_logic_vector(1 downto 0);
  signal dac_axi_rvalid:  std_logic;
  signal dac_axi_rready:  std_logic;

  signal stuff_axi_awaddr:  std_logic_vector(31 downto 0);
  signal stuff_axi_awprot:  std_logic_vector(2 downto 0);
  signal stuff_axi_awvalid: std_logic;
  signal stuff_axi_awready: std_logic;
  signal stuff_axi_wdata:   std_logic_vector(31 downto 0);
  signal stuff_axi_wstrb:   std_logic_vector(3 downto 0);
  signal stuff_axi_wvalid:  std_logic;
  signal stuff_axi_wready:  std_logic;
  signal stuff_axi_bresp:   std_logic_vector(1 downto 0);
  signal stuff_axi_bvalid:  std_logic;
  signal stuff_axi_bready:  std_logic;
  signal stuff_axi_araddr:  std_logic_vector(31 downto 0);
  signal stuff_axi_arprot:  std_logic_vector(2 downto 0);
  signal stuff_axi_arvalid: std_logic;
  signal stuff_axi_arready: std_logic;
  signal stuff_axi_rdata:   std_logic_vector(31 downto 0);
  signal stuff_axi_rresp:   std_logic_vector(1 downto 0);
  signal stuff_axi_rvalid:  std_logic;
  signal stuff_axi_rready:  std_logic;
begin
  afe_axi_awaddr         <= afe_spi_s_axi_awaddr;
  afe_axi_awprot         <= afe_spi_s_axi_awprot;
  afe_axi_awvalid        <= afe_spi_s_axi_awvalid;
  afe_spi_s_axi_awready  <= afe_axi_awready;
  afe_axi_wdata          <= afe_spi_s_axi_wdata;
  afe_axi_wstrb          <= afe_spi_s_axi_wstrb;
  afe_axi_wvalid         <= afe_spi_s_axi_wvalid;
  afe_spi_s_axi_wready   <= afe_axi_wready;
  afe_spi_s_axi_bresp    <= afe_axi_bresp;
  afe_spi_s_axi_bvalid   <= afe_axi_bvalid;
  afe_axi_bready         <= afe_spi_s_axi_bready;
  afe_axi_araddr         <= afe_spi_s_axi_araddr;
  afe_axi_arprot         <= afe_spi_s_axi_arprot;
  afe_axi_arvalid        <= afe_spi_s_axi_arvalid;
  afe_spi_s_axi_arready  <= afe_axi_arready;
  afe_spi_s_axi_rdata    <= afe_axi_rdata;
  afe_spi_s_axi_rresp    <= afe_axi_rresp;
  afe_spi_s_axi_rvalid   <= afe_axi_rvalid;
  afe_axi_rready         <= afe_spi_s_axi_rready;

  dac_axi_awaddr         <= spi_dac_s_axi_awaddr;
  dac_axi_awprot         <= spi_dac_s_axi_awprot;
  dac_axi_awvalid        <= spi_dac_s_axi_awvalid;
  spi_dac_s_axi_awready  <= dac_axi_awready;
  dac_axi_wdata          <= spi_dac_s_axi_wdata;
  dac_axi_wstrb          <= spi_dac_s_axi_wstrb;
  dac_axi_wvalid         <= spi_dac_s_axi_wvalid;
  spi_dac_s_axi_wready   <= dac_axi_wready;
  spi_dac_s_axi_bresp    <= dac_axi_bresp;
  spi_dac_s_axi_bvalid   <= dac_axi_bvalid;
  dac_axi_bready         <= spi_dac_s_axi_bready;
  dac_axi_araddr         <= spi_dac_s_axi_araddr;
  dac_axi_arprot         <= spi_dac_s_axi_arprot;
  dac_axi_arvalid        <= spi_dac_s_axi_arvalid;
  spi_dac_s_axi_arready  <= dac_axi_arready;
  spi_dac_s_axi_rdata    <= dac_axi_rdata;
  spi_dac_s_axi_rresp    <= dac_axi_rresp;
  spi_dac_s_axi_rvalid   <= dac_axi_rvalid;
  dac_axi_rready         <= spi_dac_s_axi_rready;

  stuff_axi_awaddr       <= stuff_s_axi_awaddr;
  stuff_axi_awprot       <= stuff_s_axi_awprot;
  stuff_axi_awvalid      <= stuff_s_axi_awvalid;
  stuff_s_axi_awready    <= stuff_axi_awready;
  stuff_axi_wdata        <= stuff_s_axi_wdata;
  stuff_axi_wstrb        <= stuff_s_axi_wstrb;
  stuff_axi_wvalid       <= stuff_s_axi_wvalid;
  stuff_s_axi_wready     <= stuff_axi_wready;
  stuff_s_axi_bresp      <= stuff_axi_bresp;
  stuff_s_axi_bvalid     <= stuff_axi_bvalid;
  stuff_axi_bready       <= stuff_s_axi_bready;
  stuff_axi_araddr       <= stuff_s_axi_araddr;
  stuff_axi_arprot       <= stuff_s_axi_arprot;
  stuff_axi_arvalid      <= stuff_s_axi_arvalid;
  stuff_s_axi_arready    <= stuff_axi_arready;
  stuff_s_axi_rdata      <= stuff_axi_rdata;
  stuff_s_axi_rresp      <= stuff_axi_rresp;
  stuff_s_axi_rvalid     <= stuff_axi_rvalid;
  stuff_axi_rready       <= stuff_s_axi_rready;

  spim_afe_inst: entity work.spim_afe
    port map(
      afe_rst       => afe_rst,
      afe_pdn       => afe_pdn,
      afe0_miso     => afe0_miso,
      afe0_sclk     => afe0_sclk,
      afe0_mosi     => afe0_mosi,
      afe12_miso    => afe12_miso,
      afe12_sclk    => afe12_sclk,
      afe12_mosi    => afe12_mosi,
      afe34_miso    => afe34_miso,
      afe34_sclk    => afe34_sclk,
      afe34_mosi    => afe34_mosi,
      afe_sen       => afe_sen,
      trim_sync_n   => trim_sync_n,
      trim_ldac_n   => trim_ldac_n,
      offset_sync_n => offset_sync_n,
      offset_ldac_n => offset_ldac_n,
      S_AXI_ACLK    => afe_spi_s_axi_aclk,
      S_AXI_ARESETN => afe_spi_s_axi_aresetn,
      S_AXI_AWADDR  => afe_axi_awaddr,
      S_AXI_AWPROT  => afe_axi_awprot,
      S_AXI_AWVALID => afe_axi_awvalid,
      S_AXI_AWREADY => afe_axi_awready,
      S_AXI_WDATA   => afe_axi_wdata,
      S_AXI_WSTRB   => afe_axi_wstrb,
      S_AXI_WVALID  => afe_axi_wvalid,
      S_AXI_WREADY  => afe_axi_wready,
      S_AXI_BRESP   => afe_axi_bresp,
      S_AXI_BVALID  => afe_axi_bvalid,
      S_AXI_BREADY  => afe_axi_bready,
      S_AXI_ARADDR  => afe_axi_araddr,
      S_AXI_ARPROT  => afe_axi_arprot,
      S_AXI_ARVALID => afe_axi_arvalid,
      S_AXI_ARREADY => afe_axi_arready,
      S_AXI_RDATA   => afe_axi_rdata,
      S_AXI_RRESP   => afe_axi_rresp,
      S_AXI_RVALID  => afe_axi_rvalid,
      S_AXI_RREADY  => afe_axi_rready
    );

  spim_dac_inst: entity work.spim_dac
    port map(
      dac_sclk      => dac_sclk,
      dac_din       => dac_din,
      dac_sync_n    => dac_sync_n,
      dac_ldac_n    => dac_ldac_n,
      S_AXI_ACLK    => spi_dac_s_axi_aclk,
      S_AXI_ARESETN => spi_dac_s_axi_aresetn,
      S_AXI_AWADDR  => dac_axi_awaddr,
      S_AXI_AWPROT  => dac_axi_awprot,
      S_AXI_AWVALID => dac_axi_awvalid,
      S_AXI_AWREADY => dac_axi_awready,
      S_AXI_WDATA   => dac_axi_wdata,
      S_AXI_WSTRB   => dac_axi_wstrb,
      S_AXI_WVALID  => dac_axi_wvalid,
      S_AXI_WREADY  => dac_axi_wready,
      S_AXI_BRESP   => dac_axi_bresp,
      S_AXI_BVALID  => dac_axi_bvalid,
      S_AXI_BREADY  => dac_axi_bready,
      S_AXI_ARADDR  => dac_axi_araddr,
      S_AXI_ARPROT  => dac_axi_arprot,
      S_AXI_ARVALID => dac_axi_arvalid,
      S_AXI_ARREADY => dac_axi_arready,
      S_AXI_RDATA   => dac_axi_rdata,
      S_AXI_RRESP   => dac_axi_rresp,
      S_AXI_RVALID  => dac_axi_rvalid,
      S_AXI_RREADY  => dac_axi_rready
    );

  stuff_inst: entity work.stuff
    port map(
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
      S_AXI_ACLK           => stuff_s_axi_aclk,
      S_AXI_ARESETN        => stuff_s_axi_aresetn,
      S_AXI_AWADDR         => stuff_axi_awaddr,
      S_AXI_AWPROT         => stuff_axi_awprot,
      S_AXI_AWVALID        => stuff_axi_awvalid,
      S_AXI_AWREADY        => stuff_axi_awready,
      S_AXI_WDATA          => stuff_axi_wdata,
      S_AXI_WSTRB          => stuff_axi_wstrb,
      S_AXI_WVALID         => stuff_axi_wvalid,
      S_AXI_WREADY         => stuff_axi_wready,
      S_AXI_BRESP          => stuff_axi_bresp,
      S_AXI_BVALID         => stuff_axi_bvalid,
      S_AXI_BREADY         => stuff_axi_bready,
      S_AXI_ARADDR         => stuff_axi_araddr,
      S_AXI_ARPROT         => stuff_axi_arprot,
      S_AXI_ARVALID        => stuff_axi_arvalid,
      S_AXI_ARREADY        => stuff_axi_arready,
      S_AXI_RDATA          => stuff_axi_rdata,
      S_AXI_RRESP          => stuff_axi_rresp,
      S_AXI_RVALID         => stuff_axi_rvalid,
      S_AXI_RREADY         => stuff_axi_rready
    );
end architecture rtl;
