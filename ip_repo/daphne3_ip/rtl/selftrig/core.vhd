-- core.vhd
-- 40 channel self triggered senders + selection logic + single channel 10G Ethernet sender
-- for DAPHNE3 / DAPHNE_MEZZ
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne3_package.all;

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



component daphne_top -- single output 10G Ethernet sender
    port(
        S_AXI_ACLK: in std_logic;
        S_AXI_ARESETN: in std_logic;
        S_AXI_AWADDR: in std_logic_vector(15 downto 0);
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
        S_AXI_ARADDR: in std_logic_vector(15 downto 0);
        S_AXI_ARPROT: in std_logic_vector(2 downto 0);
        S_AXI_ARVALID: in std_logic;
        S_AXI_ARREADY: out std_logic;
        S_AXI_RDATA: out std_logic_vector(31 downto 0);
        S_AXI_RRESP: out std_logic_vector(1 downto 0);
        S_AXI_RVALID: out std_logic;
        S_AXI_RREADY: in std_logic;
        
        eth_rx_p: in  std_logic_vector(0 downto 0); -- Ethernet rx from SFP
        eth_rx_n: in  std_logic_vector(0 downto 0);
        eth_tx_p: out std_logic_vector(0 downto 0); -- Ethernet tx to SFP
        eth_tx_n: out std_logic_vector(0 downto 0);
        eth_tx_dis: out std_logic_vector(0 downto 0); -- SFP tx_disable
    
        eth_clk_p: in std_logic; -- Transceiver refclk
        eth_clk_n: in std_logic;
        
        dune_base_clk: in std_logic; -- DUNE base clock
        dune_base_rst: in std_logic; -- DUNE base clock sync reset

        data_clk: in std_logic; 
        data_clk_rst: in std_logic;
        
        d0: in std_logic_vector(63 downto 0);
        d0_valid: in std_logic;
        d0_last: in std_logic;
        
        d1: in std_logic_vector(63 downto 0);
        d1_valid: in std_logic;
        d1_last: in std_logic;

        ts : in std_logic_vector(63 downto 0);
        
        ext_mac_addr    : in std_logic_vector(47 downto 0);
        ext_ip_addr     : in std_logic_vector(31 downto 0);
        ext_port_addr   : in std_logic_vector(15 downto 0)
    );         
end component;

signal din: array_40x14_type;
signal dout: array_2x64_type;
signal valid, last: std_logic_vector(1 downto 0);
--signal thresholds:array_40x10_type;
--signal    AXI_IN:  AXILITE_INREC;
--signal    AXI_OUT:  AXILITE_OUTREC;
begin

-- make input bus array

--din(0) <= afe_data0;
--din(1) <= afe_data1;
--din(2) <= afe_data2;
--din(3) <= afe_data3; 
--din(4) <= afe_data4;
--din(5) <= afe_data5;
--din(6) <= afe_data6;
--din(7) <= afe_data7;
--din(8) <= afe_data8;
--din(9) <= afe_data9;

--din(10) <= afe_data10;
--din(11) <= afe_data11;
--din(12) <= afe_data12;
--din(13) <= afe_data13;
--din(14) <= afe_data14;
--din(15) <= afe_data15;
--din(16) <= afe_data16;
--din(17) <= afe_data17;
--din(18) <= afe_data18;
--din(19) <= afe_data19;

--din(20) <= afe_data20;
--din(21) <= afe_data21;
--din(22) <= afe_data22;
--din(23) <= afe_data23;
--din(24) <= afe_data24;
--din(25) <= afe_data25;
--din(26) <= afe_data26;
--din(27) <= afe_data27;
--din(28) <= afe_data28;
--din(29) <= afe_data29;

--din(30) <= afe_data30;
--din(31) <= afe_data31;
--din(32) <= afe_data32;
--din(33) <= afe_data33;
--din(34) <= afe_data34;
--din(35) <= afe_data35;
--din(36) <= afe_data36;
--din(37) <= afe_data37;
--din(38) <= afe_data38;
--din(39) <= afe_data39;


-- selftrig core



-- 40 self-triggered sender machines + selection logic
selftrig_core_inst: entity work.selftrig_core
port map (
    clock  => clock,  -- main clock 62.5 MHz
    reset  => reset,
    reset_st_counters => reset_st_counters,
    version  => version (3 downto 0),
    filter_output_selector => filter_output_selector, --Esteban
    afe_comp_enable => afe_comp_enable,
    invert_enable => invert_enable,
    st_config => st_config, -- Config param for Self-Trigger and Local Primitive Calculation, CIEMAT (Nacho)
    signal_delay => signal_delay,
    timestamp  => timestamp,
    forcetrig  => forcetrig,
    st_trigger_signal => st_trigger_signal,
    adhoc => adhoc,
    ti_trigger => ti_trigger,
    ti_trigger_stbr => ti_trigger_stbr,
	din  => din_core , -- 45 AFE channels feed into this module
    dout  => dout,
    afe_dat_filtered => afe_dat_filtered,
    valid  => valid,
    last  => last,
    AXI_IN   => AXI_IN,
    AXI_OUT   => AXI_OUT  
    
);




-- single output 10G Ethernet sender

daphne_top_inst: daphne_top 
    port map(
        S_AXI_ACLK => S_AXI_ACLK,  -- AXI-Lite interface
        S_AXI_ARESETN => S_AXI_ARESETN,
        S_AXI_AWADDR => S_AXI_AWADDR(15 downto 0),
        S_AXI_AWPROT => S_AXI_AWPROT,
        S_AXI_AWVALID => S_AXI_AWVALID,
        S_AXI_AWREADY => S_AXI_AWREADY,
        S_AXI_WDATA => S_AXI_WDATA,
        S_AXI_WSTRB => S_AXI_WSTRB,
        S_AXI_WVALID => S_AXI_WVALID,
        S_AXI_WREADY => S_AXI_WREADY,
        S_AXI_BRESP => S_AXI_BRESP,
        S_AXI_BVALID => S_AXI_BVALID,
        S_AXI_BREADY => S_AXI_BREADY,
        S_AXI_ARADDR => S_AXI_ARADDR(15 downto 0),
        S_AXI_ARPROT => S_AXI_ARPROT,
        S_AXI_ARVALID => S_AXI_ARVALID,
        S_AXI_ARREADY => S_AXI_ARREADY, 
        S_AXI_RDATA => S_AXI_RDATA,
        S_AXI_RRESP => S_AXI_RRESP,
        S_AXI_RVALID => S_AXI_RVALID,
        S_AXI_RREADY => S_AXI_RREADY,

        eth_rx_p => eth0_rx_p, -- external SFP+ transceiver
        eth_rx_n => eth0_rx_n,
        eth_tx_p => eth0_tx_p,
        eth_tx_n => eth0_tx_n,
        eth_tx_dis => eth0_tx_dis,

        eth_clk_p => eth_clk_p, -- external MGT refclk LVDS 156.25MHz
        eth_clk_n => eth_clk_n,

        dune_base_clk => clock,-- DUNE base clock
        dune_base_rst =>reset,  -- DUNE base clock sync reset

        data_clk => clock,
        data_clk_rst =>  reset,

        d0 => dout(0),
        d0_valid => valid(0),
        d0_last => last(0),
        d1 => dout(1),
        d1_valid => valid(1),
        d1_last => last(1),

        ts => timestamp,

        ext_mac_addr => DEFAULT_ext_mac_addr_0, -- Ethernet defaults point up to generics for now
        ext_ip_addr => DEFAULT_ext_ip_addr_0,
        ext_port_addr => DEFAULT_ext_port_addr_0
    );         

    out_buff_data <= dout;
     VALID_DEBUG   <= valid ;
     LAST_DEBUG    <= last;  
  

end core_arch;
