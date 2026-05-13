library ieee;
use ieee.std_logic_1164.all;

library work;
use work.grouped_transport_pkg.all;

entity k26c_board_grouped_transport_plane is
  generic (
    SOURCE_COUNT_G        : positive := 5;
    HERMES_IN_BUF_DEPTH_G : natural := 2048;
    ENABLE_OUTBUFFER_G    : boolean  := false
  );
  port (
    clock               : in  std_logic;
    reset               : in  std_logic;
    timestamp           : in  std_logic_vector(63 downto 0);

    trirg_s_axi_aclk    : in  std_logic;
    trirg_s_axi_aresetn : in  std_logic;
    trirg_s_axi_awaddr  : in  std_logic_vector(31 downto 0);
    trirg_s_axi_awprot  : in  std_logic_vector(2 downto 0);
    trirg_s_axi_awvalid : in  std_logic;
    trirg_s_axi_awready : out std_logic;
    trirg_s_axi_wdata   : in  std_logic_vector(31 downto 0);
    trirg_s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    trirg_s_axi_wvalid  : in  std_logic;
    trirg_s_axi_wready  : out std_logic;
    trirg_s_axi_bresp   : out std_logic_vector(1 downto 0);
    trirg_s_axi_bvalid  : out std_logic;
    trirg_s_axi_bready  : in  std_logic;
    trirg_s_axi_araddr  : in  std_logic_vector(31 downto 0);
    trirg_s_axi_arprot  : in  std_logic_vector(2 downto 0);
    trirg_s_axi_arvalid : in  std_logic;
    trirg_s_axi_arready : out std_logic;
    trirg_s_axi_rdata   : out std_logic_vector(31 downto 0);
    trirg_s_axi_rresp   : out std_logic_vector(1 downto 0);
    trirg_s_axi_rvalid  : out std_logic;
    trirg_s_axi_rready  : in  std_logic;

    outbuff_s_axi_aclk   : in  std_logic;
    outbuff_s_axi_aresetn: in  std_logic;
    outbuff_s_axi_awaddr : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_awprot : in  std_logic_vector(2 downto 0);
    outbuff_s_axi_awvalid: in  std_logic;
    outbuff_s_axi_awready: out std_logic;
    outbuff_s_axi_wdata  : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_wstrb  : in  std_logic_vector(3 downto 0);
    outbuff_s_axi_wvalid : in  std_logic;
    outbuff_s_axi_wready : out std_logic;
    outbuff_s_axi_bresp  : out std_logic_vector(1 downto 0);
    outbuff_s_axi_bvalid : out std_logic;
    outbuff_s_axi_bready : in  std_logic;
    outbuff_s_axi_araddr : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_arprot : in  std_logic_vector(2 downto 0);
    outbuff_s_axi_arvalid: in  std_logic;
    outbuff_s_axi_arready: out std_logic;
    outbuff_s_axi_rdata  : out std_logic_vector(31 downto 0);
    outbuff_s_axi_rresp  : out std_logic_vector(1 downto 0);
    outbuff_s_axi_rvalid : out std_logic;
    outbuff_s_axi_rready : in  std_logic;

    eth_clk_p           : in  std_logic;
    eth_clk_n           : in  std_logic;
    eth0_rx_p           : in  std_logic_vector(0 downto 0);
    eth0_rx_n           : in  std_logic_vector(0 downto 0);
    eth0_tx_p           : out std_logic_vector(0 downto 0);
    eth0_tx_n           : out std_logic_vector(0 downto 0);
    eth0_tx_dis         : out std_logic_vector(0 downto 0);

    readout_i           : in  grouped_source_stream_array_t(0 to SOURCE_COUNT_G - 1);
    readout_ready_o     : out std_logic_vector(0 to SOURCE_COUNT_G - 1);

    out_buff_data       : out std_logic_vector(63 downto 0);
    out_buff_trig       : out std_logic;
    valid_debug         : out std_logic;
    last_debug          : out std_logic
  );
end entity k26c_board_grouped_transport_plane;

architecture rtl of k26c_board_grouped_transport_plane is
begin
  hermes_transport_plane_inst : entity work.k26c_grouped_hermes_transport_plane
    generic map (
      SOURCE_COUNT_G        => SOURCE_COUNT_G,
      HERMES_IN_BUF_DEPTH_G => HERMES_IN_BUF_DEPTH_G
    )
    port map (
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
      readout_i           => readout_i,
      readout_ready_o     => readout_ready_o
    );

  gen_outbuffer_enabled : if ENABLE_OUTBUFFER_G generate
  begin
    outbuffer_plane_inst : entity work.k26c_board_grouped_outbuffer_plane
      generic map (
        SOURCE_COUNT_G => SOURCE_COUNT_G
      )
      port map (
        clock                => clock,
        outbuff_s_axi_aclk   => outbuff_s_axi_aclk,
        outbuff_s_axi_aresetn=> outbuff_s_axi_aresetn,
        outbuff_s_axi_awaddr => outbuff_s_axi_awaddr,
        outbuff_s_axi_awprot => outbuff_s_axi_awprot,
        outbuff_s_axi_awvalid=> outbuff_s_axi_awvalid,
        outbuff_s_axi_awready=> outbuff_s_axi_awready,
        outbuff_s_axi_wdata  => outbuff_s_axi_wdata,
        outbuff_s_axi_wstrb  => outbuff_s_axi_wstrb,
        outbuff_s_axi_wvalid => outbuff_s_axi_wvalid,
        outbuff_s_axi_wready => outbuff_s_axi_wready,
        outbuff_s_axi_bresp  => outbuff_s_axi_bresp,
        outbuff_s_axi_bvalid => outbuff_s_axi_bvalid,
        outbuff_s_axi_bready => outbuff_s_axi_bready,
        outbuff_s_axi_araddr => outbuff_s_axi_araddr,
        outbuff_s_axi_arprot => outbuff_s_axi_arprot,
        outbuff_s_axi_arvalid=> outbuff_s_axi_arvalid,
        outbuff_s_axi_arready=> outbuff_s_axi_arready,
        outbuff_s_axi_rdata  => outbuff_s_axi_rdata,
        outbuff_s_axi_rresp  => outbuff_s_axi_rresp,
        outbuff_s_axi_rvalid => outbuff_s_axi_rvalid,
        outbuff_s_axi_rready => outbuff_s_axi_rready,
        readout_i            => readout_i,
        out_buff_data        => out_buff_data,
        out_buff_trig        => out_buff_trig,
        valid_debug          => valid_debug,
        last_debug           => last_debug
      );
  end generate gen_outbuffer_enabled;

  gen_outbuffer_disabled : if ENABLE_OUTBUFFER_G = false generate
  begin
    outbuffer_null_slave_inst : entity work.axilite_null_slave
      port map (
        s_axi_aclk    => outbuff_s_axi_aclk,
        s_axi_aresetn => outbuff_s_axi_aresetn,
        s_axi_awaddr  => outbuff_s_axi_awaddr,
        s_axi_awprot  => outbuff_s_axi_awprot,
        s_axi_awvalid => outbuff_s_axi_awvalid,
        s_axi_awready => outbuff_s_axi_awready,
        s_axi_wdata   => outbuff_s_axi_wdata,
        s_axi_wstrb   => outbuff_s_axi_wstrb,
        s_axi_wvalid  => outbuff_s_axi_wvalid,
        s_axi_wready  => outbuff_s_axi_wready,
        s_axi_bresp   => outbuff_s_axi_bresp,
        s_axi_bvalid  => outbuff_s_axi_bvalid,
        s_axi_bready  => outbuff_s_axi_bready,
        s_axi_araddr  => outbuff_s_axi_araddr,
        s_axi_arprot  => outbuff_s_axi_arprot,
        s_axi_arvalid => outbuff_s_axi_arvalid,
        s_axi_arready => outbuff_s_axi_arready,
        s_axi_rdata   => outbuff_s_axi_rdata,
        s_axi_rresp   => outbuff_s_axi_rresp,
        s_axi_rvalid  => outbuff_s_axi_rvalid,
        s_axi_rready  => outbuff_s_axi_rready
      );

    out_buff_data <= (others => '0');
    out_buff_trig <= '0';
    valid_debug   <= '0';
    last_debug    <= '0';
  end generate gen_outbuffer_disabled;
end architecture rtl;
