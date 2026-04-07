-- front_end.vhd
--
-- DAPHNE V3 AFE front end. This version is different from the DAPHNE V2 design in 
-- that the bit delay and word alignment logic is no longer automatic in the FPGA logic.
-- These adjustments are now done by the Kria CPU so that we can calibrate the AFE input 
-- timing using SOFTWARE control in the USERSPACE. This will be more flexible and more reliable
-- and it will also provide better feedback to the user about timing margins, etc.
--
-- The bit and word alignment values can be changed at any time and these values are unique for
-- each AFE group (5 total). The assumption is that signals within an AFE group are tightly 
-- matched on the PCB layout. So make adjustments to get the FCLK pattern properly aligned, then
-- those same settings will automatically be applied to all other bits in the group.
--
-- NOTE: AFEs must be configured for 16 bit transmission mode, LSb First!
--
-- The suggested calibration procedure is:
--
-- 0. disable IDELAY voltage/temperature compensation (EN_VTC=0)
-- 1. Look at the FCLK data word (trigger and read spy buffers), sweep the delay values (512 steps) and determine the bit edges by observing 
--    when the word value changes. Choose a delay tap value in the middle of a bit.
-- 2. Try different values of BITSLIP until the FCLK word reads 0x00FF
-- 3. put the AFE chip into one of the test modes, recommend count up
-- 4. read data channels (spy buffers), verify that it is counting up properly for each data channel
-- 5. put AFE back into normal data mode, 
-- 6. repeat for remaining AFE groups
-- 7. enable IDELAY voltage/temperature compensation (EN_VTC=1)
--
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.daphne_package.all;

entity front_end is
port(

    -- AFE interface: 

    afe_p, afe_n: in array_5x9_type; -- 5 x 9 = 45 LVDS pairs (7..0 = data, 8 = fclk)
    afe_clk_p, afe_clk_n: out std_logic; -- copy of 62.5MHz master clock fanned out to AFEs

    -- high speed FPGA fabric interface:

    clk500:  in  std_logic; -- 500MHz bit clock (these 3 clocks must be related/aligned)
    clk125:  in  std_logic; -- 125MHz byte clock
    clock:   in  std_logic; -- 62.5MHz master clock
    dout:    out array_5x9x16_type; -- data synchronized to clock
    trig:    out std_logic; -- user generated trigger
    trig_IN: IN std_logic ;
    -- AXI-Lite interface:

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
end front_end;

architecture fe_arch of front_end is
begin
    -- Keep the legacy entity and port contract while delegating the actual
    -- frontend capture/alignment implementation to the composable island.
    frontend_island_inst : entity work.frontend_island
        generic map (
            AFE_COUNT_G => 5
        )
        port map (
            afe_p         => afe_p,
            afe_n         => afe_n,
            afe_clk_p     => afe_clk_p,
            afe_clk_n     => afe_clk_n,
            clk500        => clk500,
            clk125        => clk125,
            clock         => clock,
            dout          => dout,
            trig          => trig,
            trig_IN       => trig_IN,
            S_AXI_ACLK    => S_AXI_ACLK,
            S_AXI_ARESETN => S_AXI_ARESETN,
            S_AXI_AWADDR  => S_AXI_AWADDR,
            S_AXI_AWPROT  => S_AXI_AWPROT,
            S_AXI_AWVALID => S_AXI_AWVALID,
            S_AXI_AWREADY => S_AXI_AWREADY,
            S_AXI_WDATA   => S_AXI_WDATA,
            S_AXI_WSTRB   => S_AXI_WSTRB,
            S_AXI_WVALID  => S_AXI_WVALID,
            S_AXI_WREADY  => S_AXI_WREADY,
            S_AXI_BRESP   => S_AXI_BRESP,
            S_AXI_BVALID  => S_AXI_BVALID,
            S_AXI_BREADY  => S_AXI_BREADY,
            S_AXI_ARADDR  => S_AXI_ARADDR,
            S_AXI_ARPROT  => S_AXI_ARPROT,
            S_AXI_ARVALID => S_AXI_ARVALID,
            S_AXI_ARREADY => S_AXI_ARREADY,
            S_AXI_RDATA   => S_AXI_RDATA,
            S_AXI_RRESP   => S_AXI_RRESP,
            S_AXI_RVALID  => S_AXI_RVALID,
            S_AXI_RREADY  => S_AXI_RREADY
        );

end fe_arch;
