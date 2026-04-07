library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity legacy_core_readout_bridge is
port(
    link_id: std_logic_vector(5 downto 0);
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
    afe_dat_filtered: out array_40x14_type;
    S_AXI_ACLK: in std_logic;
    S_AXI_ARESETN: in std_logic;
    S_AXI_AWADDR: in std_logic_vector(31 downto 0);
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
    S_AXI_ARADDR: in std_logic_vector(31 downto 0);
    S_AXI_ARPROT: in std_logic_vector(2 downto 0);
    S_AXI_ARVALID: in std_logic;
    S_AXI_ARREADY: out std_logic;
    S_AXI_RDATA: out std_logic_vector(31 downto 0);
    S_AXI_RRESP: out std_logic_vector(1 downto 0);
    S_AXI_RVALID: out std_logic;
    S_AXI_RREADY: in std_logic;
    AXI_IN: in AXILITE_INREC;
    AXI_OUT: out AXILITE_OUTREC;
    eth_clk_p: in std_logic;
    eth_clk_n: in std_logic;
    eth0_rx_p: in std_logic_vector(0 downto 0);
    eth0_rx_n: in std_logic_vector(0 downto 0);
    eth0_tx_p: out std_logic_vector(0 downto 0);
    eth0_tx_n: out std_logic_vector(0 downto 0);
    eth0_tx_dis: out std_logic_vector(0 downto 0);
    out_buff_data: out array_2x64_type;
    out_buff_trig: out std_logic ;
    VALID_DEBUG: out std_logic_vector(1 downto 0);
    LAST_DEBUG: out std_logic_vector(1 downto 0)
);
end legacy_core_readout_bridge;

architecture rtl of legacy_core_readout_bridge is
  signal dout: array_2x64_type;
  signal valid, last: std_logic_vector(1 downto 0);
begin
  selftrig_core_inst: entity work.selftrig_core
  port map (
      clock  => clock,
      reset  => reset,
      reset_st_counters => reset_st_counters,
      version  => version (3 downto 0),
      filter_output_selector => filter_output_selector,
      afe_comp_enable => afe_comp_enable,
      invert_enable => invert_enable,
      st_config => st_config,
      signal_delay => signal_delay,
      timestamp  => timestamp,
      forcetrig  => forcetrig,
      enable  => enable,
      st_trigger_signal => st_trigger_signal,
      adhoc => adhoc,
      ti_trigger => ti_trigger,
      ti_trigger_stbr => ti_trigger_stbr,
      din  => din_core,
      dout  => dout,
      afe_dat_filtered => afe_dat_filtered,
      valid  => valid,
      last  => last,
      AXI_IN   => AXI_IN,
      AXI_OUT   => AXI_OUT
  );

  legacy_deimos_readout_bridge_inst : entity work.legacy_deimos_readout_bridge
    port map (
      s_axi_aclk_i => S_AXI_ACLK,
      s_axi_aresetn_i => S_AXI_ARESETN,
      s_axi_awaddr_i => S_AXI_AWADDR,
      s_axi_awprot_i => S_AXI_AWPROT,
      s_axi_awvalid_i => S_AXI_AWVALID,
      s_axi_awready_o => S_AXI_AWREADY,
      s_axi_wdata_i => S_AXI_WDATA,
      s_axi_wstrb_i => S_AXI_WSTRB,
      s_axi_wvalid_i => S_AXI_WVALID,
      s_axi_wready_o => S_AXI_WREADY,
      s_axi_bresp_o => S_AXI_BRESP,
      s_axi_bvalid_o => S_AXI_BVALID,
      s_axi_bready_i => S_AXI_BREADY,
      s_axi_araddr_i => S_AXI_ARADDR,
      s_axi_arprot_i => S_AXI_ARPROT,
      s_axi_arvalid_i => S_AXI_ARVALID,
      s_axi_arready_o => S_AXI_ARREADY,
      s_axi_rdata_o => S_AXI_RDATA,
      s_axi_rresp_o => S_AXI_RRESP,
      s_axi_rvalid_o => S_AXI_RVALID,
      s_axi_rready_i => S_AXI_RREADY,
      eth_clk_p_i => eth_clk_p,
      eth_clk_n_i => eth_clk_n,
      eth_rx_p_i => eth0_rx_p,
      eth_rx_n_i => eth0_rx_n,
      eth_tx_p_o => eth0_tx_p,
      eth_tx_n_o => eth0_tx_n,
      eth_tx_dis_o => eth0_tx_dis,
      dune_base_clk_i => clock,
      dune_base_rst_i => reset,
      data_clk_i => clock,
      data_clk_rst_i => reset,
      d_i => dout,
      valid_i => valid,
      last_i => last,
      timestamp_i => timestamp,
      ext_mac_addr_i => DEFAULT_ext_mac_addr_0,
      ext_ip_addr_i => DEFAULT_ext_ip_addr_0,
      ext_port_addr_i => DEFAULT_ext_port_addr_0
    );

  -- Keep the legacy debug trigger meaningful even though the readout data path is
  -- now split across the extracted selftrigger and Deimos bridges.
  out_buff_trig <= valid(0) or valid(1);
  out_buff_data <= dout;
  VALID_DEBUG   <= valid;
  LAST_DEBUG    <= last;
end architecture rtl;
