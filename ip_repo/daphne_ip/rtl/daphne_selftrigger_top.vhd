-- daphne_selftrigger_top.vhd
--
-- Kria PL TOP LEVEL. This REPLACES the top level graphical block.
--
-- Build this with the TCL script from the command line (aka Vivado NON PROJECT MODE)
-- see the github README file for details

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;  

library unisim;
use unisim.vcomponents.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity daphne_selftrigger_top is
generic(
    version: std_logic_vector(27 downto 0) := X"1234567" ;  -- firmware firsion
    link_id: std_logic_vector(5 downto 0) := "000000";
    slot_id: std_logic_vector(3 downto 0) := X"2";
    crate_id: std_logic_vector(9 downto 0) := "0000000011";
    detector_id: std_logic_vector(5 downto 0) := "000010";
    -- threshold: in std_logic_vector(9 downto 0):= "1000000000";
    version_id: std_logic_vector(5 downto 0) := "000001");  -- build virsion - to be updated everytime we build a new image
port(
            
          
    -- misc PL external connections
    sysclk100:   in std_logic;
    sysclk_p, sysclk_n: in  std_logic; -- 100MHz system clock from the clock generator chip (LVDS)
    fan_tach: in std_logic_vector(1 downto 0); -- fan tach speed sensors
    fan_ctrl: out std_logic; -- pwm fan speed control
    stat_led: out std_logic_vector(5 downto 0); -- general status LEDs
    hvbias_en: out std_logic; -- enable HV bias source
    mux_en: out std_logic_vector(1 downto 0); -- analog mux enables
    mux_a: out std_logic_vector(1 downto 0); -- analog mux addr selects

    -- optical timing endpoint interface signals

    sfp_tmg_los: in std_logic; -- loss of signal is active high
    rx0_tmg_p, rx0_tmg_n: in std_logic; -- received serial data "LVDS"
    sfp_tmg_tx_dis: out std_logic; -- high to disable timing SFP TX
    tx0_tmg_p, tx0_tmg_n: out std_logic; -- serial data to TX to the timing master

    -- AFE LVDS high speed data interface 

    afe0_p, afe0_n: in std_logic_vector(8 downto 0);
    afe1_p, afe1_n: in std_logic_vector(8 downto 0);
    afe2_p, afe2_n: in std_logic_vector(8 downto 0);
    afe3_p, afe3_n: in std_logic_vector(8 downto 0);
    afe4_p, afe4_n: in std_logic_vector(8 downto 0);

    -- 62.5MHz master clock sent to AFEs (LVDS)

    afe_clk_p, afe_clk_n: out std_logic; 

    -- I2C master (for many different devices)

  



    -- SPI master (for 3 DACs)

    dac_sclk:   out std_logic;
    dac_din:    out std_logic;
    dac_sync_n: out std_logic;
    dac_ldac_n: out std_logic;

    -- SPI master (for AFEs and associated DACs)

    afe_rst: out std_logic; -- high = hard reset all AFEs
    afe_pdn: out std_logic; -- low = power down all AFEs

    afe0_miso: in std_logic;
    afe0_sclk: out std_logic;
    afe0_mosi: out std_logic;

    afe12_miso: in std_logic;
    afe12_sclk: out std_logic;
    afe12_mosi: out std_logic;

    afe34_miso: in std_logic;
    afe34_sclk: out std_logic;
    afe34_mosi: out std_logic;

    afe_sen: out std_logic_vector(4 downto 0);
    trim_sync_n: out std_logic_vector(4 downto 0);
    trim_ldac_n: out std_logic_vector(4 downto 0);
    offset_sync_n: out std_logic_vector(4 downto 0);
    offset_ldac_n: out std_logic_vector(4 downto 0);
    
    -- front end AXI----------
    trig_IN: in std_logic;
    FRONT_END_S_AXI_ACLK: in std_logic;
    FRONT_END_S_AXI_ARESETN: in std_logic;
    FRONT_END_S_AXI_AWADDR: in std_logic_vector(31 downto 0);
    FRONT_END_S_AXI_AWPROT: in std_logic_vector(2 downto 0);
    FRONT_END_S_AXI_AWVALID: in std_logic;
    FRONT_END_S_AXI_AWREADY: out std_logic;
    FRONT_END_S_AXI_WDATA: in std_logic_vector(31 downto 0);
    FRONT_END_S_AXI_WSTRB: in std_logic_vector(3 downto 0);
    FRONT_END_S_AXI_WVALID: in std_logic;
    FRONT_END_S_AXI_WREADY: out std_logic;
    FRONT_END_S_AXI_BRESP: out std_logic_vector(1 downto 0);
    FRONT_END_S_AXI_BVALID: out std_logic;
    FRONT_END_S_AXI_BREADY: in std_logic;
    FRONT_END_S_AXI_ARADDR: in std_logic_vector(31 downto 0);
    FRONT_END_S_AXI_ARPROT: in std_logic_vector(2 downto 0);
    FRONT_END_S_AXI_ARVALID: in std_logic;
    FRONT_END_S_AXI_ARREADY: out std_logic;
    FRONT_END_S_AXI_RDATA: out std_logic_vector(31 downto 0);
    FRONT_END_S_AXI_RRESP: out std_logic_vector(1 downto 0);
    FRONT_END_S_AXI_RVALID: out std_logic;
    FRONT_END_S_AXI_RREADY: in std_logic;


-- SPY BUFF AXI

    SPY_BUF_S_S_AXI_ACLK: in std_logic;
    SPY_BUF_S_S_AXI_ARESETN: in std_logic;
	SPY_BUF_S_S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	SPY_BUF_S_S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	SPY_BUF_S_S_AXI_AWVALID	: in std_logic;
	SPY_BUF_S_S_AXI_AWREADY	: out std_logic;
	SPY_BUF_S_S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	SPY_BUF_S_S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	SPY_BUF_S_S_AXI_WVALID	: in std_logic;
	SPY_BUF_S_S_AXI_WREADY	: out std_logic;
	SPY_BUF_S_S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	SPY_BUF_S_S_AXI_BVALID	: out std_logic;
	SPY_BUF_S_S_AXI_BREADY	: in std_logic;
	SPY_BUF_S_S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	SPY_BUF_S_S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	SPY_BUF_S_S_AXI_ARVALID	: in std_logic;
	SPY_BUF_S_S_AXI_ARREADY	: out std_logic;
	SPY_BUF_S_S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	SPY_BUF_S_S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	SPY_BUF_S_S_AXI_RVALID	: out std_logic;
	SPY_BUF_S_S_AXI_RREADY	: in std_logic;
	
	
	-- END POINT AXI
	
    END_P_S_AXI_ACLK: in std_logic;
    END_P_S_AXI_ARESETN: in std_logic;
	END_P_S_AXI_AWADDR    : in std_logic_vector(31 downto 0);
	END_P_S_AXI_AWPROT    : in std_logic_vector(2 downto 0);
	END_P_S_AXI_AWVALID   : in std_logic;
	END_P_S_AXI_AWREADY   : out std_logic;
	END_P_S_AXI_WDATA     : in std_logic_vector(31 downto 0);
	END_P_S_AXI_WSTRB     : in std_logic_vector(3 downto 0);
	END_P_S_AXI_WVALID    : in std_logic;
	END_P_S_AXI_WREADY    : out std_logic;
	END_P_S_AXI_BRESP     : out std_logic_vector(1 downto 0);
	END_P_S_AXI_BVALID    : out std_logic;
	END_P_S_AXI_BREADY    : in std_logic;
	END_P_S_AXI_ARADDR    : in std_logic_vector(31 downto 0);
	END_P_S_AXI_ARPROT    : in std_logic_vector(2 downto 0);
	END_P_S_AXI_ARVALID   : in std_logic;
	END_P_S_AXI_ARREADY   : out std_logic;
	END_P_S_AXI_RDATA     : out std_logic_vector(31 downto 0);
	END_P_S_AXI_RRESP     : out std_logic_vector(1 downto 0);
	END_P_S_AXI_RVALID    : out std_logic;
	END_P_S_AXI_RREADY    : in std_logic;
	
	

	
	-- DAC SPI AXI
	
	
    SPI_DAC_S_AXI_ACLK: in std_logic;
    SPI_DAC_S_AXI_ARESETN: in std_logic;
	SPI_DAC_S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	SPI_DAC_S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	SPI_DAC_S_AXI_AWVALID	: in std_logic;
	SPI_DAC_S_AXI_AWREADY	: out std_logic;
	SPI_DAC_S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	SPI_DAC_S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	SPI_DAC_S_AXI_WVALID	: in std_logic;
	SPI_DAC_S_AXI_WREADY	: out std_logic;
	SPI_DAC_S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	SPI_DAC_S_AXI_BVALID	: out std_logic;
	SPI_DAC_S_AXI_BREADY	: in std_logic;
	SPI_DAC_S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	SPI_DAC_S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	SPI_DAC_S_AXI_ARVALID	: in std_logic;
	SPI_DAC_S_AXI_ARREADY	: out std_logic;
	SPI_DAC_S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	SPI_DAC_S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	SPI_DAC_S_AXI_RVALID	: out std_logic;
	SPI_DAC_S_AXI_RREADY	: in std_logic;
	

	
	-- AFE SPI AXI---
	
	
    AFE_SPI_S_AXI_ACLK: in std_logic;
    AFE_SPI_S_AXI_ARESETN: in std_logic;
	AFE_SPI_S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	AFE_SPI_S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	AFE_SPI_S_AXI_AWVALID	: in std_logic;
	AFE_SPI_S_AXI_AWREADY	: out std_logic;
	AFE_SPI_S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	AFE_SPI_S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	AFE_SPI_S_AXI_WVALID	: in std_logic;
	AFE_SPI_S_AXI_WREADY	: out std_logic;
	AFE_SPI_S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	AFE_SPI_S_AXI_BVALID	: out std_logic;
	AFE_SPI_S_AXI_BREADY	: in std_logic;
	AFE_SPI_S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	AFE_SPI_S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	AFE_SPI_S_AXI_ARVALID	: in std_logic;
	AFE_SPI_S_AXI_ARREADY	: out std_logic;
	AFE_SPI_S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	AFE_SPI_S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	AFE_SPI_S_AXI_RVALID	: out std_logic;
	AFE_SPI_S_AXI_RREADY	: in std_logic;
	
	--TRIG AXI
	
    TRIRG_S_AXI_ACLK: in std_logic;
    TRIRG_S_AXI_ARESETN: in std_logic;
    TRIRG_S_AXI_AWADDR: in std_logic_vector(31 downto 0);
    TRIRG_S_AXI_AWPROT: in std_logic_vector(2 downto 0);
    TRIRG_S_AXI_AWVALID: in std_logic;
    TRIRG_S_AXI_AWREADY: out std_logic;
    TRIRG_S_AXI_WDATA: in std_logic_vector(31 downto 0);
    TRIRG_S_AXI_WSTRB: in std_logic_vector(3 downto 0);
    TRIRG_S_AXI_WVALID: in std_logic;
    TRIRG_S_AXI_WREADY: out std_logic;
    TRIRG_S_AXI_BRESP: out std_logic_vector(1 downto 0);
    TRIRG_S_AXI_BVALID: out std_logic;
    TRIRG_S_AXI_BREADY: in std_logic;
    TRIRG_S_AXI_ARADDR: in std_logic_vector(31 downto 0);
    TRIRG_S_AXI_ARPROT: in std_logic_vector(2 downto 0);
    TRIRG_S_AXI_ARVALID: in std_logic;
    TRIRG_S_AXI_ARREADY: out std_logic;
    TRIRG_S_AXI_RDATA: out std_logic_vector(31 downto 0);
    TRIRG_S_AXI_RRESP: out std_logic_vector(1 downto 0);
    TRIRG_S_AXI_RVALID: out std_logic;
    TRIRG_S_AXI_RREADY: in std_logic;
	
	
	-- STUFF AXI
	
    STUFF_S_AXI_ACLK: in std_logic;
    STUFF_S_AXI_ARESETN: in std_logic;
	STUFF_S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	STUFF_S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	STUFF_S_AXI_AWVALID	: in std_logic;
	STUFF_S_AXI_AWREADY	: out std_logic;
	STUFF_S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	STUFF_S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	STUFF_S_AXI_WVALID	: in std_logic;
	STUFF_S_AXI_WREADY	: out std_logic;
	STUFF_S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	STUFF_S_AXI_BVALID	: out std_logic;
	STUFF_S_AXI_BREADY	: in std_logic;
	STUFF_S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	STUFF_S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	STUFF_S_AXI_ARVALID	: in std_logic;
	STUFF_S_AXI_ARREADY	: out std_logic;
	STUFF_S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	STUFF_S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	STUFF_S_AXI_RVALID	: out std_logic;
	STUFF_S_AXI_RREADY	: in std_logic;
	
	
	
	-- Threshold AXI
	
	
    THRESH_S_AXI_ACLK: in std_logic;
    THRESH_S_AXI_ARESETN: in std_logic;
	THRESH_S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	THRESH_S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	THRESH_S_AXI_AWVALID	: in std_logic;
	THRESH_S_AXI_AWREADY	: out std_logic;
	THRESH_S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	THRESH_S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	THRESH_S_AXI_WVALID	: in std_logic;
	THRESH_S_AXI_WREADY	: out std_logic;
	THRESH_S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	THRESH_S_AXI_BVALID	: out std_logic;
	THRESH_S_AXI_BREADY	: in std_logic;
	THRESH_S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	THRESH_S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	THRESH_S_AXI_ARVALID	: in std_logic;
	THRESH_S_AXI_ARREADY	: out std_logic;
	THRESH_S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	THRESH_S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	THRESH_S_AXI_RVALID	: out std_logic; 
	THRESH_S_AXI_RREADY	: in std_logic;
	
	
	OUTBUFF_S_AXI_ACLK: in std_logic;
    OUTBUFF_S_AXI_ARESETN: in std_logic;
	OUTBUFF_S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	OUTBUFF_S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	OUTBUFF_S_AXI_AWVALID	: in std_logic;
	OUTBUFF_S_AXI_AWREADY	: out std_logic;
	OUTBUFF_S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	OUTBUFF_S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	OUTBUFF_S_AXI_WVALID	: in std_logic;
	OUTBUFF_S_AXI_WREADY	: out std_logic;
	OUTBUFF_S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	OUTBUFF_S_AXI_BVALID	: out std_logic;
	OUTBUFF_S_AXI_BREADY	: in std_logic;
	OUTBUFF_S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	OUTBUFF_S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	OUTBUFF_S_AXI_ARVALID	: in std_logic;
	OUTBUFF_S_AXI_ARREADY	: out std_logic;
	OUTBUFF_S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	OUTBUFF_S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	OUTBUFF_S_AXI_RVALID	: out std_logic; 
	OUTBUFF_S_AXI_RREADY	: in std_logic;
    -- 10G Ethernet sender interface to external MGT refclk LVDS 156.25MHz
    --eth_clk: in std_logic ;
    eth_clk_p: in std_logic;
    eth_clk_n: in std_logic; 

    -- 10G Ethernet sender interface to external SFP+ transceiver

    eth0_rx_p: in std_logic_vector (0 downto 0);
    eth0_rx_n: in std_logic_vector (0 downto 0);
    eth0_tx_p: out std_logic_vector (0 downto 0);
    eth0_tx_n: out std_logic_vector (0 downto 0);
    eth0_tx_dis: out std_logic_vector (0 downto 0);
     
    --debugging signals
    out_buff_trig: out std_logic ;
    out_buff_clk: out std_logic ;
    out_buff_data: out std_logic_vector (63 downto 0);
    
    --gth0_debut: out std_logic ;
    --time_stamp_debug: out std_logic_vector(63 downto 0);
    --syclk_62p5: out std_logic;
    --ep_rx_tmg_debug: out std_logic;
    --mmcm0_locked: out std_logic;
    --mmcm1_locked: out std_logic;
    --mmcm1_62p5_ouput: out std_logic;
    FORCE_TRIG: IN std_logic ;
    DIN_DEBUG: out std_logic_vector (13 downto 0) ;
     VALID_DEBUG: out std_logic;
     LAST_DEBUG: out std_logic;
     
     -- endpoint debug signals
     
    clock_gen_debug: out std_logic ;
    mmcm0_100MHZ_CLK_debug: out std_logic ;
    ep_62p5MHZ_CLK_debug: out std_logic ;
    F_OK_DEBUG: out std_logic ;    
    SCTR_DEBUG: OUT std_logic_vector (15 downto 0);
    CCTR_DEBUG: OUT std_logic_vector (15 downto 0);
    Trigered_debug: out std_logic
    --ep_mmcm1_reset: out std_logic

  );
end daphne_selftrigger_top;

architecture daphne_selftrigger_top_arch of daphne_selftrigger_top is 

-- There are 9 AXI-LITE interfaces in this design:
--
-- 1. timing endpoint
-- 2. front end 
-- 3. spy buffers
-- 4. i2c master (multiple devices)
-- 5. spi master (current monitor)
-- 6. spi master (afe + dac)
-- 7. spi master (3 dacs)
-- 8. misc stuff (fans, vbias, mux control, leds, etc. etc.)
-- 9. core logic
--
-- MOAR NOTES: 
-- 1. all modules are written assuming S_AXI_ACLK is 100MHz
-- 2. most modules use S_AXI_ARESETN has an active low HARD RESET
-- 3. most modules have various SOFT RESET control bits that can be written via AXI registers
-- 4. most modules have a testbench for standalone simulation

-- front end data alignment logic

component front_end 
port(
    afe_p, afe_n: in array_5x9_type;
    afe_clk_p, afe_clk_n: out std_logic;
    clk500: in std_logic;
    clk125: in std_logic;
    clock: in std_logic;
    dout: out array_5x9x16_type;
    trig: out std_logic;
    trig_IN: IN std_logic ;
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
    S_AXI_RREADY: in std_logic
  );
end component;

-- Input Spy Buffers

component spybuffers
port(
    clock           : in std_logic;
    trig            : in std_logic;
    din             : in array_5x9x16_type;
    timestamp       : in std_logic_vector(63 downto 0);
	S_AXI_ACLK	    : in std_logic;
	S_AXI_ARESETN	: in std_logic;
	S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	S_AXI_AWVALID	: in std_logic;
	S_AXI_AWREADY	: out std_logic;
	S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	S_AXI_WVALID	: in std_logic;
	S_AXI_WREADY	: out std_logic;
	S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	S_AXI_BVALID	: out std_logic;
	S_AXI_BREADY	: in std_logic;
	S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	S_AXI_ARVALID	: in std_logic;
	S_AXI_ARREADY	: out std_logic;
	S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	S_AXI_RVALID	: out std_logic;
	S_AXI_RREADY	: in std_logic
  );
end component;

-- Timing Endpoint

component endpoint 
port(
  sysclk_p, sysclk_n:   in std_logic;  -- 100MHz constant system clock from PS or oscillator
   --sysclk100:   in std_logic;  -- 100MHz constant system clock from PS or oscillator
    -- external optical timing SFP link interface

    sfp_tmg_los: in std_logic; -- loss of signal
    rx0_tmg_p, rx0_tmg_n: in std_logic; -- LVDS recovered serial data ACKCHYUALLY the clock!
    sfp_tmg_tx_dis: out std_logic; -- high to disable timing SFP TX
    tx0_tmg_p, tx0_tmg_n: out std_logic; -- send data upstream
    --rx_tmg_debug: out std_logic ;
    -- output clocks used by daphne logic
    mclk: out std_logic;  -- master clock 62.5MHz
    clock:   out std_logic;  -- master clock 62.5MHz
    clk500:  out std_logic;  -- front end clock 500MHz
    clk125:  out std_logic;  -- front end clock 125MHz
    sclk200: out std_logic; -- system clock 200MHz
    --sclk100: out std_logic; -- system clock 100MHz
    timestamp: out std_logic_vector(63 downto 0); -- sync to clock 
    sync: out std_logic_vector(7 downto 0);
    sync_stb: out std_logic; 
    
    -- debug signals
    
    clock_gen_debug: out std_logic ;
    mmcm0_100MHZ_CLK_debug: out std_logic ;
    ep_62p5MHZ_CLK_debug: out std_logic ;
    F_OK_DEBUG: out std_logic ;    
    SCTR_DEBUG: OUT std_logic_vector (15 downto 0);
    CCTR_DEBUG: OUT std_logic_vector (15 downto 0);
    mmcm0_locked_o: out std_logic;
    mmcm1_locked_o: out std_logic;
    endpoint_ready_o: out std_logic;
    endpoint_state_o: out std_logic_vector(3 downto 0);
    timestamp_valid_o: out std_logic;
    --mmc0_locked_debug: out std_logic ;
    --mmc1_locked_debug: out std_logic;
    --ep_stat_debug: out std_logic_vector (3 downto 0);
    --mmcm1_reset_debug : out std_logic ;
    --ep_reset_debug : out std_logic ;
    -- AXI-Lite interface for the control/status registers

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
	S_AXI_RREADY: in std_logic
);
end component;



-- SPI master for 3 DAC chips 

component spim_dac
port(
    dac_sclk        : out std_logic;
    dac_din         : out std_logic;
    dac_sync_n      : out std_logic;
    dac_ldac_n      : out std_logic;
	S_AXI_ACLK	    : in std_logic;
	S_AXI_ARESETN	: in std_logic;
	S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	S_AXI_AWVALID	: in std_logic;
	S_AXI_AWREADY	: out std_logic;
	S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	S_AXI_WVALID	: in std_logic;
	S_AXI_WREADY	: out std_logic;
	S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	S_AXI_BVALID	: out std_logic;
	S_AXI_BREADY	: in std_logic;
	S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	S_AXI_ARVALID	: in std_logic;
	S_AXI_ARREADY	: out std_logic;
	S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	S_AXI_RVALID	: out std_logic;
	S_AXI_RREADY	: in std_logic
  );
end component;

-- current monitor



-- SPI master for AFE chips + Offset DACs + Trim DACs
-- plus two global AFE control signals

component spim_afe 
port(
    afe_rst: out std_logic;
    afe_pdn: out std_logic;
    afe0_miso: in std_logic;
    afe0_sclk: out std_logic;
    afe0_mosi: out std_logic;
    afe12_miso: in std_logic;
    afe12_sclk: out std_logic;
    afe12_mosi: out std_logic;
    afe34_miso: in std_logic;
    afe34_sclk: out std_logic;
    afe34_mosi: out std_logic;
    afe_sen: out std_logic_vector(4 downto 0);
    trim_sync_n: out std_logic_vector(4 downto 0);
    trim_ldac_n: out std_logic_vector(4 downto 0);
    offset_sync_n: out std_logic_vector(4 downto 0);
    offset_ldac_n: out std_logic_vector(4 downto 0);
	S_AXI_ACLK	    : in std_logic;
	S_AXI_ARESETN	: in std_logic;
	S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	S_AXI_AWVALID	: in std_logic;
	S_AXI_AWREADY	: out std_logic;
	S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	S_AXI_WVALID	: in std_logic;
	S_AXI_WREADY	: out std_logic;
	S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	S_AXI_BVALID	: out std_logic;
	S_AXI_BREADY	: in std_logic;
	S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	S_AXI_ARVALID	: in std_logic;
	S_AXI_ARREADY	: out std_logic;
	S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	S_AXI_RVALID	: out std_logic;
	S_AXI_RREADY	: in std_logic
  );
end component;

-- catch all module for misc signals

component stuff
port(
    fan_tach        : in  std_logic_vector(1 downto 0);
    fan_ctrl        : out std_logic;
    hvbias_en       : out std_logic;
    mux_en          : out std_logic_vector(1 downto 0);
    mux_a           : out std_logic_vector(1 downto 0);
    stat_led        : out std_logic_vector(5 downto 0);
    version         : in std_logic_vector(27 downto 0);
    core_chan_enable: out std_logic_vector(39 downto 0);
    adhoc           : out std_logic_vector(7 downto 0); 
    filter_output_selector: out std_logic_vector(1 downto 0);
    afe_comp_enable : out std_logic_vector(39 downto 0);
    invert_enable   : out std_logic_vector(39 downto 0);
    st_config       : out std_logic_vector(13 downto 0);
    signal_delay    : out std_logic_vector(4 downto 0);
    reset_st_counters: out std_logic; 
	S_AXI_ACLK	    : in std_logic;
	S_AXI_ARESETN	: in std_logic;
	S_AXI_AWADDR	: in std_logic_vector(31 downto 0);
	S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
	S_AXI_AWVALID	: in std_logic;
	S_AXI_AWREADY	: out std_logic;
	S_AXI_WDATA	    : in std_logic_vector(31 downto 0);
	S_AXI_WSTRB	    : in std_logic_vector(3 downto 0);
	S_AXI_WVALID	: in std_logic;
	S_AXI_WREADY	: out std_logic;
	S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
	S_AXI_BVALID	: out std_logic;
	S_AXI_BREADY	: in std_logic;
	S_AXI_ARADDR	: in std_logic_vector(31 downto 0);
	S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
	S_AXI_ARVALID	: in std_logic;
	S_AXI_ARREADY	: out std_logic;
	S_AXI_RDATA	    : out std_logic_vector(31 downto 0);
	S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
	S_AXI_RVALID	: out std_logic;
	S_AXI_RREADY	: in std_logic
  );
end component;



signal afe_p_array, afe_n_array: array_5x9_type;
signal din_full_array: array_5x9x16_type;
signal din_array: array_5x8x14_type;
signal trig: std_logic;
signal spybuffer_trig: std_logic;
signal timestamp: std_logic_vector(63 downto 0);
signal clock, clk125, clk500: std_logic;
signal core_chan_enable: std_logic_vector(39 downto 0);
signal st_trigger_signal: std_logic_vector(39 downto 0);

signal S_AXI_ACLK:    std_logic;
signal S_AXI_ARESETN: std_logic;

signal FE_AXI_AWADDR:  std_logic_vector(31 downto 0);
signal FE_AXI_AWPROT:  std_logic_vector(2 downto 0);
signal FE_AXI_AWVALID: std_logic;
signal FE_AXI_AWREADY: std_logic;
signal FE_AXI_WDATA:   std_logic_vector(31 downto 0);
signal FE_AXI_WSTRB:   std_logic_vector(3 downto 0);
signal FE_AXI_WVALID:  std_logic;
signal FE_AXI_WREADY:  std_logic;
signal FE_AXI_BRESP:   std_logic_vector(1 downto 0);
signal FE_AXI_BVALID:  std_logic;
signal FE_AXI_BREADY:  std_logic;
signal FE_AXI_ARADDR:  std_logic_vector(31 downto 0);
signal FE_AXI_ARPROT:  std_logic_vector(2 downto 0);
signal FE_AXI_ARVALID: std_logic;
signal FE_AXI_ARREADY: std_logic;
signal FE_AXI_RDATA:   std_logic_vector(31 downto 0);
signal FE_AXI_RRESP:   std_logic_vector(1 downto 0);
signal FE_AXI_RVALID:  std_logic;
signal FE_AXI_RREADY:  std_logic;

signal SB_AXI_AWADDR:  std_logic_vector(31 downto 0);
signal SB_AXI_AWPROT:  std_logic_vector(2 downto 0);
signal SB_AXI_AWVALID: std_logic;
signal SB_AXI_AWREADY: std_logic;
signal SB_AXI_WDATA:   std_logic_vector(31 downto 0);
signal SB_AXI_WSTRB:   std_logic_vector(3 downto 0);
signal SB_AXI_WVALID:  std_logic;
signal SB_AXI_WREADY:  std_logic;
signal SB_AXI_BRESP:   std_logic_vector(1 downto 0);
signal SB_AXI_BVALID:  std_logic;
signal SB_AXI_BREADY:  std_logic;
signal SB_AXI_ARADDR:  std_logic_vector(31 downto 0);
signal SB_AXI_ARPROT:  std_logic_vector(2 downto 0);
signal SB_AXI_ARVALID: std_logic;
signal SB_AXI_ARREADY: std_logic;
signal SB_AXI_RDATA:   std_logic_vector(31 downto 0);
signal SB_AXI_RRESP:   std_logic_vector(1 downto 0);
signal SB_AXI_RVALID:  std_logic;
signal SB_AXI_RREADY:  std_logic;

signal EP_AXI_AWADDR:  std_logic_vector(31 downto 0);
signal EP_AXI_AWPROT:  std_logic_vector(2 downto 0);
signal EP_AXI_AWVALID: std_logic;
signal EP_AXI_AWREADY: std_logic;
signal EP_AXI_WDATA:   std_logic_vector(31 downto 0);
signal EP_AXI_WSTRB:   std_logic_vector(3 downto 0);
signal EP_AXI_WVALID:  std_logic;
signal EP_AXI_WREADY:  std_logic;
signal EP_AXI_BRESP:   std_logic_vector(1 downto 0);
signal EP_AXI_BVALID:  std_logic;
signal EP_AXI_BREADY:  std_logic;
signal EP_AXI_ARADDR:  std_logic_vector(31 downto 0);
signal EP_AXI_ARPROT:  std_logic_vector(2 downto 0);
signal EP_AXI_ARVALID: std_logic;
signal EP_AXI_ARREADY: std_logic;
signal EP_AXI_RDATA:   std_logic_vector(31 downto 0);
signal EP_AXI_RRESP:   std_logic_vector(1 downto 0);
signal EP_AXI_RVALID:  std_logic;
signal EP_AXI_RREADY:  std_logic;

signal AFE_AXI_AWADDR:  std_logic_vector(31 downto 0);
signal AFE_AXI_AWPROT:  std_logic_vector(2 downto 0);
signal AFE_AXI_AWVALID: std_logic;
signal AFE_AXI_AWREADY: std_logic;
signal AFE_AXI_WDATA:   std_logic_vector(31 downto 0);
signal AFE_AXI_WSTRB:   std_logic_vector(3 downto 0);
signal AFE_AXI_WVALID:  std_logic;
signal AFE_AXI_WREADY:  std_logic;
signal AFE_AXI_BRESP:   std_logic_vector(1 downto 0);
signal AFE_AXI_BVALID:  std_logic;
signal AFE_AXI_BREADY:  std_logic;
signal AFE_AXI_ARADDR:  std_logic_vector(31 downto 0);
signal AFE_AXI_ARPROT:  std_logic_vector(2 downto 0);
signal AFE_AXI_ARVALID: std_logic;
signal AFE_AXI_ARREADY: std_logic;
signal AFE_AXI_RDATA:   std_logic_vector(31 downto 0);
signal AFE_AXI_RRESP:   std_logic_vector(1 downto 0);
signal AFE_AXI_RVALID:  std_logic;
signal AFE_AXI_RREADY:  std_logic;



signal DAC_AXI_AWADDR:  std_logic_vector(31 downto 0);
signal DAC_AXI_AWPROT:  std_logic_vector(2 downto 0);
signal DAC_AXI_AWVALID: std_logic;
signal DAC_AXI_AWREADY: std_logic;
signal DAC_AXI_WDATA:   std_logic_vector(31 downto 0);
signal DAC_AXI_WSTRB:   std_logic_vector(3 downto 0);
signal DAC_AXI_WVALID:  std_logic;
signal DAC_AXI_WREADY:  std_logic;
signal DAC_AXI_BRESP:   std_logic_vector(1 downto 0);
signal DAC_AXI_BVALID:  std_logic;
signal DAC_AXI_BREADY:  std_logic;
signal DAC_AXI_ARADDR:  std_logic_vector(31 downto 0);
signal DAC_AXI_ARPROT:  std_logic_vector(2 downto 0);
signal DAC_AXI_ARVALID: std_logic;
signal DAC_AXI_ARREADY: std_logic;
signal DAC_AXI_RDATA:   std_logic_vector(31 downto 0);
signal DAC_AXI_RRESP:   std_logic_vector(1 downto 0);
signal DAC_AXI_RVALID:  std_logic;
signal DAC_AXI_RREADY:  std_logic;



signal STUFF_AXI_AWADDR:  std_logic_vector(31 downto 0);
signal STUFF_AXI_AWPROT:  std_logic_vector(2 downto 0);
signal STUFF_AXI_AWVALID: std_logic;
signal STUFF_AXI_AWREADY: std_logic;
signal STUFF_AXI_WDATA:   std_logic_vector(31 downto 0);
signal STUFF_AXI_WSTRB:   std_logic_vector(3 downto 0);
signal STUFF_AXI_WVALID:  std_logic;
signal STUFF_AXI_WREADY:  std_logic;
signal STUFF_AXI_BRESP:   std_logic_vector(1 downto 0);
signal STUFF_AXI_BVALID:  std_logic;
signal STUFF_AXI_BREADY:  std_logic;
signal STUFF_AXI_ARADDR:  std_logic_vector(31 downto 0);
signal STUFF_AXI_ARPROT:  std_logic_vector(2 downto 0);
signal STUFF_AXI_ARVALID: std_logic;
signal STUFF_AXI_ARREADY: std_logic;
signal STUFF_AXI_RDATA:   std_logic_vector(31 downto 0);
signal STUFF_AXI_RRESP:   std_logic_vector(1 downto 0);
signal STUFF_AXI_RVALID:  std_logic;
signal STUFF_AXI_RREADY:  std_logic;

signal eth0_p_buff: std_logic;
signal eth0_n_buff: std_logic ;


signal  clk_62p5_debug: std_logic ;
signal  ep_rx_debug: std_logic ;
signal ep_mmcm0_locked: std_logic ;
signal ep_mmcm1_locked: std_logic ;
signal ep_stat_debug: std_logic_vector (3 downto 0);
signal mmcm1_reset_debug: std_logic ;
signal ep_reset_debug: std_logic ;
signal eth0_tx_dis_debug: std_logic ;
--signal eth0_10g_debug:std_logic  ;
signal din_debug_reg: std_logic_vector (13 downto 0);
signal trigered_debug_reg: std_logic;

--timing interface trigger signals
signal ti_trigger_reg: std_logic_vector(7 downto 0); ------------------
signal ti_trigger_stbr_reg: std_logic;  ---------------------------
signal ti_trigger_en: std_logic;
signal ti_trigger_en0, ti_trigger_en1, ti_trigger_en2, trig_en_total: std_logic;
signal adhoc: std_logic_vector(7 downto 0);

-- self trigger core operation and configuration signals
signal filter_output_selector: std_logic_vector(1 downto 0);
signal invert_enable, afe_comp_enable: std_logic_vector(39 downto 0);
signal st_config: std_logic_vector(13 downto 0);
signal signal_delay: std_logic_vector(4 downto 0);
signal reset_st_counters: std_logic;

signal  f_ok,sysclk_ibuf,mmcm0_clkout2,ep_clk62p5: std_logic ;
signal sctr, cctr: std_logic_vector (15 downto 0);
signal timing_stat: timing_status_t;
         

begin


--eth0_tx_p <= eth0_p_buff;
--eth0_tx_n <= eth0_n_buff;
din_debug_reg <=  din_array(1)(0);

     

   
     
-- pack SLV AFE LVDS signals into 5x9 2D arrays

afe_p_array(0)(8 downto 0) <= afe0_p(8 downto 0); 
afe_p_array(1)(8 downto 0) <= afe1_p(8 downto 0); 
afe_p_array(2)(8 downto 0) <= afe2_p(8 downto 0); 
afe_p_array(3)(8 downto 0) <= afe3_p(8 downto 0); 
afe_p_array(4)(8 downto 0) <= afe4_p(8 downto 0); 

afe_n_array(0)(8 downto 0) <= afe0_n(8 downto 0);
afe_n_array(1)(8 downto 0) <= afe1_n(8 downto 0);
afe_n_array(2)(8 downto 0) <= afe2_n(8 downto 0);
afe_n_array(3)(8 downto 0) <= afe3_n(8 downto 0);
afe_n_array(4)(8 downto 0) <= afe4_n(8 downto 0);

-- AXI ASSIGNMNT



-- FRONT END

 FE_AXI_AWADDR <=   FRONT_END_S_AXI_AWADDR;
 FE_AXI_AWPROT <= FRONT_END_S_AXI_AWPROT;
 FE_AXI_AWVALID <= FRONT_END_S_AXI_AWVALID;
 FRONT_END_S_AXI_AWREADY <= FE_AXI_AWREADY  ;
 FE_AXI_WDATA <= FRONT_END_S_AXI_WDATA;
 FE_AXI_WSTRB <= FRONT_END_S_AXI_WSTRB;
 FE_AXI_WVALID <= FRONT_END_S_AXI_WVALID;
 FRONT_END_S_AXI_WREADY <= FE_AXI_WREADY  ;
 FRONT_END_S_AXI_BRESP<= FE_AXI_BRESP  ;
 FRONT_END_S_AXI_BVALID <= FE_AXI_BVALID  ;
 FE_AXI_BREADY <= FRONT_END_S_AXI_BREADY;
 FE_AXI_ARADDR <= FRONT_END_S_AXI_ARADDR;
 FE_AXI_ARPROT <= FRONT_END_S_AXI_ARPROT;
 FE_AXI_ARVALID <= FRONT_END_S_AXI_ARVALID;
 FRONT_END_S_AXI_ARREADY<= FE_AXI_ARREADY  ;
 FRONT_END_S_AXI_RDATA <= FE_AXI_RDATA  ;
 FRONT_END_S_AXI_RRESP <= FE_AXI_RRESP  ;
 FRONT_END_S_AXI_RVALID<=  FE_AXI_RVALID  ;
 FE_AXI_RREADY <= FRONT_END_S_AXI_RREADY ;


-- SPY BUFF

 SB_AXI_AWADDR <= SPY_BUF_S_S_AXI_AWADDR;
 SB_AXI_AWPROT <= SPY_BUF_S_S_AXI_AWPROT;
 SB_AXI_AWVALID <= SPY_BUF_S_S_AXI_AWVALID;
  SPY_BUF_S_S_AXI_AWREADY<= SB_AXI_AWREADY;
 SB_AXI_WDATA <= SPY_BUF_S_S_AXI_WDATA;
 SB_AXI_WSTRB <= SPY_BUF_S_S_AXI_WSTRB;
 SB_AXI_WVALID <= SPY_BUF_S_S_AXI_WVALID;
  SPY_BUF_S_S_AXI_WREADY<= SB_AXI_WREADY;
  SPY_BUF_S_S_AXI_BRESP <= SB_AXI_BRESP;
  SPY_BUF_S_S_AXI_BVALID<= SB_AXI_BVALID;
 SB_AXI_BREADY <= SPY_BUF_S_S_AXI_BREADY;
 SB_AXI_ARADDR <= SPY_BUF_S_S_AXI_ARADDR;
 SB_AXI_ARPROT <= SPY_BUF_S_S_AXI_ARPROT;
 SB_AXI_ARVALID <= SPY_BUF_S_S_AXI_ARVALID;
  SPY_BUF_S_S_AXI_ARREADY<= SB_AXI_ARREADY;
  SPY_BUF_S_S_AXI_RDATA<= SB_AXI_RDATA;
  SPY_BUF_S_S_AXI_RRESP<= SB_AXI_RRESP;
 SPY_BUF_S_S_AXI_RVALID <= SB_AXI_RVALID;
 SB_AXI_RREADY <= SPY_BUF_S_S_AXI_RREADY;

-- END POINT 

  EP_AXI_AWADDR <= END_P_S_AXI_AWADDR; 
  EP_AXI_AWPROT <=  END_P_S_AXI_AWPROT;
  EP_AXI_AWVALID <=   END_P_S_AXI_AWVALID;
  END_P_S_AXI_AWREADY <=  EP_AXI_AWREADY   ;
  EP_AXI_WDATA <=   END_P_S_AXI_WDATA  ;
  EP_AXI_WSTRB   <=  END_P_S_AXI_WSTRB ;
  EP_AXI_WVALID   <= END_P_S_AXI_WVALID;
   END_P_S_AXI_WREADY<= EP_AXI_WREADY   ;
   END_P_S_AXI_BRESP<= EP_AXI_BRESP    ;
   END_P_S_AXI_BVALID<= EP_AXI_BVALID   ;
   EP_AXI_BREADY   <=  END_P_S_AXI_BREADY;
  EP_AXI_ARADDR  <=  END_P_S_AXI_ARADDR  ;
  EP_AXI_ARPROT  <=  END_P_S_AXI_ARPROT ;
  EP_AXI_ARVALID   <= END_P_S_AXI_ARVALID;
  END_P_S_AXI_ARREADY <= EP_AXI_ARREADY  ;
   END_P_S_AXI_RDATA <= EP_AXI_RDATA     ;
  END_P_S_AXI_RRESP<=  EP_AXI_RRESP     ;
  END_P_S_AXI_RVALID<=  EP_AXI_RVALID    ;
  EP_AXI_RREADY  <=  END_P_S_AXI_RREADY ;


-- AFE SPI

  AFE_AXI_AWADDR   <= AFE_SPI_S_AXI_AWADDR;
  AFE_AXI_AWPROT   <= AFE_SPI_S_AXI_AWPROT;
  AFE_AXI_AWVALID  <=  AFE_SPI_S_AXI_AWVALID;
  AFE_SPI_S_AXI_AWREADY  <= AFE_AXI_AWREADY ;
  AFE_AXI_WDATA   <= AFE_SPI_S_AXI_WDATA;
  AFE_AXI_WSTRB   <= AFE_SPI_S_AXI_WSTRB;
  AFE_AXI_WVALID   <= AFE_SPI_S_AXI_WVALID;
  AFE_SPI_S_AXI_WREADY  <= AFE_AXI_WREADY ;
  AFE_SPI_S_AXI_BRESP  <= AFE_AXI_BRESP ;
  AFE_SPI_S_AXI_BVALID <=  AFE_AXI_BVALID ;
  AFE_AXI_BREADY  <=  AFE_SPI_S_AXI_BREADY;
  AFE_AXI_ARADDR   <= AFE_SPI_S_AXI_ARADDR;
  AFE_AXI_ARPROT  <=  AFE_SPI_S_AXI_ARPROT;
  AFE_AXI_ARVALID  <=  AFE_SPI_S_AXI_ARVALID;
  AFE_SPI_S_AXI_ARREADY  <= AFE_AXI_ARREADY   ;
  AFE_SPI_S_AXI_RDATA  <= AFE_AXI_RDATA ;
  AFE_SPI_S_AXI_RRESP  <= AFE_AXI_RRESP ;
  AFE_SPI_S_AXI_RVALID  <= AFE_AXI_RVALID ;
  AFE_AXI_RREADY   <= AFE_SPI_S_AXI_RREADY;





-- DACs

 DAC_AXI_AWADDR <= SPI_DAC_S_AXI_AWADDR;
 DAC_AXI_AWPROT <=SPI_DAC_S_AXI_AWPROT;
 DAC_AXI_AWVALID <= SPI_DAC_S_AXI_AWVALID;
 SPI_DAC_S_AXI_AWREADY<= DAC_AXI_AWREADY ;
 DAC_AXI_WDATA <= SPI_DAC_S_AXI_WDATA;
 DAC_AXI_WSTRB <= SPI_DAC_S_AXI_WSTRB;
 DAC_AXI_WVALID <= SPI_DAC_S_AXI_WVALID;
 SPI_DAC_S_AXI_WREADY<= DAC_AXI_WREADY ;
 SPI_DAC_S_AXI_BRESP<= DAC_AXI_BRESP ;
 SPI_DAC_S_AXI_BVALID <= DAC_AXI_BVALID ;
 DAC_AXI_BREADY <= SPI_DAC_S_AXI_BREADY;
 DAC_AXI_ARADDR <= SPI_DAC_S_AXI_ARADDR;
 DAC_AXI_ARPROT <= SPI_DAC_S_AXI_ARPROT;
 DAC_AXI_ARVALID <= SPI_DAC_S_AXI_ARVALID;
 SPI_DAC_S_AXI_ARREADY <= DAC_AXI_ARREADY ;
 SPI_DAC_S_AXI_RDATA <= DAC_AXI_RDATA ;
SPI_DAC_S_AXI_RRESP  <= DAC_AXI_RRESP ;
 SPI_DAC_S_AXI_RVALID <= DAC_AXI_RVALID ;
 DAC_AXI_RREADY <= SPI_DAC_S_AXI_RREADY;






--STUF 

 STUFF_AXI_AWADDR   <= STUFF_S_AXI_AWADDR;
 STUFF_AXI_AWPROT   <= STUFF_S_AXI_AWPROT;
 STUFF_AXI_AWVALID   <= STUFF_S_AXI_AWVALID ;
 STUFF_S_AXI_AWREADY   <= STUFF_AXI_AWREADY ;
 STUFF_AXI_WDATA   <= STUFF_S_AXI_WDATA;
 STUFF_AXI_WSTRB   <= STUFF_S_AXI_WSTRB;
 STUFF_AXI_WVALID   <= STUFF_S_AXI_WVALID ;
 STUFF_S_AXI_WREADY   <= STUFF_AXI_WREADY  ;
 STUFF_S_AXI_BRESP   <= STUFF_AXI_BRESP  ;
 STUFF_S_AXI_BVALID   <= STUFF_AXI_BVALID  ;
 STUFF_AXI_BREADY   <= STUFF_S_AXI_BREADY  ;
 STUFF_AXI_ARADDR   <= STUFF_S_AXI_ARADDR  ;
 STUFF_AXI_ARPROT   <= STUFF_S_AXI_ARPROT;
 STUFF_AXI_ARVALID   <= STUFF_S_AXI_ARVALID ;
 STUFF_S_AXI_ARREADY  <= STUFF_AXI_ARREADY ;
 STUFF_S_AXI_RDATA   <= STUFF_AXI_RDATA;
 STUFF_S_AXI_RRESP   <= STUFF_AXI_RRESP;
 STUFF_S_AXI_RVALID   <= STUFF_AXI_RVALID  ;
 STUFF_AXI_RREADY   <= STUFF_S_AXI_RREADY  ;

	

	
	
-- front end deskew and alignment

front_end_inst: front_end 
port map(
    afe_p           => afe_p_array,
    afe_n           => afe_n_array,
    
    afe_clk_p       => afe_clk_p,
    afe_clk_n       => afe_clk_n,
    clock           => clock,
    clk125          => clk125,
    clk500          => clk500,
    dout            => din_full_array,
    trig            => trig,
    trig_IN         => trig_IN,
	S_AXI_ACLK	    => FRONT_END_S_AXI_ACLK,
	S_AXI_ARESETN	=> FRONT_END_S_AXI_ARESETN,
	S_AXI_AWADDR	=> FE_AXI_AWADDR,
	S_AXI_AWPROT	=> FE_AXI_AWPROT,
	S_AXI_AWVALID	=> FE_AXI_AWVALID,
	S_AXI_AWREADY	=> FE_AXI_AWREADY,
	S_AXI_WDATA	    => FE_AXI_WDATA,
	S_AXI_WSTRB	    => FE_AXI_WSTRB,
	S_AXI_WVALID	=> FE_AXI_WVALID,
	S_AXI_WREADY	=> FE_AXI_WREADY,
	S_AXI_BRESP	    => FE_AXI_BRESP,
	S_AXI_BVALID	=> FE_AXI_BVALID,
	S_AXI_BREADY	=> FE_AXI_BREADY,
	S_AXI_ARADDR	=> FE_AXI_ARADDR,
	S_AXI_ARPROT	=> FE_AXI_ARPROT,
	S_AXI_ARVALID	=> FE_AXI_ARVALID,
	S_AXI_ARREADY	=> FE_AXI_ARREADY,
	S_AXI_RDATA	    => FE_AXI_RDATA,
	S_AXI_RRESP	    => FE_AXI_RRESP,
	S_AXI_RVALID	=> FE_AXI_RVALID,
	S_AXI_RREADY	=> FE_AXI_RREADY
  );

-- Input spy buffers

spybuffers_inst: spybuffers
port map(
    clock           => clock,
    trig            => spybuffer_trig,
    din             => din_full_array,
    timestamp       => timestamp,
	S_AXI_ACLK	    => SPY_BUF_S_S_AXI_ACLK,
	S_AXI_ARESETN	=> SPY_BUF_S_S_AXI_ARESETN,
	S_AXI_AWADDR	=> SB_AXI_AWADDR,
	S_AXI_AWPROT	=> SB_AXI_AWPROT,
	S_AXI_AWVALID	=> SB_AXI_AWVALID,
	S_AXI_AWREADY	=> SB_AXI_AWREADY,
	S_AXI_WDATA	    => SB_AXI_WDATA,
	S_AXI_WSTRB	    => SB_AXI_WSTRB,
	S_AXI_WVALID	=> SB_AXI_WVALID,
	S_AXI_WREADY	=> SB_AXI_WREADY,
	S_AXI_BRESP	    => SB_AXI_BRESP,
	S_AXI_BVALID	=> SB_AXI_BVALID,
	S_AXI_BREADY	=> SB_AXI_BREADY,
	S_AXI_ARADDR	=> SB_AXI_ARADDR,
	S_AXI_ARPROT	=> SB_AXI_ARPROT,
	S_AXI_ARVALID	=> SB_AXI_ARVALID,
	S_AXI_ARREADY	=> SB_AXI_ARREADY,
	S_AXI_RDATA	    => SB_AXI_RDATA,
	S_AXI_RRESP	    => SB_AXI_RRESP,
	S_AXI_RVALID	=> SB_AXI_RVALID,
	S_AXI_RREADY	=> SB_AXI_RREADY
  );

-- Timing Endpoint

timing_bridge_inst: entity work.legacy_timing_subsystem_bridge
port map(
    sysclk_p                 => sysclk_p,
    sysclk_n                 => sysclk_n,
    sfp_tmg_los              => sfp_tmg_los,
    rx0_tmg_p                => rx0_tmg_p,
    rx0_tmg_n                => rx0_tmg_n,
    sfp_tmg_tx_dis           => sfp_tmg_tx_dis,
    tx0_tmg_p                => tx0_tmg_p,
    tx0_tmg_n                => tx0_tmg_n,
    clock_gen_debug_o        => sysclk_ibuf,
    mmcm0_100mhz_clk_debug_o => mmcm0_clkout2,
    ep_62p5mhz_clk_debug_o   => ep_clk62p5,
    f_ok_debug_o             => f_ok,
    sctr_debug_o             => sctr,
    cctr_debug_o             => cctr,
    mclk_o                   => open,
    clock_o                  => clock,
    clk500_o                 => clk500,
    clk125_o                 => clk125,
    sclk200_o                => open,
    timestamp_o              => timestamp,
    sync_o                   => ti_trigger_reg,
    sync_stb_o               => ti_trigger_stbr_reg,
    timing_stat_o            => timing_stat,
    s_axi_aclk               => END_P_S_AXI_ACLK,
    s_axi_aresetn            => END_P_S_AXI_ARESETN,
    s_axi_awaddr             => EP_AXI_AWADDR,
    s_axi_awprot             => EP_AXI_AWPROT,
    s_axi_awvalid            => EP_AXI_AWVALID,
    s_axi_awready            => EP_AXI_AWREADY,
    s_axi_wdata              => EP_AXI_WDATA,
    s_axi_wstrb              => EP_AXI_WSTRB,
    s_axi_wvalid             => EP_AXI_WVALID,
    s_axi_wready             => EP_AXI_WREADY,
    s_axi_bresp              => EP_AXI_BRESP,
    s_axi_bvalid             => EP_AXI_BVALID,
    s_axi_bready             => EP_AXI_BREADY,
    s_axi_araddr             => EP_AXI_ARADDR,
    s_axi_arprot             => EP_AXI_ARPROT,
    s_axi_arvalid            => EP_AXI_ARVALID,
    s_axi_arready            => EP_AXI_ARREADY,
    s_axi_rdata              => EP_AXI_RDATA,
    s_axi_rresp              => EP_AXI_RRESP,
    s_axi_rvalid             => EP_AXI_RVALID,
    s_axi_rready             => EP_AXI_RREADY
);

ti_trigger_en <= '1' when ( ti_trigger_reg=adhoc and ti_trigger_stbr_reg='1' ) else '0';
spybuffer_trig <= trig or trig_en_total;
-- SPI master for AFEs and associated DACs
trig_proc: process(clock) -- note external trigger input is inverted on DAPHNE2
    begin
        if rising_edge(clock) then
            ti_trigger_en0 <= ti_trigger_en;
            ti_trigger_en1 <= ti_trigger_en0;
            ti_trigger_en2 <= ti_trigger_en1;
            trig_en_total <= ti_trigger_en0 or ti_trigger_en1 or ti_trigger_en2;
        end if;
    end process trig_proc;

spim_afe_inst: spim_afe 
port map(
    afe_rst       => afe_rst,
    afe_pdn       => afe_pdn,
    afe0_miso     => afe0_miso,
    afe0_sclk     => afe0_sclk,
    afe0_mosi     => afe0_mosi,
    afe12_miso    => afe12_miso,
    afe12_sclk    => afe12_sclk,
    afe12_mosi    => afe12_mosi,
    afe34_miso    => afe34_miso,
    afe34_sclk    => afe34_sclk,
    afe34_mosi    => afe34_mosi,
    afe_sen       => afe_sen,
    trim_sync_n   => trim_sync_n,
    trim_ldac_n   => trim_ldac_n,
    offset_sync_n => offset_sync_n,
    offset_ldac_n => offset_ldac_n,

    S_AXI_ACLK	     => AFE_SPI_S_AXI_ACLK,
	S_AXI_ARESETN	 => AFE_SPI_S_AXI_ARESETN,
	S_AXI_AWADDR	 => AFE_AXI_AWADDR,
	S_AXI_AWPROT	 => AFE_AXI_AWPROT,
	S_AXI_AWVALID	 => AFE_AXI_AWVALID,
	S_AXI_AWREADY	 => AFE_AXI_AWREADY,
	S_AXI_WDATA	     => AFE_AXI_WDATA,
	S_AXI_WSTRB	     => AFE_AXI_WSTRB,
	S_AXI_WVALID	 => AFE_AXI_WVALID,
	S_AXI_WREADY	 => AFE_AXI_WREADY,
	S_AXI_BRESP	     => AFE_AXI_BRESP,
	S_AXI_BVALID     => AFE_AXI_BVALID,
	S_AXI_BREADY	 => AFE_AXI_BREADY,
	S_AXI_ARADDR     => AFE_AXI_ARADDR,
	S_AXI_ARPROT     => AFE_AXI_ARPROT,
	S_AXI_ARVALID    => AFE_AXI_ARVALID,
	S_AXI_ARREADY    => AFE_AXI_ARREADY,
	S_AXI_RDATA      => AFE_AXI_RDATA,
	S_AXI_RRESP      => AFE_AXI_RRESP,
	S_AXI_RVALID     => AFE_AXI_RVALID,
	S_AXI_RREADY     => AFE_AXI_RREADY
  );

-- I2C master


-- SPI master for 3 DACs

spim_dac_inst: spim_dac 
port map(
    dac_sclk        => dac_sclk,
    dac_din         => dac_din,
    dac_sync_n      => dac_sync_n,
    dac_ldac_n      => dac_ldac_n, 
    S_AXI_ACLK	    => SPI_DAC_S_AXI_ACLK,
	S_AXI_ARESETN	=> SPI_DAC_S_AXI_ARESETN,
	S_AXI_AWADDR	=> DAC_AXI_AWADDR,
	S_AXI_AWPROT	=> DAC_AXI_AWPROT,
	S_AXI_AWVALID	=> DAC_AXI_AWVALID,
	S_AXI_AWREADY	=> DAC_AXI_AWREADY,
	S_AXI_WDATA	    => DAC_AXI_WDATA,
	S_AXI_WSTRB	    => DAC_AXI_WSTRB,
	S_AXI_WVALID	=> DAC_AXI_WVALID,
	S_AXI_WREADY	=> DAC_AXI_WREADY,
	S_AXI_BRESP	    => DAC_AXI_BRESP,
	S_AXI_BVALID	=> DAC_AXI_BVALID,
	S_AXI_BREADY	=> DAC_AXI_BREADY,
	S_AXI_ARADDR	=> DAC_AXI_ARADDR,
	S_AXI_ARPROT	=> DAC_AXI_ARPROT,
	S_AXI_ARVALID	=> DAC_AXI_ARVALID,
	S_AXI_ARREADY	=> DAC_AXI_ARREADY,
	S_AXI_RDATA	    => DAC_AXI_RDATA,
	S_AXI_RRESP	    => DAC_AXI_RRESP,
	S_AXI_RVALID	=> DAC_AXI_RVALID,
	S_AXI_RREADY	=> DAC_AXI_RREADY
  );

-- SPI master for current monitor


-- Misc. Stuff
 
stuff_inst: stuff
port map(
    fan_tach        => fan_tach,
    fan_ctrl        => fan_ctrl,
    hvbias_en       => hvbias_en,
    mux_en          => mux_en,
    mux_a           => mux_a,
    stat_led        => stat_led,
    version         => version,
    adhoc           => adhoc,
    core_chan_enable        => core_chan_enable,
    filter_output_selector  => filter_output_selector,
    afe_comp_enable         => afe_comp_enable,
    invert_enable   => invert_enable,
    st_config       => st_config,
    signal_delay    => signal_delay,
    reset_st_counters => reset_st_counters,
    S_AXI_ACLK	    => STUFF_S_AXI_ACLK,
	S_AXI_ARESETN	=> STUFF_S_AXI_ARESETN,
	S_AXI_AWADDR	=> STUFF_AXI_AWADDR,
	S_AXI_AWPROT	=> STUFF_AXI_AWPROT,
	S_AXI_AWVALID	=> STUFF_AXI_AWVALID,
	S_AXI_AWREADY	=> STUFF_AXI_AWREADY,
	S_AXI_WDATA	    => STUFF_AXI_WDATA,
	S_AXI_WSTRB	    => STUFF_AXI_WSTRB,
	S_AXI_WVALID	=> STUFF_AXI_WVALID,
	S_AXI_WREADY	=> STUFF_AXI_WREADY,
	S_AXI_BRESP	    => STUFF_AXI_BRESP,
	S_AXI_BVALID	=> STUFF_AXI_BVALID,
	S_AXI_BREADY	=> STUFF_AXI_BREADY,
	S_AXI_ARADDR	=> STUFF_AXI_ARADDR,
	S_AXI_ARPROT	=> STUFF_AXI_ARPROT,
	S_AXI_ARVALID	=> STUFF_AXI_ARVALID,
	S_AXI_ARREADY	=> STUFF_AXI_ARREADY,
	S_AXI_RDATA	    => STUFF_AXI_RDATA,
	S_AXI_RRESP	    => STUFF_AXI_RRESP,
	S_AXI_RVALID	=> STUFF_AXI_RVALID,
	S_AXI_RREADY	=> STUFF_AXI_RREADY
  );

-- reduce din_array, since we don't need the full 45 channels * 16 bits for the core

gena_din: for a in 4 downto 0 generate
genc_din: for c in 7 downto 0 generate

    din_array(a)(c)(13 downto 0) <= din_full_array(a)(c)(15 downto 2);

end generate genc_din;
end generate gena_din;

-- core logic is 40 self-trig senders + 10G Ethernet sender

selftrigger_plane_inst: entity work.legacy_selftrigger_plane_bridge
port map(
    link_id => link_id,
    slot_id => slot_id,
    crate_id => crate_id,
    detector_id => detector_id,
    -- threshold  => threshold,
    version => version_id,
    filter_output_selector => filter_output_selector,
    afe_comp_enable => afe_comp_enable,
    invert_enable => invert_enable,
    st_config => st_config,
    signal_delay => signal_delay,
    clock => clock,
    reset => '0', 
    reset_st_counters => reset_st_counters,
    timestamp => timestamp,
    din_core => din_full_array,
    enable => core_chan_enable, 
    forcetrig =>  FORCE_TRIG,
    st_trigger_signal => st_trigger_signal,
    adhoc => adhoc,
    ti_trigger => ti_trigger_reg,
    ti_trigger_stbr => ti_trigger_stbr_reg,
    trirg_s_axi_aclk   => TRIRG_S_AXI_ACLK,
    trirg_s_axi_aresetn => TRIRG_S_AXI_ARESETN,
    trirg_s_axi_awaddr => TRIRG_S_AXI_AWADDR,
    trirg_s_axi_awprot => TRIRG_S_AXI_AWPROT,
    trirg_s_axi_awvalid => TRIRG_S_AXI_AWVALID,
    trirg_s_axi_awready => TRIRG_S_AXI_AWREADY,
    trirg_s_axi_wdata => TRIRG_S_AXI_WDATA,
    trirg_s_axi_wstrb => TRIRG_S_AXI_WSTRB,
    trirg_s_axi_wvalid => TRIRG_S_AXI_WVALID,
    trirg_s_axi_wready => TRIRG_S_AXI_WREADY,
    trirg_s_axi_bresp => TRIRG_S_AXI_BRESP,
    trirg_s_axi_bvalid => TRIRG_S_AXI_BVALID,
    trirg_s_axi_bready => TRIRG_S_AXI_BREADY,
    trirg_s_axi_araddr => TRIRG_S_AXI_ARADDR,
    trirg_s_axi_arprot => TRIRG_S_AXI_ARPROT,
    trirg_s_axi_arvalid => TRIRG_S_AXI_ARVALID,
    trirg_s_axi_arready => TRIRG_S_AXI_ARREADY,
    trirg_s_axi_rdata => TRIRG_S_AXI_RDATA,
    trirg_s_axi_rresp => TRIRG_S_AXI_RRESP,
    trirg_s_axi_rvalid => TRIRG_S_AXI_RVALID,
    trirg_s_axi_rready => TRIRG_S_AXI_RREADY,
    thresh_s_axi_aclk => THRESH_S_AXI_ACLK,
    thresh_s_axi_aresetn => THRESH_S_AXI_ARESETN,
    thresh_s_axi_awaddr => THRESH_S_AXI_AWADDR,
    thresh_s_axi_awprot => THRESH_S_AXI_AWPROT,
    thresh_s_axi_awvalid => THRESH_S_AXI_AWVALID,
    thresh_s_axi_awready => THRESH_S_AXI_AWREADY,
    thresh_s_axi_wdata => THRESH_S_AXI_WDATA,
    thresh_s_axi_wstrb => THRESH_S_AXI_WSTRB,
    thresh_s_axi_wvalid => THRESH_S_AXI_WVALID,
    thresh_s_axi_wready => THRESH_S_AXI_WREADY,
    thresh_s_axi_bresp => THRESH_S_AXI_BRESP,
    thresh_s_axi_bvalid => THRESH_S_AXI_BVALID,
    thresh_s_axi_bready => THRESH_S_AXI_BREADY,
    thresh_s_axi_araddr => THRESH_S_AXI_ARADDR,
    thresh_s_axi_arprot => THRESH_S_AXI_ARPROT,
    thresh_s_axi_arvalid => THRESH_S_AXI_ARVALID,
    thresh_s_axi_arready => THRESH_S_AXI_ARREADY,
    thresh_s_axi_rdata => THRESH_S_AXI_RDATA,
    thresh_s_axi_rresp => THRESH_S_AXI_RRESP,
    thresh_s_axi_rvalid => THRESH_S_AXI_RVALID,
    thresh_s_axi_rready => THRESH_S_AXI_RREADY,
    outbuff_s_axi_aclk => OUTBUFF_S_AXI_ACLK,
    outbuff_s_axi_aresetn => OUTBUFF_S_AXI_ARESETN,
    outbuff_s_axi_awaddr => OUTBUFF_S_AXI_AWADDR,
    outbuff_s_axi_awprot => OUTBUFF_S_AXI_AWPROT,
    outbuff_s_axi_awvalid => OUTBUFF_S_AXI_AWVALID,
    outbuff_s_axi_awready => OUTBUFF_S_AXI_AWREADY,
    outbuff_s_axi_wdata => OUTBUFF_S_AXI_WDATA,
    outbuff_s_axi_wstrb => OUTBUFF_S_AXI_WSTRB,
    outbuff_s_axi_wvalid => OUTBUFF_S_AXI_WVALID,
    outbuff_s_axi_wready => OUTBUFF_S_AXI_WREADY,
    outbuff_s_axi_bresp => OUTBUFF_S_AXI_BRESP,
    outbuff_s_axi_bvalid => OUTBUFF_S_AXI_BVALID,
    outbuff_s_axi_bready => OUTBUFF_S_AXI_BREADY,
    outbuff_s_axi_araddr => OUTBUFF_S_AXI_ARADDR,
    outbuff_s_axi_arprot => OUTBUFF_S_AXI_ARPROT,
    outbuff_s_axi_arvalid => OUTBUFF_S_AXI_ARVALID,
    outbuff_s_axi_arready => OUTBUFF_S_AXI_ARREADY,
    outbuff_s_axi_rdata => OUTBUFF_S_AXI_RDATA,
    outbuff_s_axi_rresp => OUTBUFF_S_AXI_RRESP,
    outbuff_s_axi_rvalid => OUTBUFF_S_AXI_RVALID,
    outbuff_s_axi_rready => OUTBUFF_S_AXI_RREADY,
    eth_clk_p => eth_clk_p,
    eth_clk_n => eth_clk_n,
    eth0_rx_p => eth0_rx_p,
    eth0_rx_n => eth0_rx_n,
    eth0_tx_p => eth0_tx_p,
    eth0_tx_n => eth0_tx_n,
    eth0_tx_dis => eth0_tx_dis,
    out_buff_data => out_buff_data,
    out_buff_trig => out_buff_trig,
    valid_debug => VALID_DEBUG,
    last_debug => LAST_DEBUG
);

    --time_stamp_debug <= timestamp;
    --syclk_62p5 <= clk_62p5_debug;
   -- ep_rx_tmg_debug <= ep_rx_debug;
    --mmcm0_locked <= ep_mmcm0_locked ;
    --mmcm1_locked <= ep_mmcm1_locked;
   -- ep_status <= ep_stat_debug;
   -- ep_resets <= ep_reset_debug;
    DIN_DEBUG  <= din_debug_reg; 
    --Trigered_debug <= trigered_debug_reg;
    out_buff_clk <= clock;
    
   -- endpoint debug signals
   
 F_OK_DEBUG <= f_ok;
 SCTR_DEBUG <= sctr;
 cCTR_DEBUG <= cctr;
clock_gen_debug  <= sysclk_ibuf;
mmcm0_100MHZ_CLK_debug   <= mmcm0_clkout2;
ep_62p5MHZ_CLK_debug   <=   ep_clk62p5 ;
    
    
    
-- TO DO: add Xilinx IP block: ZYNQ_PS
-- this IP block requires parameters that must be set by the TCL build script

-- TO DO: add Xilinx IP block: AXI SmartConnecct
-- this IP block requires parameters that must be set by the TCL build script

-- Jonathan recommends we make a top level graphical block with the ZYNQ_PS and 
-- AXI SmartConnect blocks wired up. Bring the 9 AXI-Lite buses to "IO pins" on this 
-- block diagram, THEN export the block as VHDL. Instantiate that HERE. This way we 
-- can keep the project top level as VHDL and keep it GIT friendly.

end daphne_selftrigger_top_arch;
