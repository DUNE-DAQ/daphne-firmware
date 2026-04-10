library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity legacy_selftrigger_plane_bridge is
port(
    link_id: in std_logic_vector(5 downto 0);
    slot_id: in std_logic_vector(3 downto 0);
    crate_id: in std_logic_vector(9 downto 0);
    detector_id: in std_logic_vector(5 downto 0);
    version: in std_logic_vector(5 downto 0);
    filter_output_selector: in std_logic_vector(1 downto 0);
    afe_comp_enable: in std_logic_vector(39 downto 0);
    invert_enable: in std_logic_vector(39 downto 0);
    st_config: in std_logic_vector(13 downto 0);
    signal_delay: in std_logic_vector(4 downto 0);
    clock: in std_logic;
    reset: in std_logic;
    reset_st_counters: in std_logic;
    timestamp: in std_logic_vector(63 downto 0);
    enable: in std_logic_vector(39 downto 0);
    forcetrig: in std_logic;
    st_trigger_signal: out std_logic_vector(39 downto 0);
    adhoc: in std_logic_vector(7 downto 0);
    ti_trigger: in std_logic_vector(7 downto 0);
    ti_trigger_stbr: in std_logic;
    din_core: in array_5x9x16_type;

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

    thresh_s_axi_aclk: in std_logic;
    thresh_s_axi_aresetn: in std_logic;
    thresh_s_axi_awaddr: in std_logic_vector(31 downto 0);
    thresh_s_axi_awprot: in std_logic_vector(2 downto 0);
    thresh_s_axi_awvalid: in std_logic;
    thresh_s_axi_awready: out std_logic;
    thresh_s_axi_wdata: in std_logic_vector(31 downto 0);
    thresh_s_axi_wstrb: in std_logic_vector(3 downto 0);
    thresh_s_axi_wvalid: in std_logic;
    thresh_s_axi_wready: out std_logic;
    thresh_s_axi_bresp: out std_logic_vector(1 downto 0);
    thresh_s_axi_bvalid: out std_logic;
    thresh_s_axi_bready: in std_logic;
    thresh_s_axi_araddr: in std_logic_vector(31 downto 0);
    thresh_s_axi_arprot: in std_logic_vector(2 downto 0);
    thresh_s_axi_arvalid: in std_logic;
    thresh_s_axi_arready: out std_logic;
    thresh_s_axi_rdata: out std_logic_vector(31 downto 0);
    thresh_s_axi_rresp: out std_logic_vector(1 downto 0);
    thresh_s_axi_rvalid: out std_logic;
    thresh_s_axi_rready: in std_logic;

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

    out_buff_data: out std_logic_vector(63 downto 0);
    out_buff_trig: out std_logic;
    valid_debug: out std_logic;
    last_debug: out std_logic
);
end legacy_selftrigger_plane_bridge;

architecture rtl of legacy_selftrigger_plane_bridge is
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

  signal threshold_axi_in:   AXILITE_INREC;
  signal threshold_axi_out:  AXILITE_OUTREC;
  signal outbuff_axi_in:     AXILITE_INREC;
  signal outbuff_axi_out:    AXILITE_OUTREC;
  signal out_buff_data_reg:  array_2x64_type;
  signal valid_debug_reg:    std_logic_vector(1 downto 0);
  signal last_debug_reg:     std_logic_vector(1 downto 0);
begin
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

  threshold_axi_in.ACLK    <= thresh_s_axi_aclk;
  threshold_axi_in.ARESETN <= thresh_s_axi_aresetn;
  threshold_axi_in.AWADDR  <= thresh_s_axi_awaddr;
  threshold_axi_in.AWPROT  <= thresh_s_axi_awprot;
  threshold_axi_in.AWVALID <= thresh_s_axi_awvalid;
  threshold_axi_in.WDATA   <= thresh_s_axi_wdata;
  threshold_axi_in.WSTRB   <= thresh_s_axi_wstrb;
  threshold_axi_in.WVALID  <= thresh_s_axi_wvalid;
  threshold_axi_in.BREADY  <= thresh_s_axi_bready;
  threshold_axi_in.ARADDR  <= thresh_s_axi_araddr;
  threshold_axi_in.ARPROT  <= thresh_s_axi_arprot;
  threshold_axi_in.ARVALID <= thresh_s_axi_arvalid;
  threshold_axi_in.RREADY  <= thresh_s_axi_rready;

  thresh_s_axi_awready <= threshold_axi_out.AWREADY;
  thresh_s_axi_wready  <= threshold_axi_out.WREADY;
  thresh_s_axi_bresp   <= threshold_axi_out.BRESP;
  thresh_s_axi_bvalid  <= threshold_axi_out.BVALID;
  thresh_s_axi_arready <= threshold_axi_out.ARREADY;
  thresh_s_axi_rdata   <= threshold_axi_out.RDATA;
  thresh_s_axi_rresp   <= threshold_axi_out.RRESP;
  thresh_s_axi_rvalid  <= threshold_axi_out.RVALID;

  outbuff_axi_in.ACLK    <= outbuff_s_axi_aclk;
  outbuff_axi_in.ARESETN <= outbuff_s_axi_aresetn;
  outbuff_axi_in.AWADDR  <= outbuff_s_axi_awaddr;
  outbuff_axi_in.AWPROT  <= outbuff_s_axi_awprot;
  outbuff_axi_in.AWVALID <= outbuff_s_axi_awvalid;
  outbuff_axi_in.WDATA   <= outbuff_s_axi_wdata;
  outbuff_axi_in.WSTRB   <= outbuff_s_axi_wstrb;
  outbuff_axi_in.WVALID  <= outbuff_s_axi_wvalid;
  outbuff_axi_in.BREADY  <= outbuff_s_axi_bready;
  outbuff_axi_in.ARADDR  <= outbuff_s_axi_araddr;
  outbuff_axi_in.ARPROT  <= outbuff_s_axi_arprot;
  outbuff_axi_in.ARVALID <= outbuff_s_axi_arvalid;
  outbuff_axi_in.RREADY  <= outbuff_s_axi_rready;

  outbuff_s_axi_awready <= outbuff_axi_out.AWREADY;
  outbuff_s_axi_wready  <= outbuff_axi_out.WREADY;
  outbuff_s_axi_bresp   <= outbuff_axi_out.BRESP;
  outbuff_s_axi_bvalid  <= outbuff_axi_out.BVALID;
  outbuff_s_axi_arready <= outbuff_axi_out.ARREADY;
  outbuff_s_axi_rdata   <= outbuff_axi_out.RDATA;
  outbuff_s_axi_rresp   <= outbuff_axi_out.RRESP;
  outbuff_s_axi_rvalid  <= outbuff_axi_out.RVALID;

  legacy_selftrigger_core_bridge_inst : entity work.legacy_selftrigger_core_bridge
    port map(
      version                => version(3 downto 0),
      filter_output_selector => filter_output_selector,
      afe_comp_enable        => afe_comp_enable,
      invert_enable          => invert_enable,
      st_config              => st_config,
      signal_delay           => signal_delay,
      clock                  => clock,
      reset                  => reset,
      reset_st_counters      => reset_st_counters,
      timestamp              => timestamp,
      enable                 => enable,
      forcetrig              => forcetrig,
      st_trigger_signal      => st_trigger_signal,
      adhoc                  => adhoc,
      ti_trigger             => ti_trigger,
      ti_trigger_stbr        => ti_trigger_stbr,
      din                    => din_core,
      dout                   => out_buff_data_reg,
      afe_dat_filtered       => open,
      AXI_IN                 => threshold_axi_in,
      AXI_OUT                => threshold_axi_out,
      valid                  => valid_debug_reg,
      last                   => last_debug_reg
    );

  legacy_selftrigger_output_bridge_inst : entity work.legacy_selftrigger_output_bridge
    port map(
      s_axi_aclk_i    => trirg_s_axi_aclk,
      s_axi_aresetn_i => trirg_s_axi_aresetn,
      s_axi_awaddr_i  => core_axi_awaddr,
      s_axi_awprot_i  => core_axi_awprot,
      s_axi_awvalid_i => core_axi_awvalid,
      s_axi_awready_o => core_axi_awready,
      s_axi_wdata_i   => core_axi_wdata,
      s_axi_wstrb_i   => core_axi_wstrb,
      s_axi_wvalid_i  => core_axi_wvalid,
      s_axi_wready_o  => core_axi_wready,
      s_axi_bresp_o   => core_axi_bresp,
      s_axi_bvalid_o  => core_axi_bvalid,
      s_axi_bready_i  => core_axi_bready,
      s_axi_araddr_i  => core_axi_araddr,
      s_axi_arprot_i  => core_axi_arprot,
      s_axi_arvalid_i => core_axi_arvalid,
      s_axi_arready_o => core_axi_arready,
      s_axi_rdata_o   => core_axi_rdata,
      s_axi_rresp_o   => core_axi_rresp,
      s_axi_rvalid_o  => core_axi_rvalid,
      s_axi_rready_i  => core_axi_rready,
      eth_clk_p_i     => eth_clk_p,
      eth_clk_n_i     => eth_clk_n,
      eth0_rx_p_i     => eth0_rx_p,
      eth0_rx_n_i     => eth0_rx_n,
      eth0_tx_p_o     => eth0_tx_p,
      eth0_tx_n_o     => eth0_tx_n,
      eth0_tx_dis_o   => eth0_tx_dis,
      clock_i         => clock,
      reset_i         => reset,
      data_i          => out_buff_data_reg,
      valid_i         => valid_debug_reg,
      last_i          => last_debug_reg,
      timestamp_i     => timestamp,
      outbuff_axi_in  => outbuff_axi_in,
      outbuff_axi_out => outbuff_axi_out,
      out_buff_data_o => out_buff_data,
      out_buff_trig_o => out_buff_trig,
      valid_debug_o   => valid_debug,
      last_debug_o    => last_debug
    );
end architecture rtl;
