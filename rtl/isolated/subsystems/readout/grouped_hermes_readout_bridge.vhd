library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ipbus;
use work.ipbus.all;

library work;
use work.addr_pkg.all;
use work.freq_pkg.all;
use work.grouped_transport_pkg.all;
use work.tx_mux_decl.all;

entity grouped_hermes_readout_bridge is
  generic (
    SOURCE_COUNT_G : positive := GROUPED_SOURCE_COUNT_5_C;
    IN_BUF_DEPTH_G : natural  := 2048;
    REF_FREQ_G     : t_freq   := f156_25
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
    readout_data_i  : in  slv64_array_t(SOURCE_COUNT_G - 1 downto 0);
    readout_valid_i : in  std_logic_vector(SOURCE_COUNT_G - 1 downto 0);
    readout_last_i  : in  std_logic_vector(SOURCE_COUNT_G - 1 downto 0);
    timestamp_i     : in  std_logic_vector(63 downto 0);
    ext_mac_addr_i  : in  std_logic_vector(47 downto 0);
    ext_ip_addr_i   : in  std_logic_vector(31 downto 0);
    ext_port_addr_i : in  std_logic_vector(15 downto 0)
  );
end entity grouped_hermes_readout_bridge;

architecture rtl of grouped_hermes_readout_bridge is
  signal ipbw : ipb_wbus;
  signal ipbr : ipb_rbus;
  signal ipb_clk : std_logic;
  signal ipb_rst : std_logic;
  signal nuke : std_logic;
  signal soft_rst : std_logic;

  signal src_s           : array_of_src_d_arrays(0 downto 0)(SOURCE_COUNT_G - 1 downto 0);
  signal ext_mac_addr_s  : mac_addr_array(0 downto 0);
  signal ext_ip_addr_s   : ip_addr_array(0 downto 0);
  signal ext_port_addr_s : udp_port_array(0 downto 0);

  constant C_S_AXI_ADDR_WIDTH : integer := 16;
begin

  ext_mac_addr_s(0)  <= ext_mac_addr_i;
  ext_ip_addr_s(0)   <= ext_ip_addr_i;
  ext_port_addr_s(0) <= ext_port_addr_i;

  src_gen : for i in 0 to SOURCE_COUNT_G - 1 generate
  begin
    src_s(0)(i).d     <= readout_data_i(i);
    src_s(0)(i).valid <= readout_valid_i(i);
    src_s(0)(i).last  <= readout_last_i(i);
  end generate;

  ipb_ctrl : entity work.ipb_axi4_lite_ctrl
    port map (
      aclk => s_axi_aclk_i,
      aresetn => s_axi_aresetn_i,
      axi_in.awaddr(31 downto C_S_AXI_ADDR_WIDTH) => (others => '0'),
      axi_in.awaddr(C_S_AXI_ADDR_WIDTH - 1 downto 0) => s_axi_awaddr_i(15 downto 0),
      axi_in.awprot => s_axi_awprot_i,
      axi_in.awvalid => s_axi_awvalid_i,
      axi_in.wdata => s_axi_wdata_i,
      axi_in.wstrb => s_axi_wstrb_i,
      axi_in.wvalid => s_axi_wvalid_i,
      axi_in.bready => s_axi_bready_i,
      axi_in.araddr(31 downto C_S_AXI_ADDR_WIDTH) => (others => '0'),
      axi_in.araddr(C_S_AXI_ADDR_WIDTH - 1 downto 0) => s_axi_araddr_i(15 downto 0),
      axi_in.arprot => s_axi_arprot_i,
      axi_in.arvalid => s_axi_arvalid_i,
      axi_in.rready => s_axi_rready_i,
      axi_out.awready => s_axi_awready_o,
      axi_out.wready => s_axi_wready_o,
      axi_out.bresp => s_axi_bresp_o,
      axi_out.bvalid => s_axi_bvalid_o,
      axi_out.arready => s_axi_arready_o,
      axi_out.rdata => s_axi_rdata_o,
      axi_out.rresp => s_axi_rresp_o,
      axi_out.rvalid => s_axi_rvalid_o,
      ipb_clk => ipb_clk,
      ipb_rst => ipb_rst,
      ipb_in => ipbr,
      ipb_out => ipbw,
      nuke => nuke,
      soft_rst => soft_rst
    );

  hermes_inst : entity work.eth_readout
    generic map(
      N_SRC        => SOURCE_COUNT_G,
      N_MGT        => 1,
      IN_BUF_DEPTH => IN_BUF_DEPTH_G,
      REF_FREQ     => REF_FREQ_G
    )
    port map(
      ipb_clk       => ipb_clk,
      ipb_rst       => ipb_rst,
      ipb_in        => ipbw,
      ipb_out       => ipbr,
      nuke          => nuke,
      soft_rst      => soft_rst,
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
      d             => src_s,
      ext_mac_addr  => ext_mac_addr_s,
      ext_ip_addr   => ext_ip_addr_s,
      ext_port_addr => ext_port_addr_s
    );

end architecture rtl;
