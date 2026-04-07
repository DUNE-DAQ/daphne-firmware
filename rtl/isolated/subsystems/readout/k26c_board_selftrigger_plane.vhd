library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity k26c_board_selftrigger_plane is
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
end k26c_board_selftrigger_plane;

architecture rtl of k26c_board_selftrigger_plane is
  signal out_buff_data_reg:  array_2x64_type;
  signal valid_debug_reg:    std_logic_vector(1 downto 0);
  signal last_debug_reg:     std_logic_vector(1 downto 0);
begin
  datapath_plane_inst : entity work.k26c_selftrigger_datapath_plane
    port map(
      version                => version,
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
      din_core               => din_core,
      thresh_s_axi_aclk      => thresh_s_axi_aclk,
      thresh_s_axi_aresetn   => thresh_s_axi_aresetn,
      thresh_s_axi_awaddr    => thresh_s_axi_awaddr,
      thresh_s_axi_awprot    => thresh_s_axi_awprot,
      thresh_s_axi_awvalid   => thresh_s_axi_awvalid,
      thresh_s_axi_awready   => thresh_s_axi_awready,
      thresh_s_axi_wdata     => thresh_s_axi_wdata,
      thresh_s_axi_wstrb     => thresh_s_axi_wstrb,
      thresh_s_axi_wvalid    => thresh_s_axi_wvalid,
      thresh_s_axi_wready    => thresh_s_axi_wready,
      thresh_s_axi_bresp     => thresh_s_axi_bresp,
      thresh_s_axi_bvalid    => thresh_s_axi_bvalid,
      thresh_s_axi_bready    => thresh_s_axi_bready,
      thresh_s_axi_araddr    => thresh_s_axi_araddr,
      thresh_s_axi_arprot    => thresh_s_axi_arprot,
      thresh_s_axi_arvalid   => thresh_s_axi_arvalid,
      thresh_s_axi_arready   => thresh_s_axi_arready,
      thresh_s_axi_rdata     => thresh_s_axi_rdata,
      thresh_s_axi_rresp     => thresh_s_axi_rresp,
      thresh_s_axi_rvalid    => thresh_s_axi_rvalid,
      thresh_s_axi_rready    => thresh_s_axi_rready,
      readout_data_o         => out_buff_data_reg,
      readout_valid_o        => valid_debug_reg,
      readout_last_o         => last_debug_reg
    );

  transport_plane_inst : entity work.k26c_board_transport_plane
    port map(
      clock                => clock,
      reset                => reset,
      timestamp            => timestamp,
      trirg_s_axi_aclk     => trirg_s_axi_aclk,
      trirg_s_axi_aresetn  => trirg_s_axi_aresetn,
      trirg_s_axi_awaddr   => trirg_s_axi_awaddr,
      trirg_s_axi_awprot   => trirg_s_axi_awprot,
      trirg_s_axi_awvalid  => trirg_s_axi_awvalid,
      trirg_s_axi_awready  => trirg_s_axi_awready,
      trirg_s_axi_wdata    => trirg_s_axi_wdata,
      trirg_s_axi_wstrb    => trirg_s_axi_wstrb,
      trirg_s_axi_wvalid   => trirg_s_axi_wvalid,
      trirg_s_axi_wready   => trirg_s_axi_wready,
      trirg_s_axi_bresp    => trirg_s_axi_bresp,
      trirg_s_axi_bvalid   => trirg_s_axi_bvalid,
      trirg_s_axi_bready   => trirg_s_axi_bready,
      trirg_s_axi_araddr   => trirg_s_axi_araddr,
      trirg_s_axi_arprot   => trirg_s_axi_arprot,
      trirg_s_axi_arvalid  => trirg_s_axi_arvalid,
      trirg_s_axi_arready  => trirg_s_axi_arready,
      trirg_s_axi_rdata    => trirg_s_axi_rdata,
      trirg_s_axi_rresp    => trirg_s_axi_rresp,
      trirg_s_axi_rvalid   => trirg_s_axi_rvalid,
      trirg_s_axi_rready   => trirg_s_axi_rready,
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
      eth_clk_p            => eth_clk_p,
      eth_clk_n            => eth_clk_n,
      eth0_rx_p            => eth0_rx_p,
      eth0_rx_n            => eth0_rx_n,
      eth0_tx_p            => eth0_tx_p,
      eth0_tx_n            => eth0_tx_n,
      eth0_tx_dis          => eth0_tx_dis,
      readout_data_i       => out_buff_data_reg,
      readout_valid_i      => valid_debug_reg,
      readout_last_i       => last_debug_reg,
      out_buff_data        => out_buff_data,
      out_buff_trig        => out_buff_trig,
      valid_debug          => valid_debug,
      last_debug           => last_debug
    );
end architecture rtl;
