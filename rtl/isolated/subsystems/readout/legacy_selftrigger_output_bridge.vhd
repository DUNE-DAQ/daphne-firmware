library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity legacy_selftrigger_output_bridge is
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
    eth0_rx_p_i     : in  std_logic_vector(0 downto 0);
    eth0_rx_n_i     : in  std_logic_vector(0 downto 0);
    eth0_tx_p_o     : out std_logic_vector(0 downto 0);
    eth0_tx_n_o     : out std_logic_vector(0 downto 0);
    eth0_tx_dis_o   : out std_logic_vector(0 downto 0);
    clock_i         : in  std_logic;
    reset_i         : in  std_logic;
    data_i          : in  array_2x64_type;
    valid_i         : in  std_logic_vector(1 downto 0);
    last_i          : in  std_logic_vector(1 downto 0);
    timestamp_i     : in  std_logic_vector(63 downto 0);
    outbuff_axi_in  : in  AXILITE_INREC;
    outbuff_axi_out : out AXILITE_OUTREC;
    out_buff_data_o : out std_logic_vector(63 downto 0);
    out_buff_trig_o : out std_logic;
    valid_debug_o   : out std_logic;
    last_debug_o    : out std_logic
  );
end entity legacy_selftrigger_output_bridge;

architecture rtl of legacy_selftrigger_output_bridge is
begin
  legacy_deimos_readout_bridge_inst : entity work.legacy_deimos_readout_bridge
    port map(
      s_axi_aclk_i           => s_axi_aclk_i,
      s_axi_aresetn_i        => s_axi_aresetn_i,
      s_axi_awaddr_i         => s_axi_awaddr_i,
      s_axi_awprot_i         => s_axi_awprot_i,
      s_axi_awvalid_i        => s_axi_awvalid_i,
      s_axi_awready_o        => s_axi_awready_o,
      s_axi_wdata_i          => s_axi_wdata_i,
      s_axi_wstrb_i          => s_axi_wstrb_i,
      s_axi_wvalid_i         => s_axi_wvalid_i,
      s_axi_wready_o         => s_axi_wready_o,
      s_axi_bresp_o          => s_axi_bresp_o,
      s_axi_bvalid_o         => s_axi_bvalid_o,
      s_axi_bready_i         => s_axi_bready_i,
      s_axi_araddr_i         => s_axi_araddr_i,
      s_axi_arprot_i         => s_axi_arprot_i,
      s_axi_arvalid_i        => s_axi_arvalid_i,
      s_axi_arready_o        => s_axi_arready_o,
      s_axi_rdata_o          => s_axi_rdata_o,
      s_axi_rresp_o          => s_axi_rresp_o,
      s_axi_rvalid_o         => s_axi_rvalid_o,
      s_axi_rready_i         => s_axi_rready_i,
      eth_clk_p_i            => eth_clk_p_i,
      eth_clk_n_i            => eth_clk_n_i,
      eth_rx_p_i             => eth0_rx_p_i,
      eth_rx_n_i             => eth0_rx_n_i,
      eth_tx_p_o             => eth0_tx_p_o,
      eth_tx_n_o             => eth0_tx_n_o,
      eth_tx_dis_o           => eth0_tx_dis_o,
      dune_base_clk_i        => clock_i,
      dune_base_rst_i        => reset_i,
      data_clk_i             => clock_i,
      data_clk_rst_i         => reset_i,
      d_i                    => data_i,
      valid_i                => valid_i,
      last_i                 => last_i,
      timestamp_i            => timestamp_i,
      ext_mac_addr_i         => DEFAULT_ext_mac_addr_0,
      ext_ip_addr_i          => DEFAULT_ext_ip_addr_0,
      ext_port_addr_i        => DEFAULT_ext_port_addr_0
    );

  outbuff_inst : entity work.outspybuff
    port map(
      clock   => clock_i,
      din     => data_i,
      valid   => valid_i,
      last    => last_i,
      AXI_IN  => outbuff_axi_in,
      AXI_OUT => outbuff_axi_out
    );

  out_buff_data_o <= data_i(0);
  out_buff_trig_o <= valid_i(0) or valid_i(1);
  valid_debug_o   <= valid_i(0);
  last_debug_o    <= last_i(0);
end architecture rtl;
