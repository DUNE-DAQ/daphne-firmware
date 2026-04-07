library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity k26c_board_transport_plane is
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

    outbuff_s_axi_aclk: in std_logic;
    outbuff_s_axi_aresetn: in std_logic;
    outbuff_s_axi_awaddr: in std_logic_vector(31 downto 0);
    outbuff_s_axi_awprot: in std_logic_vector(2 downto 0);
    outbuff_s_axi_awvalid: in std_logic;
    outbuff_s_axi_awready: out std_logic;
    outbuff_s_axi_wdata: in std_logic_vector(31 downto 0);
    outbuff_s_axi_wstrb: in std_logic_vector(3 downto 0);
    outbuff_s_axi_wvalid: in std_logic;
    outbuff_s_axi_wready: out std_logic;
    outbuff_s_axi_bresp: out std_logic_vector(1 downto 0);
    outbuff_s_axi_bvalid: out std_logic;
    outbuff_s_axi_bready: in std_logic;
    outbuff_s_axi_araddr: in std_logic_vector(31 downto 0);
    outbuff_s_axi_arprot: in std_logic_vector(2 downto 0);
    outbuff_s_axi_arvalid: in std_logic;
    outbuff_s_axi_arready: out std_logic;
    outbuff_s_axi_rdata: out std_logic_vector(31 downto 0);
    outbuff_s_axi_rresp: out std_logic_vector(1 downto 0);
    outbuff_s_axi_rvalid: out std_logic;
    outbuff_s_axi_rready: in std_logic;

    eth_clk_p: in std_logic;
    eth_clk_n: in std_logic;
    eth0_rx_p: in std_logic_vector(0 downto 0);
    eth0_rx_n: in std_logic_vector(0 downto 0);
    eth0_tx_p: out std_logic_vector(0 downto 0);
    eth0_tx_n: out std_logic_vector(0 downto 0);
    eth0_tx_dis: out std_logic_vector(0 downto 0);

    readout_data_i: in array_2x64_type;
    readout_valid_i: in std_logic_vector(1 downto 0);
    readout_last_i: in std_logic_vector(1 downto 0);

    out_buff_data: out std_logic_vector(63 downto 0);
    out_buff_trig: out std_logic;
    valid_debug: out std_logic;
    last_debug: out std_logic
);
end k26c_board_transport_plane;

architecture rtl of k26c_board_transport_plane is
begin
  hermes_transport_plane_inst : entity work.k26c_board_hermes_transport_plane
    port map(
      clock               => clock,
      reset               => reset,
      timestamp           => timestamp,
      trirg_s_axi_aclk    => trirg_s_axi_aclk,
      trirg_s_axi_aresetn => trirg_s_axi_aresetn,
      trirg_s_axi_awaddr  => trirg_s_axi_awaddr,
      trirg_s_axi_awprot  => trirg_s_axi_awprot,
      trirg_s_axi_awvalid => trirg_s_axi_awvalid,
      trirg_s_axi_awready => trirg_s_axi_awready,
      trirg_s_axi_wdata   => trirg_s_axi_wdata,
      trirg_s_axi_wstrb   => trirg_s_axi_wstrb,
      trirg_s_axi_wvalid  => trirg_s_axi_wvalid,
      trirg_s_axi_wready  => trirg_s_axi_wready,
      trirg_s_axi_bresp   => trirg_s_axi_bresp,
      trirg_s_axi_bvalid  => trirg_s_axi_bvalid,
      trirg_s_axi_bready  => trirg_s_axi_bready,
      trirg_s_axi_araddr  => trirg_s_axi_araddr,
      trirg_s_axi_arprot  => trirg_s_axi_arprot,
      trirg_s_axi_arvalid => trirg_s_axi_arvalid,
      trirg_s_axi_arready => trirg_s_axi_arready,
      trirg_s_axi_rdata   => trirg_s_axi_rdata,
      trirg_s_axi_rresp   => trirg_s_axi_rresp,
      trirg_s_axi_rvalid  => trirg_s_axi_rvalid,
      trirg_s_axi_rready  => trirg_s_axi_rready,
      eth_clk_p           => eth_clk_p,
      eth_clk_n           => eth_clk_n,
      eth0_rx_p           => eth0_rx_p,
      eth0_rx_n           => eth0_rx_n,
      eth0_tx_p           => eth0_tx_p,
      eth0_tx_n           => eth0_tx_n,
      eth0_tx_dis         => eth0_tx_dis,
      readout_data_i      => readout_data_i,
      readout_valid_i     => readout_valid_i,
      readout_last_i      => readout_last_i
    );

  outbuffer_plane_inst : entity work.k26c_board_outbuffer_plane
    port map(
      clock                => clock,
      outbuff_s_axi_aclk   => outbuff_s_axi_aclk,
      outbuff_s_axi_aresetn => outbuff_s_axi_aresetn,
      outbuff_s_axi_awaddr => outbuff_s_axi_awaddr,
      outbuff_s_axi_awprot => outbuff_s_axi_awprot,
      outbuff_s_axi_awvalid => outbuff_s_axi_awvalid,
      outbuff_s_axi_awready => outbuff_s_axi_awready,
      outbuff_s_axi_wdata  => outbuff_s_axi_wdata,
      outbuff_s_axi_wstrb  => outbuff_s_axi_wstrb,
      outbuff_s_axi_wvalid => outbuff_s_axi_wvalid,
      outbuff_s_axi_wready => outbuff_s_axi_wready,
      outbuff_s_axi_bresp  => outbuff_s_axi_bresp,
      outbuff_s_axi_bvalid => outbuff_s_axi_bvalid,
      outbuff_s_axi_bready => outbuff_s_axi_bready,
      outbuff_s_axi_araddr => outbuff_s_axi_araddr,
      outbuff_s_axi_arprot => outbuff_s_axi_arprot,
      outbuff_s_axi_arvalid => outbuff_s_axi_arvalid,
      outbuff_s_axi_arready => outbuff_s_axi_arready,
      outbuff_s_axi_rdata  => outbuff_s_axi_rdata,
      outbuff_s_axi_rresp  => outbuff_s_axi_rresp,
      outbuff_s_axi_rvalid => outbuff_s_axi_rvalid,
      outbuff_s_axi_rready => outbuff_s_axi_rready,
      readout_data_i       => readout_data_i,
      readout_valid_i      => readout_valid_i,
      readout_last_i       => readout_last_i,
      out_buff_data        => out_buff_data,
      out_buff_trig        => out_buff_trig,
      valid_debug          => valid_debug,
      last_debug           => last_debug
    );
end architecture rtl;
