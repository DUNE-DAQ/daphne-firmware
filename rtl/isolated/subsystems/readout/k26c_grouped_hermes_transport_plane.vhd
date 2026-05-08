library ieee;
use ieee.std_logic_1164.all;

use work.grouped_transport_pkg.all;

entity k26c_grouped_hermes_transport_plane is
  generic (
    SOURCE_COUNT_G : positive := 10
  );
  port (
    clock              : in  std_logic;
    reset              : in  std_logic;
    timestamp          : in  std_logic_vector(63 downto 0);
    trirg_s_axi_aclk   : in  std_logic;
    trirg_s_axi_aresetn: in  std_logic;
    trirg_s_axi_awaddr : in  std_logic_vector(31 downto 0);
    trirg_s_axi_awprot : in  std_logic_vector(2 downto 0);
    trirg_s_axi_awvalid: in  std_logic;
    trirg_s_axi_awready: out std_logic;
    trirg_s_axi_wdata  : in  std_logic_vector(31 downto 0);
    trirg_s_axi_wstrb  : in  std_logic_vector(3 downto 0);
    trirg_s_axi_wvalid : in  std_logic;
    trirg_s_axi_wready : out std_logic;
    trirg_s_axi_bresp  : out std_logic_vector(1 downto 0);
    trirg_s_axi_bvalid : out std_logic;
    trirg_s_axi_bready : in  std_logic;
    trirg_s_axi_araddr : in  std_logic_vector(31 downto 0);
    trirg_s_axi_arprot : in  std_logic_vector(2 downto 0);
    trirg_s_axi_arvalid: in  std_logic;
    trirg_s_axi_arready: out std_logic;
    trirg_s_axi_rdata  : out std_logic_vector(31 downto 0);
    trirg_s_axi_rresp  : out std_logic_vector(1 downto 0);
    trirg_s_axi_rvalid : out std_logic;
    trirg_s_axi_rready : in  std_logic;
    eth_clk_p          : in  std_logic;
    eth_clk_n          : in  std_logic;
    eth0_rx_p          : in  std_logic_vector(0 downto 0);
    eth0_rx_n          : in  std_logic_vector(0 downto 0);
    eth0_tx_p          : out std_logic_vector(0 downto 0);
    eth0_tx_n          : out std_logic_vector(0 downto 0);
    eth0_tx_dis        : out std_logic_vector(0 downto 0);
    readout_i          : in  grouped_source_stream_array_t(0 to SOURCE_COUNT_G - 1)
  );
end entity k26c_grouped_hermes_transport_plane;

architecture rtl of k26c_grouped_hermes_transport_plane is
begin
  grouped_hermes_readout_bridge_inst : entity work.grouped_hermes_readout_bridge
    generic map (
      SOURCE_COUNT_G => SOURCE_COUNT_G
    )
    port map (
      s_axi_aclk_i    => trirg_s_axi_aclk,
      s_axi_aresetn_i => trirg_s_axi_aresetn,
      s_axi_awaddr_i  => trirg_s_axi_awaddr,
      s_axi_awprot_i  => trirg_s_axi_awprot,
      s_axi_awvalid_i => trirg_s_axi_awvalid,
      s_axi_awready_o => trirg_s_axi_awready,
      s_axi_wdata_i   => trirg_s_axi_wdata,
      s_axi_wstrb_i   => trirg_s_axi_wstrb,
      s_axi_wvalid_i  => trirg_s_axi_wvalid,
      s_axi_wready_o  => trirg_s_axi_wready,
      s_axi_bresp_o   => trirg_s_axi_bresp,
      s_axi_bvalid_o  => trirg_s_axi_bvalid,
      s_axi_bready_i  => trirg_s_axi_bready,
      s_axi_araddr_i  => trirg_s_axi_araddr,
      s_axi_arprot_i  => trirg_s_axi_arprot,
      s_axi_arvalid_i => trirg_s_axi_arvalid,
      s_axi_arready_o => trirg_s_axi_arready,
      s_axi_rdata_o   => trirg_s_axi_rdata,
      s_axi_rresp_o   => trirg_s_axi_rresp,
      s_axi_rvalid_o  => trirg_s_axi_rvalid,
      s_axi_rready_i  => trirg_s_axi_rready,
      eth_clk_p_i     => eth_clk_p,
      eth_clk_n_i     => eth_clk_n,
      eth_rx_p_i      => eth0_rx_p,
      eth_rx_n_i      => eth0_rx_n,
      eth_tx_p_o      => eth0_tx_p,
      eth_tx_n_o      => eth0_tx_n,
      eth_tx_dis_o    => eth0_tx_dis,
      dune_base_clk_i => clock,
      dune_base_rst_i => reset,
      data_clk_i      => clock,
      data_clk_rst_i  => reset,
      readout_i       => readout_i,
      timestamp_i     => timestamp
    );
end architecture rtl;
