-- wib_top
--
-- Multiplexes data blocks from multiple sources onto ethernet UDP packet stream
--
-- This is the top level block for the WIB core, with interface compatible with the ip packager (no custom types, etc)
--
-- Dave Newbold, 2/1/23

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library deimos;
use work.addr_pkg.all;

library ipbus;
use work.ipbus.all;

use work.tx_mux_decl.all;
use work.freq_pkg.all;

entity daphne_top is
    generic (N_MGT: positive range 1 to 4 := 1; PACKET_WORDS: natural := 0; IN_BUF_DEPTH: positive := 2048);
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
        
        eth_rx_p: in  std_logic_vector(N_MGT-1 downto 0); -- Ethernet rx from SFP
        eth_rx_n: in  std_logic_vector(N_MGT-1 downto 0);
        eth_tx_p: out std_logic_vector(N_MGT-1 downto 0); -- Ethernet tx to SFP
        eth_tx_n: out std_logic_vector(N_MGT-1 downto 0);
        eth_tx_dis: out std_logic_vector(N_MGT-1 downto 0); -- SFP tx_disable
    
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

        d2: in std_logic_vector(63 downto 0) := (others => '0');
        d2_valid: in std_logic := '0';
        d2_last: in std_logic := '0';
        d3: in std_logic_vector(63 downto 0) := (others => '0');
        d3_valid: in std_logic := '0';
        d3_last: in std_logic := '0';
        d4: in std_logic_vector(63 downto 0) := (others => '0');
        d4_valid: in std_logic := '0';
        d4_last: in std_logic := '0';
        d5: in std_logic_vector(63 downto 0) := (others => '0');
        d5_valid: in std_logic := '0';
        d5_last: in std_logic := '0';
        d6: in std_logic_vector(63 downto 0) := (others => '0');
        d6_valid: in std_logic := '0';
        d6_last: in std_logic := '0';
        d7: in std_logic_vector(63 downto 0) := (others => '0');
        d7_valid: in std_logic := '0';
        d7_last: in std_logic := '0';
        packet_ready: out std_logic_vector(2*N_MGT-1 downto 0) := (others => '0');

        ts : in std_logic_vector(63 downto 0);
        
        ext_mac_addr    : in std_logic_vector(47 downto 0);
        ext_ip_addr     : in std_logic_vector(31 downto 0);
        ext_port_addr   : in std_logic_vector(15 downto 0)
    );         
end entity daphne_top;

architecture rtl of daphne_top is

    signal sources: array_of_src_d_arrays(N_MGT-1 downto 0)(1 downto 0);
    signal flat_sources: src_d_array(7 downto 0);
    signal mac_addresses: mac_addr_array(N_MGT-1 downto 0);
    signal ip_addresses: ip_addr_array(N_MGT-1 downto 0);
    signal port_addresses: udp_port_array(N_MGT-1 downto 0);
    signal ipbw: ipb_wbus;
    signal ipbr: ipb_rbus;
    signal ipb_clk, ipb_rst: std_logic;
    signal nuke, soft_rst: std_logic;
    constant C_S_AXI_ADDR_WIDTH: integer := 16;
    
begin

    flat_sources(0) <= (d0, d0_valid, d0_last);
    flat_sources(1) <= (d1, d1_valid, d1_last);
    flat_sources(2) <= (d2, d2_valid, d2_last);
    flat_sources(3) <= (d3, d3_valid, d3_last);
    flat_sources(4) <= (d4, d4_valid, d4_last);
    flat_sources(5) <= (d5, d5_valid, d5_last);
    flat_sources(6) <= (d6, d6_valid, d6_last);
    flat_sources(7) <= (d7, d7_valid, d7_last);
    links: for i in 0 to N_MGT-1 generate
        sources(i)(0) <= flat_sources(2*i);
        sources(i)(1) <= flat_sources(2*i+1);
        -- Preserve link0 identity; each additional physical interface is unique.
        mac_addresses(i) <= std_logic_vector(unsigned(ext_mac_addr) + i);
        ip_addresses(i) <= std_logic_vector(unsigned(ext_ip_addr) + i);
        port_addresses(i) <= ext_port_addr;
    end generate;

    ipb_ctrl : entity work.ipb_axi4_lite_ctrl
        port map (
            aclk => S_AXI_ACLK,
            aresetn => S_AXI_ARESETN,
            axi_in.awaddr(31 downto C_S_AXI_ADDR_WIDTH) => (others => '0'),
            axi_in.awaddr(C_S_AXI_ADDR_WIDTH - 1 downto 0) => S_AXI_AWADDR,
            axi_in.awprot => S_AXI_AWPROT,
            axi_in.awvalid => S_AXI_AWVALID,
            axi_in.wdata => S_AXI_WDATA,
            axi_in.wstrb => S_AXI_WSTRB,
            axi_in.wvalid => S_AXI_WVALID,
            axi_in.bready => S_AXI_BREADY,
            axi_in.araddr(31 downto C_S_AXI_ADDR_WIDTH) => (others => '0'),
            axi_in.araddr(C_S_AXI_ADDR_WIDTH - 1 downto 0) => S_AXI_ARADDR,     
            axi_in.arprot => S_AXI_ARPROT,
            axi_in.arvalid => S_AXI_ARVALID,
            axi_in.rready => S_AXI_RREADY,
            axi_out.awready => S_AXI_AWREADY,
            axi_out.wready => S_AXI_WREADY,
            axi_out.bresp => S_AXI_BRESP,
            axi_out.bvalid => S_AXI_BVALID,
            axi_out.arready => S_AXI_ARREADY,
            axi_out.rdata => S_AXI_RDATA,
            axi_out.rresp => S_AXI_RRESP,
            axi_out.rvalid => S_AXI_RVALID,

            ipb_clk => ipb_clk,
            ipb_rst => ipb_rst,
            ipb_in => ipbr,
            ipb_out => ipbw,
            nuke =>  nuke,
            soft_rst => soft_rst
            );

    mux: entity work.eth_readout
        generic map(
            N_SRC => 2,
            N_MGT => N_MGT,
            PACKET_WORDS => PACKET_WORDS,
            REF_FREQ => f156_25,
            IN_BUF_DEPTH => IN_BUF_DEPTH
        )
        port map(
            ipb_clk                => ipb_clk,
            ipb_rst                => ipb_rst,
            ipb_in                 => ipbw,
            ipb_out                => ipbr,
            nuke                   => nuke,
            soft_rst               => soft_rst,
            
            eth_rx_p               => eth_rx_p,
            eth_rx_n               => eth_rx_n,
            eth_tx_p               => eth_tx_p, 
            eth_tx_n               => eth_tx_n,
            eth_tx_dis             => eth_tx_dis,

            eth_clk_p              => eth_clk_p,
            eth_clk_n              => eth_clk_n,
            
            dune_base_clk          => dune_base_clk,
            dune_base_rst          => dune_base_rst,
            ts                     => ts,
            
            data_clk               => data_clk,
            data_clk_rst           => data_clk_rst,
            d                      => sources,
            packet_ready           => packet_ready,
            ext_mac_addr           => mac_addresses,
            ext_ip_addr            => ip_addresses,
            ext_port_addr          => port_addresses
        );

end architecture rtl;
