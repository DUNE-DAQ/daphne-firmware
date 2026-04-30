library ieee;
use ieee.std_logic_1164.all;

library work;
use work.addr_pkg.all;
use work.daphne_package.all;
use work.freq_pkg.all;
use work.grouped_transport_pkg.all;
use work.ipbus.all;
use work.ipbus_axi4lite_decl.all;
use work.tx_mux_decl.all;

entity grouped_hermes_readout_bridge is
  generic (
    SOURCE_COUNT_G : positive := 5;
    IN_BUF_DEPTH_G : natural := 2048;
    REF_FREQ_G     : t_freq := f156_25
  );
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
    readout_i       : in  grouped_source_stream_array_t(SOURCE_COUNT_G - 1 downto 0);
    timestamp_i     : in  std_logic_vector(63 downto 0);
    ext_mac_addr_i  : in  std_logic_vector(47 downto 0) := DEFAULT_ext_mac_addr_0;
    ext_ip_addr_i   : in  std_logic_vector(31 downto 0) := DEFAULT_ext_ip_addr_0;
    ext_port_addr_i : in  std_logic_vector(15 downto 0) := DEFAULT_ext_port_addr_0
  );
end entity grouped_hermes_readout_bridge;

architecture rtl of grouped_hermes_readout_bridge is
  component ipb_axi4_lite_ctrl is
    generic(
      BUFWIDTH  : natural := 2;
      ADDRWIDTH : natural := 11
    );
    port (
      aclk     : in  std_logic;
      aresetn  : in  std_logic;
      axi_in   : in  ipb_axi4lite_mosi;
      axi_out  : out ipb_axi4lite_miso;
      ipb_clk  : out std_logic;
      ipb_rst  : out std_logic;
      ipb_in   : in  ipb_rbus;
      ipb_out  : out ipb_wbus;
      nuke     : in  std_logic;
      soft_rst : in  std_logic
    );
  end component ipb_axi4_lite_ctrl;

  component eth_readout is
    generic(
      N_SRC        : positive;
      N_MGT        : positive;
      IN_BUF_DEPTH : natural;
      REF_FREQ     : t_freq := f156_25
    );
    port(
      ipb_clk       : in  std_logic;
      ipb_rst       : in  std_logic;
      ipb_in        : in  ipb_wbus;
      ipb_out       : out ipb_rbus;
      nuke          : out std_logic;
      soft_rst      : out std_logic;
      eth_rx_p      : in  std_logic_vector(N_MGT - 1 downto 0);
      eth_rx_n      : in  std_logic_vector(N_MGT - 1 downto 0);
      eth_tx_p      : out std_logic_vector(N_MGT - 1 downto 0);
      eth_tx_n      : out std_logic_vector(N_MGT - 1 downto 0);
      eth_tx_dis    : out std_logic_vector(N_MGT - 1 downto 0);
      eth_clk_p     : in  std_logic;
      eth_clk_n     : in  std_logic;
      dune_base_clk : in  std_logic;
      dune_base_rst : in  std_logic;
      ts            : in  std_logic_vector(63 downto 0);
      data_clk      : in  std_logic;
      data_clk_rst  : in  std_logic;
      d             : in  array_of_src_d_arrays(N_MGT - 1 downto 0)(N_SRC - 1 downto 0);
      ext_mac_addr  : in  mac_addr_array(N_MGT - 1 downto 0);
      ext_ip_addr   : in  ip_addr_array(N_MGT - 1 downto 0);
      ext_port_addr : in  udp_port_array(N_MGT - 1 downto 0)
    );
  end component eth_readout;

  signal axi_in_s  : ipb_axi4lite_mosi;
  signal axi_out_s : ipb_axi4lite_miso;
  signal ipbw_s    : ipb_wbus;
  signal ipbr_s    : ipb_rbus;
  signal ipb_clk_s : std_logic;
  signal ipb_rst_s : std_logic;
  signal nuke_s    : std_logic;
  signal soft_rst_s: std_logic;

  signal hermes_sources_s : array_of_src_d_arrays(0 downto 0)(SOURCE_COUNT_G - 1 downto 0);
  signal ext_mac_addr_s   : mac_addr_array(0 downto 0);
  signal ext_ip_addr_s    : ip_addr_array(0 downto 0);
  signal ext_port_addr_s  : udp_port_array(0 downto 0);
begin
  axi_in_s.awaddr  <= s_axi_awaddr_i;
  axi_in_s.awprot  <= s_axi_awprot_i;
  axi_in_s.awvalid <= s_axi_awvalid_i;
  axi_in_s.wdata   <= s_axi_wdata_i;
  axi_in_s.wstrb   <= s_axi_wstrb_i;
  axi_in_s.wvalid  <= s_axi_wvalid_i;
  axi_in_s.bready  <= s_axi_bready_i;
  axi_in_s.araddr  <= s_axi_araddr_i;
  axi_in_s.arprot  <= s_axi_arprot_i;
  axi_in_s.arvalid <= s_axi_arvalid_i;
  axi_in_s.rready  <= s_axi_rready_i;

  s_axi_awready_o <= axi_out_s.awready;
  s_axi_wready_o  <= axi_out_s.wready;
  s_axi_bresp_o   <= axi_out_s.bresp;
  s_axi_bvalid_o  <= axi_out_s.bvalid;
  s_axi_arready_o <= axi_out_s.arready;
  s_axi_rdata_o   <= axi_out_s.rdata;
  s_axi_rresp_o   <= axi_out_s.rresp;
  s_axi_rvalid_o  <= axi_out_s.rvalid;

  hermes_sources_s(0) <= to_src_d_array(readout_i);
  ext_mac_addr_s(0)   <= ext_mac_addr_i;
  ext_ip_addr_s(0)    <= ext_ip_addr_i;
  ext_port_addr_s(0)  <= ext_port_addr_i;

  ipb_ctrl_inst : ipb_axi4_lite_ctrl
    port map (
      aclk     => s_axi_aclk_i,
      aresetn  => s_axi_aresetn_i,
      axi_in   => axi_in_s,
      axi_out  => axi_out_s,
      ipb_clk  => ipb_clk_s,
      ipb_rst  => ipb_rst_s,
      ipb_in   => ipbr_s,
      ipb_out  => ipbw_s,
      nuke     => nuke_s,
      soft_rst => soft_rst_s
    );

  hermes_transport_inst : eth_readout
    generic map (
      N_SRC        => SOURCE_COUNT_G,
      N_MGT        => 1,
      IN_BUF_DEPTH => IN_BUF_DEPTH_G,
      REF_FREQ     => REF_FREQ_G
    )
    port map (
      ipb_clk       => ipb_clk_s,
      ipb_rst       => ipb_rst_s,
      ipb_in        => ipbw_s,
      ipb_out       => ipbr_s,
      nuke          => nuke_s,
      soft_rst      => soft_rst_s,
      eth_rx_p      => eth_rx_p_i,
      eth_rx_n      => eth_rx_n_i,
      eth_tx_p      => eth_tx_p_o,
      eth_tx_n      => eth_tx_n_o,
      eth_tx_dis    => eth_tx_dis_o,
      eth_clk_p     => eth_clk_p_i,
      eth_clk_n     => eth_clk_n_i,
      dune_base_clk => dune_base_clk_i,
      dune_base_rst => dune_base_rst_i,
      ts            => timestamp_i,
      data_clk      => data_clk_i,
      data_clk_rst  => data_clk_rst_i,
      d             => hermes_sources_s,
      ext_mac_addr  => ext_mac_addr_s,
      ext_ip_addr   => ext_ip_addr_s,
      ext_port_addr => ext_port_addr_s
    );

end architecture rtl;
