library ieee;
use ieee.std_logic_1164.all;

entity legacy_afe_dac_io_bridge is
port(
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
    spi_dac_s_axi_rready: in std_logic
);
end entity legacy_afe_dac_io_bridge;

architecture rtl of legacy_afe_dac_io_bridge is
begin
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
      S_AXI_AWADDR  => afe_spi_s_axi_awaddr,
      S_AXI_AWPROT  => afe_spi_s_axi_awprot,
      S_AXI_AWVALID => afe_spi_s_axi_awvalid,
      S_AXI_AWREADY => afe_spi_s_axi_awready,
      S_AXI_WDATA   => afe_spi_s_axi_wdata,
      S_AXI_WSTRB   => afe_spi_s_axi_wstrb,
      S_AXI_WVALID  => afe_spi_s_axi_wvalid,
      S_AXI_WREADY  => afe_spi_s_axi_wready,
      S_AXI_BRESP   => afe_spi_s_axi_bresp,
      S_AXI_BVALID  => afe_spi_s_axi_bvalid,
      S_AXI_BREADY  => afe_spi_s_axi_bready,
      S_AXI_ARADDR  => afe_spi_s_axi_araddr,
      S_AXI_ARPROT  => afe_spi_s_axi_arprot,
      S_AXI_ARVALID => afe_spi_s_axi_arvalid,
      S_AXI_ARREADY => afe_spi_s_axi_arready,
      S_AXI_RDATA   => afe_spi_s_axi_rdata,
      S_AXI_RRESP   => afe_spi_s_axi_rresp,
      S_AXI_RVALID  => afe_spi_s_axi_rvalid,
      S_AXI_RREADY  => afe_spi_s_axi_rready
    );

  spim_dac_inst: entity work.spim_dac
    port map(
      dac_sclk      => dac_sclk,
      dac_din       => dac_din,
      dac_sync_n    => dac_sync_n,
      dac_ldac_n    => dac_ldac_n,
      S_AXI_ACLK    => spi_dac_s_axi_aclk,
      S_AXI_ARESETN => spi_dac_s_axi_aresetn,
      S_AXI_AWADDR  => spi_dac_s_axi_awaddr,
      S_AXI_AWPROT  => spi_dac_s_axi_awprot,
      S_AXI_AWVALID => spi_dac_s_axi_awvalid,
      S_AXI_AWREADY => spi_dac_s_axi_awready,
      S_AXI_WDATA   => spi_dac_s_axi_wdata,
      S_AXI_WSTRB   => spi_dac_s_axi_wstrb,
      S_AXI_WVALID  => spi_dac_s_axi_wvalid,
      S_AXI_WREADY  => spi_dac_s_axi_wready,
      S_AXI_BRESP   => spi_dac_s_axi_bresp,
      S_AXI_BVALID  => spi_dac_s_axi_bvalid,
      S_AXI_BREADY  => spi_dac_s_axi_bready,
      S_AXI_ARADDR  => spi_dac_s_axi_araddr,
      S_AXI_ARPROT  => spi_dac_s_axi_arprot,
      S_AXI_ARVALID => spi_dac_s_axi_arvalid,
      S_AXI_ARREADY => spi_dac_s_axi_arready,
      S_AXI_RDATA   => spi_dac_s_axi_rdata,
      S_AXI_RRESP   => spi_dac_s_axi_rresp,
      S_AXI_RVALID  => spi_dac_s_axi_rvalid,
      S_AXI_RREADY  => spi_dac_s_axi_rready
    );
end architecture rtl;
