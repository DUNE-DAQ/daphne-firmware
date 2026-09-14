library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity k26c_board_hermes_transport_plane is
port(
    clock: in std_logic;
    reset: in std_logic;
    timestamp: in std_logic_vector(63 downto 0);

    trirg_s_axi_aclk: in std_logic;
    trirg_s_axi_aresetn: in std_logic;
    trirg_s_axi_awaddr: in std_logic_vector(31 downto 0);
    trirg_s_axi_awprot: in std_logic_vector(2 downto 0);
    trirg_s_axi_awvalid: in std_logic;
    trirg_s_axi_awready: out std_logic;
    trirg_s_axi_wdata: in std_logic_vector(31 downto 0);
    trirg_s_axi_wstrb: in std_logic_vector(3 downto 0);
    trirg_s_axi_wvalid: in std_logic;
    trirg_s_axi_wready: out std_logic;
    trirg_s_axi_bresp: out std_logic_vector(1 downto 0);
    trirg_s_axi_bvalid: out std_logic;
    trirg_s_axi_bready: in std_logic;
    trirg_s_axi_araddr: in std_logic_vector(31 downto 0);
    trirg_s_axi_arprot: in std_logic_vector(2 downto 0);
    trirg_s_axi_arvalid: in std_logic;
    trirg_s_axi_arready: out std_logic;
    trirg_s_axi_rdata: out std_logic_vector(31 downto 0);
    trirg_s_axi_rresp: out std_logic_vector(1 downto 0);
    trirg_s_axi_rvalid: out std_logic;
    trirg_s_axi_rready: in std_logic;

    eth_clk_p: in std_logic;
    eth_clk_n: in std_logic;
    eth0_rx_p: in std_logic_vector(0 downto 0);
    eth0_rx_n: in std_logic_vector(0 downto 0);
    eth0_tx_p: out std_logic_vector(0 downto 0);
    eth0_tx_n: out std_logic_vector(0 downto 0);
    eth0_tx_dis: out std_logic_vector(0 downto 0);

    eth1_rx_p: in std_logic_vector(0 downto 0);
    eth1_rx_n: in std_logic_vector(0 downto 0);
    eth1_tx_p: out std_logic_vector(0 downto 0);
    eth1_tx_n: out std_logic_vector(0 downto 0);
    eth1_tx_dis: out std_logic_vector(0 downto 0);
    eth2_rx_p: in std_logic_vector(0 downto 0);
    eth2_rx_n: in std_logic_vector(0 downto 0);
    eth2_tx_p: out std_logic_vector(0 downto 0);
    eth2_tx_n: out std_logic_vector(0 downto 0);
    eth2_tx_dis: out std_logic_vector(0 downto 0);
    eth3_rx_p: in std_logic_vector(0 downto 0);
    eth3_rx_n: in std_logic_vector(0 downto 0);
    eth3_tx_p: out std_logic_vector(0 downto 0);
    eth3_tx_n: out std_logic_vector(0 downto 0);
    eth3_tx_dis: out std_logic_vector(0 downto 0);

    readout_ready_o: out std_logic_vector(7 downto 0);
    readout_data_i: in array_8x64_type;
    readout_valid_i: in std_logic_vector(7 downto 0);
    readout_last_i: in std_logic_vector(7 downto 0)
);
end k26c_board_hermes_transport_plane;

architecture rtl of k26c_board_hermes_transport_plane is
  signal eth_rx_p_s, eth_rx_n_s, eth_tx_p_s, eth_tx_n_s, eth_tx_dis_s: std_logic_vector(3 downto 0);
  signal core_axi_awaddr:  std_logic_vector(31 downto 0);
  signal core_axi_awprot:  std_logic_vector(2 downto 0);
  signal core_axi_awvalid: std_logic;
  signal core_axi_awready: std_logic;
  signal core_axi_wdata:   std_logic_vector(31 downto 0);
  signal core_axi_wstrb:   std_logic_vector(3 downto 0);
  signal core_axi_wvalid:  std_logic;
  signal core_axi_wready:  std_logic;
  signal core_axi_bresp:   std_logic_vector(1 downto 0);
  signal core_axi_bvalid:  std_logic;
  signal core_axi_bready:  std_logic;
  signal core_axi_araddr:  std_logic_vector(31 downto 0);
  signal core_axi_arprot:  std_logic_vector(2 downto 0);
  signal core_axi_arvalid: std_logic;
  signal core_axi_arready: std_logic;
  signal core_axi_rdata:   std_logic_vector(31 downto 0);
  signal core_axi_rresp:   std_logic_vector(1 downto 0);
  signal core_axi_rvalid:  std_logic;
  signal core_axi_rready:  std_logic;
begin
  eth_rx_p_s <= eth3_rx_p & eth2_rx_p & eth1_rx_p & eth0_rx_p;
  eth_rx_n_s <= eth3_rx_n & eth2_rx_n & eth1_rx_n & eth0_rx_n;
  eth0_tx_p(0) <= eth_tx_p_s(0);
  eth0_tx_n(0) <= eth_tx_n_s(0);
  eth0_tx_dis(0) <= eth_tx_dis_s(0);
  eth1_tx_p(0) <= eth_tx_p_s(1);
  eth1_tx_n(0) <= eth_tx_n_s(1);
  eth1_tx_dis(0) <= eth_tx_dis_s(1);
  eth2_tx_p(0) <= eth_tx_p_s(2);
  eth2_tx_n(0) <= eth_tx_n_s(2);
  eth2_tx_dis(0) <= eth_tx_dis_s(2);
  eth3_tx_p(0) <= eth_tx_p_s(3);
  eth3_tx_n(0) <= eth_tx_n_s(3);
  eth3_tx_dis(0) <= eth_tx_dis_s(3);
  core_axi_awaddr     <= trirg_s_axi_awaddr;
  core_axi_awprot     <= trirg_s_axi_awprot;
  core_axi_awvalid    <= trirg_s_axi_awvalid;
  trirg_s_axi_awready <= core_axi_awready;
  core_axi_wdata      <= trirg_s_axi_wdata;
  core_axi_wstrb      <= trirg_s_axi_wstrb;
  core_axi_wvalid     <= trirg_s_axi_wvalid;
  trirg_s_axi_wready  <= core_axi_wready;
  trirg_s_axi_bresp   <= core_axi_bresp;
  trirg_s_axi_bvalid  <= core_axi_bvalid;
  core_axi_bready     <= trirg_s_axi_bready;
  core_axi_araddr     <= trirg_s_axi_araddr;
  core_axi_arprot     <= trirg_s_axi_arprot;
  core_axi_arvalid    <= trirg_s_axi_arvalid;
  trirg_s_axi_arready <= core_axi_arready;
  trirg_s_axi_rdata   <= core_axi_rdata;
  trirg_s_axi_rresp   <= core_axi_rresp;
  trirg_s_axi_rvalid  <= core_axi_rvalid;
  core_axi_rready     <= trirg_s_axi_rready;

  daphne_top_inst : entity work.daphne_top
    generic map (N_MGT => 4, PACKET_WORDS => 120, IN_BUF_DEPTH => 512)
    port map(
      S_AXI_ACLK    => trirg_s_axi_aclk,
      S_AXI_ARESETN => trirg_s_axi_aresetn,
      S_AXI_AWADDR  => core_axi_awaddr(15 downto 0),
      S_AXI_AWPROT  => core_axi_awprot,
      S_AXI_AWVALID => core_axi_awvalid,
      S_AXI_AWREADY => core_axi_awready,
      S_AXI_WDATA   => core_axi_wdata,
      S_AXI_WSTRB   => core_axi_wstrb,
      S_AXI_WVALID  => core_axi_wvalid,
      S_AXI_WREADY  => core_axi_wready,
      S_AXI_BRESP   => core_axi_bresp,
      S_AXI_BVALID  => core_axi_bvalid,
      S_AXI_BREADY  => core_axi_bready,
      S_AXI_ARADDR  => core_axi_araddr(15 downto 0),
      S_AXI_ARPROT  => core_axi_arprot,
      S_AXI_ARVALID => core_axi_arvalid,
      S_AXI_ARREADY => core_axi_arready,
      S_AXI_RDATA   => core_axi_rdata,
      S_AXI_RRESP   => core_axi_rresp,
      S_AXI_RVALID  => core_axi_rvalid,
      S_AXI_RREADY  => core_axi_rready,
      eth_rx_p      => eth_rx_p_s,
      eth_rx_n      => eth_rx_n_s,
      eth_tx_p      => eth_tx_p_s,
      eth_tx_n      => eth_tx_n_s,
      eth_tx_dis    => eth_tx_dis_s,
      eth_clk_p     => eth_clk_p,
      eth_clk_n     => eth_clk_n,
      dune_base_clk => clock,
      dune_base_rst => reset,
      data_clk      => clock,
      data_clk_rst  => reset,
      d0            => readout_data_i(0),
      d0_valid      => readout_valid_i(0),
      d0_last       => readout_last_i(0),
      d1            => readout_data_i(1),
      d1_valid      => readout_valid_i(1),
      d1_last       => readout_last_i(1),
      d2 => readout_data_i(2), d2_valid => readout_valid_i(2), d2_last => readout_last_i(2),
      d3 => readout_data_i(3), d3_valid => readout_valid_i(3), d3_last => readout_last_i(3),
      d4 => readout_data_i(4), d4_valid => readout_valid_i(4), d4_last => readout_last_i(4),
      d5 => readout_data_i(5), d5_valid => readout_valid_i(5), d5_last => readout_last_i(5),
      d6 => readout_data_i(6), d6_valid => readout_valid_i(6), d6_last => readout_last_i(6),
      d7 => readout_data_i(7), d7_valid => readout_valid_i(7), d7_last => readout_last_i(7),
      packet_ready => readout_ready_o,
      ts            => timestamp,
      ext_mac_addr  => DEFAULT_ext_mac_addr_0,
      ext_ip_addr   => DEFAULT_ext_ip_addr_0,
      ext_port_addr => DEFAULT_ext_port_addr_0
    );
end architecture rtl;
