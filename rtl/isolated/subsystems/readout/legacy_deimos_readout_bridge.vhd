library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity legacy_deimos_readout_bridge is
  port (
    s_axi_aclk_i    : in  std_logic;
    s_axi_aresetn_i : in  std_logic;
    s_axi_awaddr_i  : in  std_logic_vector(31 downto 0);
    s_axi_awprot_i  : in  std_logic_vector(2 downto 0);
    s_axi_awvalid_i : in  std_logic;
    s_axi_awready_o : out std_logic;
    s_axi_wdata_i   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb_i   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid_i  : in  std_logic;
    s_axi_wready_o  : out std_logic;
    s_axi_bresp_o   : out std_logic_vector(1 downto 0);
    s_axi_bvalid_o  : out std_logic;
    s_axi_bready_i  : in  std_logic;
    s_axi_araddr_i  : in  std_logic_vector(31 downto 0);
    s_axi_arprot_i  : in  std_logic_vector(2 downto 0);
    s_axi_arvalid_i : in  std_logic;
    s_axi_arready_o : out std_logic;
    s_axi_rdata_o   : out std_logic_vector(31 downto 0);
    s_axi_rresp_o   : out std_logic_vector(1 downto 0);
    s_axi_rvalid_o  : out std_logic;
    s_axi_rready_i  : in  std_logic;
    eth_clk_p_i     : in  std_logic;
    eth_clk_n_i     : in  std_logic;
    eth_rx_p_i      : in  std_logic_vector(0 downto 0);
    eth_rx_n_i      : in  std_logic_vector(0 downto 0);
    eth_tx_p_o      : out std_logic_vector(0 downto 0);
    eth_tx_n_o      : out std_logic_vector(0 downto 0);
    eth_tx_dis_o    : out std_logic_vector(0 downto 0);
    dune_base_clk_i : in  std_logic;
    dune_base_rst_i : in  std_logic;
    data_clk_i      : in  std_logic;
    data_clk_rst_i  : in  std_logic;
    d_i             : in  array_2x64_type;
    valid_i         : in  std_logic_vector(1 downto 0);
    last_i          : in  std_logic_vector(1 downto 0);
    timestamp_i     : in  std_logic_vector(63 downto 0);
    ext_mac_addr_i  : in  std_logic_vector(47 downto 0);
    ext_ip_addr_i   : in  std_logic_vector(31 downto 0);
    ext_port_addr_i : in  std_logic_vector(15 downto 0)
  );
end entity legacy_deimos_readout_bridge;

architecture rtl of legacy_deimos_readout_bridge is

  component daphne_top
    port(
      S_AXI_ACLK: in std_logic;
      S_AXI_ARESETN: in std_logic;
      S_AXI_AWADDR: in std_logic_vector(15 downto 0);
      S_AXI_AWPROT: in std_logic_vector(2 downto 0);
      S_AXI_AWVALID: in std_logic;
      S_AXI_AWREADY: out std_logic;
      S_AXI_WDATA: in std_logic_vector(31 downto 0);
      S_AXI_WSTRB: in std_logic_vector(3 downto 0);
      S_AXI_WVALID: in std_logic;
      S_AXI_WREADY: out std_logic;
      S_AXI_BRESP: out std_logic_vector(1 downto 0);
      S_AXI_BVALID: out std_logic;
      S_AXI_BREADY: in std_logic;
      S_AXI_ARADDR: in std_logic_vector(15 downto 0);
      S_AXI_ARPROT: in std_logic_vector(2 downto 0);
      S_AXI_ARVALID: in std_logic;
      S_AXI_ARREADY: out std_logic;
      S_AXI_RDATA: out std_logic_vector(31 downto 0);
      S_AXI_RRESP: out std_logic_vector(1 downto 0);
      S_AXI_RVALID: out std_logic;
      S_AXI_RREADY: in std_logic;
      eth_rx_p: in  std_logic_vector(0 downto 0);
      eth_rx_n: in  std_logic_vector(0 downto 0);
      eth_tx_p: out std_logic_vector(0 downto 0);
      eth_tx_n: out std_logic_vector(0 downto 0);
      eth_tx_dis: out std_logic_vector(0 downto 0);
      eth_clk_p: in std_logic;
      eth_clk_n: in std_logic;
      dune_base_clk: in std_logic;
      dune_base_rst: in std_logic;
      data_clk: in std_logic;
      data_clk_rst: in std_logic;
      d0: in std_logic_vector(63 downto 0);
      d0_valid: in std_logic;
      d0_last: in std_logic;
      d1: in std_logic_vector(63 downto 0);
      d1_valid: in std_logic;
      d1_last: in std_logic;
      ts : in std_logic_vector(63 downto 0);
      ext_mac_addr    : in std_logic_vector(47 downto 0);
      ext_ip_addr     : in std_logic_vector(31 downto 0);
      ext_port_addr   : in std_logic_vector(15 downto 0)
    );
  end component;

begin
  daphne_top_inst: daphne_top
    port map(
      S_AXI_ACLK => s_axi_aclk_i,
      S_AXI_ARESETN => s_axi_aresetn_i,
      S_AXI_AWADDR => s_axi_awaddr_i(15 downto 0),
      S_AXI_AWPROT => s_axi_awprot_i,
      S_AXI_AWVALID => s_axi_awvalid_i,
      S_AXI_AWREADY => s_axi_awready_o,
      S_AXI_WDATA => s_axi_wdata_i,
      S_AXI_WSTRB => s_axi_wstrb_i,
      S_AXI_WVALID => s_axi_wvalid_i,
      S_AXI_WREADY => s_axi_wready_o,
      S_AXI_BRESP => s_axi_bresp_o,
      S_AXI_BVALID => s_axi_bvalid_o,
      S_AXI_BREADY => s_axi_bready_i,
      S_AXI_ARADDR => s_axi_araddr_i(15 downto 0),
      S_AXI_ARPROT => s_axi_arprot_i,
      S_AXI_ARVALID => s_axi_arvalid_i,
      S_AXI_ARREADY => s_axi_arready_o,
      S_AXI_RDATA => s_axi_rdata_o,
      S_AXI_RRESP => s_axi_rresp_o,
      S_AXI_RVALID => s_axi_rvalid_o,
      S_AXI_RREADY => s_axi_rready_i,
      eth_rx_p => eth_rx_p_i,
      eth_rx_n => eth_rx_n_i,
      eth_tx_p => eth_tx_p_o,
      eth_tx_n => eth_tx_n_o,
      eth_tx_dis => eth_tx_dis_o,
      eth_clk_p => eth_clk_p_i,
      eth_clk_n => eth_clk_n_i,
      dune_base_clk => dune_base_clk_i,
      dune_base_rst => dune_base_rst_i,
      data_clk => data_clk_i,
      data_clk_rst => data_clk_rst_i,
      d0 => d_i(0),
      d0_valid => valid_i(0),
      d0_last => last_i(0),
      d1 => d_i(1),
      d1_valid => valid_i(1),
      d1_last => last_i(1),
      ts => timestamp_i,
      ext_mac_addr => ext_mac_addr_i,
      ext_ip_addr => ext_ip_addr_i,
      ext_port_addr => ext_port_addr_i
    );

end architecture rtl;
