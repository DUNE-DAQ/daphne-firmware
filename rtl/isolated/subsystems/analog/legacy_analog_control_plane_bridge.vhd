library ieee;
use ieee.std_logic_1164.all;

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
begin
  afe_dac_io_inst: entity work.legacy_afe_dac_io_bridge
    port map(
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
      spi_dac_s_axi_aclk   => spi_dac_s_axi_aclk,
      spi_dac_s_axi_aresetn => spi_dac_s_axi_aresetn,
      spi_dac_s_axi_awaddr => spi_dac_s_axi_awaddr,
      spi_dac_s_axi_awprot => spi_dac_s_axi_awprot,
      spi_dac_s_axi_awvalid => spi_dac_s_axi_awvalid,
      spi_dac_s_axi_awready => spi_dac_s_axi_awready,
      spi_dac_s_axi_wdata  => spi_dac_s_axi_wdata,
      spi_dac_s_axi_wstrb  => spi_dac_s_axi_wstrb,
      spi_dac_s_axi_wvalid => spi_dac_s_axi_wvalid,
      spi_dac_s_axi_wready => spi_dac_s_axi_wready,
      spi_dac_s_axi_bresp  => spi_dac_s_axi_bresp,
      spi_dac_s_axi_bvalid => spi_dac_s_axi_bvalid,
      spi_dac_s_axi_bready => spi_dac_s_axi_bready,
      spi_dac_s_axi_araddr => spi_dac_s_axi_araddr,
      spi_dac_s_axi_arprot => spi_dac_s_axi_arprot,
      spi_dac_s_axi_arvalid => spi_dac_s_axi_arvalid,
      spi_dac_s_axi_arready => spi_dac_s_axi_arready,
      spi_dac_s_axi_rdata  => spi_dac_s_axi_rdata,
      spi_dac_s_axi_rresp  => spi_dac_s_axi_rresp,
      spi_dac_s_axi_rvalid => spi_dac_s_axi_rvalid,
      spi_dac_s_axi_rready => spi_dac_s_axi_rready
    );

  board_control_inst: entity work.legacy_board_control_bridge
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
      stuff_s_axi_aclk       => stuff_s_axi_aclk,
      stuff_s_axi_aresetn    => stuff_s_axi_aresetn,
      stuff_s_axi_awaddr     => stuff_s_axi_awaddr,
      stuff_s_axi_awprot     => stuff_s_axi_awprot,
      stuff_s_axi_awvalid    => stuff_s_axi_awvalid,
      stuff_s_axi_awready    => stuff_s_axi_awready,
      stuff_s_axi_wdata      => stuff_s_axi_wdata,
      stuff_s_axi_wstrb      => stuff_s_axi_wstrb,
      stuff_s_axi_wvalid     => stuff_s_axi_wvalid,
      stuff_s_axi_wready     => stuff_s_axi_wready,
      stuff_s_axi_bresp      => stuff_s_axi_bresp,
      stuff_s_axi_bvalid     => stuff_s_axi_bvalid,
      stuff_s_axi_bready     => stuff_s_axi_bready,
      stuff_s_axi_araddr     => stuff_s_axi_araddr,
      stuff_s_axi_arprot     => stuff_s_axi_arprot,
      stuff_s_axi_arvalid    => stuff_s_axi_arvalid,
      stuff_s_axi_arready    => stuff_s_axi_arready,
      stuff_s_axi_rdata      => stuff_s_axi_rdata,
      stuff_s_axi_rresp      => stuff_s_axi_rresp,
      stuff_s_axi_rvalid     => stuff_s_axi_rvalid,
      stuff_s_axi_rready     => stuff_s_axi_rready
    );
end architecture rtl;
