-- core.vhd
-- 40 channel self triggered senders + selection logic + single channel 10G Ethernet sender
-- for daphne_selftrigger_top
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;

entity core is 
port(
    link_id: std_logic_vector(5 downto 0); -- static header data
    slot_id: in std_logic_vector(3 downto 0);
    crate_id: in std_logic_vector(9 downto 0);
    detector_id: in std_logic_vector(5 downto 0);
    version: in std_logic_vector(5 downto 0);
    filter_output_selector: in std_logic_vector(1 downto 0); --Esteban
    afe_comp_enable: in std_logic_vector(39 downto 0);
    invert_enable: in std_logic_vector(39 downto 0);
    st_config: in std_logic_vector(13 downto 0); -- Config param for Self-Trigger and Local Primitive Calculation, CIEMAT (Nacho)
    signal_delay: in std_logic_vector(4 downto 0);
    --DEFAULT_ext_mac_addr_0:in std_logic_vector (47 downto 0); -- Ethernet defaults point up to generics for now
    --DEFAULT_ext_ip_addr_0:in std_logic_vector (31 downto 0);
    --DEFAULT_ext_port_addr_0:in std_logic_vector (15 downto 0);

    clock: in std_logic; -- master clock 62.5MHz
    reset: in std_logic; -- sync to clock
    reset_st_counters: in std_logic;
    timestamp: in std_logic_vector(63 downto 0); -- timestamp sync to clock
    enable: in std_logic_vector(39 downto 0); -- self trig sender channel enables
    forcetrig: in std_logic; -- momentary pulse to force all enabled senders to trigger
    st_trigger_signal: out std_logic_vector(39 downto 0);
    adhoc: in std_logic_vector(7 downto 0); -- command value for adhoc trigger
    ti_trigger: in std_logic_vector(7 downto 0);
    ti_trigger_stbr: in std_logic;
    -- threshold: in std_logic_vector(9 downto 0); -- counts below calculated baseline
    din_core: in array_5x9x16_type;
    afe_dat_filtered: out array_40x14_type; -- aligned AFE data filtered 
   -- afe_data0: in std_logic_vector(13 downto 0);
    --afe_data1: in std_logic_vector(13 downto 0);
    --afe_data2: in std_logic_vector(13 downto 0);
    --afe_data3: in std_logic_vector(13 downto 0);
    --afe_data4: in std_logic_vector(13 downto 0);
    --afe_data5: in std_logic_vector(13 downto 0);
    --afe_data6: in std_logic_vector(13 downto 0);
    --afe_data7: in std_logic_vector(13 downto 0);
    --afe_data8: in std_logic_vector(13 downto 0);
    --afe_data9: in std_logic_vector(13 downto 0);
    --afe_data10: in std_logic_vector(13 downto 0);
    --afe_data11: in std_logic_vector(13 downto 0);
    --afe_data12: in std_logic_vector(13 downto 0);
    --afe_data13: in std_logic_vector(13 downto 0);
    --afe_data14: in std_logic_vector(13 downto 0);
    --afe_data15: in std_logic_vector(13 downto 0);
    --afe_data16: in std_logic_vector(13 downto 0);
    --afe_data17: in std_logic_vector(13 downto 0);
    --afe_data18: in std_logic_vector(13 downto 0);
    --afe_data19: in std_logic_vector(13 downto 0);
    --afe_data20: in std_logic_vector(13 downto 0);
    --afe_data21: in std_logic_vector(13 downto 0);
    --afe_data22: in std_logic_vector(13 downto 0);
    --afe_data23: in std_logic_vector(13 downto 0);
    --afe_data24: in std_logic_vector(13 downto 0);
    --afe_data25: in std_logic_vector(13 downto 0);
    --afe_data26: in std_logic_vector(13 downto 0);
    --afe_data27: in std_logic_vector(13 downto 0);
    --afe_data28: in std_logic_vector(13 downto 0);
    --afe_data29: in std_logic_vector(13 downto 0);
    --afe_data30: in std_logic_vector(13 downto 0);
    --afe_data31: in std_logic_vector(13 downto 0);
    --afe_data32: in std_logic_vector(13 downto 0);
    --afe_data33: in std_logic_vector(13 downto 0);
    --afe_data34: in std_logic_vector(13 downto 0);
    --afe_data35: in std_logic_vector(13 downto 0);
    --afe_data36: in std_logic_vector(13 downto 0);
    --afe_data37: in std_logic_vector(13 downto 0);
    --afe_data38: in std_logic_vector(13 downto 0);
    --afe_data39: in std_logic_vector(13 downto 0);
 
    S_AXI_ACLK: in std_logic; -- 10G Ethernet sender AXI-Lite interface
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
     
     --threshold axi
     
     
    AXI_IN: in AXILITE_INREC;
    AXI_OUT: out AXILITE_OUTREC;
    
    eth_clk_p: in std_logic; -- external MGT refclk LVDS 156.25MHz
    eth_clk_n: in std_logic; 

    eth0_rx_p: in std_logic_vector(0 downto 0); -- external SFP+ transceiver
    eth0_rx_n: in std_logic_vector(0 downto 0);
    eth0_tx_p: out std_logic_vector(0 downto 0);
    eth0_tx_n: out std_logic_vector(0 downto 0);
    eth0_tx_dis: out std_logic_vector(0 downto 0);
    
        --output_spybuff-----
    out_buff_data: out array_2x64_type;
    out_buff_trig: out std_logic ;
     VALID_DEBUG: out  std_logic_vector(1 downto 0);
     LAST_DEBUG: out  std_logic_vector(1 downto 0)
);
end core;

architecture core_arch of core is
signal dout: array_2x64_type;
signal valid, last: std_logic_vector(1 downto 0);
begin
  selftrig_core_inst : entity work.selftrig_core
    port map (
      clock                 => clock,
      reset                 => reset,
      reset_st_counters     => reset_st_counters,
      version               => version(3 downto 0),
      filter_output_selector => filter_output_selector,
      afe_comp_enable       => afe_comp_enable,
      invert_enable         => invert_enable,
      st_config             => st_config,
      signal_delay          => signal_delay,
      timestamp             => timestamp,
      forcetrig             => forcetrig,
      enable                => enable,
      st_trigger_signal     => st_trigger_signal,
      adhoc                 => adhoc,
      ti_trigger            => ti_trigger,
      ti_trigger_stbr       => ti_trigger_stbr,
      din                   => din_core,
      dout                  => dout,
      afe_dat_filtered      => afe_dat_filtered,
      valid                 => valid,
      last                  => last,
      AXI_IN                => AXI_IN,
      AXI_OUT               => AXI_OUT
    );

  legacy_deimos_readout_bridge_inst : entity work.legacy_deimos_readout_bridge
    port map (
      s_axi_aclk_i    => S_AXI_ACLK,
      s_axi_aresetn_i => S_AXI_ARESETN,
      s_axi_awaddr_i  => S_AXI_AWADDR,
      s_axi_awprot_i  => S_AXI_AWPROT,
      s_axi_awvalid_i => S_AXI_AWVALID,
      s_axi_awready_o => S_AXI_AWREADY,
      s_axi_wdata_i   => S_AXI_WDATA,
      s_axi_wstrb_i   => S_AXI_WSTRB,
      s_axi_wvalid_i  => S_AXI_WVALID,
      s_axi_wready_o  => S_AXI_WREADY,
      s_axi_bresp_o   => S_AXI_BRESP,
      s_axi_bvalid_o  => S_AXI_BVALID,
      s_axi_bready_i  => S_AXI_BREADY,
      s_axi_araddr_i  => S_AXI_ARADDR,
      s_axi_arprot_i  => S_AXI_ARPROT,
      s_axi_arvalid_i => S_AXI_ARVALID,
      s_axi_arready_o => S_AXI_ARREADY,
      s_axi_rdata_o   => S_AXI_RDATA,
      s_axi_rresp_o   => S_AXI_RRESP,
      s_axi_rvalid_o  => S_AXI_RVALID,
      s_axi_rready_i  => S_AXI_RREADY,
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
      d_i             => dout,
      valid_i         => valid,
      last_i          => last,
      timestamp_i     => timestamp,
      ext_mac_addr_i  => DEFAULT_ext_mac_addr_0,
      ext_ip_addr_i   => DEFAULT_ext_ip_addr_0,
      ext_port_addr_i => DEFAULT_ext_port_addr_0
    );

  out_buff_trig <= valid(0) or valid(1);
  out_buff_data <= dout;
  VALID_DEBUG   <= valid;
  LAST_DEBUG    <= last;
end core_arch;
