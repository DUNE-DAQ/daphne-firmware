-- stuff.vhd
--
-- this module is a "catch all" for a bunch of misc stuff that exists on the PL side
-- and needs to connect to the PS side via a single axi-lite interface.
--
-- "stuff" has some 32-bit registers:
--
-- base+00: fan speed control register, 8 bits, R/W. 
--          0x00=off, 0xFF=full speed. power on default is full speed.
-- base+04: fan0 speed in RPM, 12 bits unsigned, R/O
-- base+08: fan1 speed in RPM, 12 bits unsigned, R/O
-- base+12: vbias control, one bit, R/W
-- base+16: analog mux enable lines (mux_en), 2 bits, R/W
-- base+20: analog mux address lines (mux_a), 2 bits, R/W
-- base+24: status LEDs, 6 bits, R/W
-- base+28: the GIT commit number, 28 bits, R/O
-- base+32: self triggered mode channel enable ch31..ch00 (31..0) R/W 
-- base+36: self triggered mode channel enable ch39..ch32 (7..0) R/W 
-- base+40: adhoc trigger configuration command, 8 bits, R/W
-- base+44: self triggered peak descriptor calculator configuration, 14 bits, R/W
-- base+48: self triggered signal delay configuration, 5 bits, R/W
-- base+52: self triggered filter output configuration, 2 bits, R/W
-- base+56: self triggered counter flags reset, 1 bit, R/W
-- base+60: self triggered mode channel afe compensation enable ch31..ch00 (31..0) R/W
-- base+64: self triggered mode channel afe compensation enable ch31..ch00 (31..0) R/W
-- base+68: self triggered mode channel inversion enable ch31..ch00 (31..0) R/W
-- base+72: self triggered mode channel inversion enable ch39..ch32 (7..0) R/W

-- *** TO DO: (UPDATE: NOT ANYMORE!)
-- base+32: link_id(5..0) R/W 
-- base+36: slot_id(3..0) R/W 
-- base+40: crate_id(9..0) R/W 
-- base+44: detector_id(5..0) R/W 
-- base+48: version_id(5..0) R/W 
-- base+52: threshold(13..0) R/W 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;

entity stuff is
port(
    fan_tach: in  std_logic_vector(1 downto 0); -- fan tach speed monitoring
    fan_ctrl: out std_logic; -- pwm speed control common to both fans
    hvbias_en: out std_logic; -- high = high voltage bias generator is ON
    mux_en: out std_logic_vector(1 downto 0); -- analog mux enables
    mux_a: out std_logic_vector(1 downto 0); -- analog mux selects
    stat_led: out std_logic_vector(5 downto 0); -- general purpose LEDs
    version: in std_logic_vector(27 downto 0); -- GIT version number
    core_chan_enable: out std_logic_vector(39 downto 0); -- channel enables for self-trig core
    adhoc: out std_logic_vector(7 downto 0); -- command for adhoc trigger
    filter_output_selector: out std_logic_vector(1 downto 0); -- filter configuration (Esteban)
    afe_comp_enable: out std_logic_vector(39 downto 0); -- enable digital afe compensator
    invert_enable: out std_logic_vector(39 downto 0); -- invert signal polarity
    st_config: out std_logic_vector(13 downto 0); -- Config param for self-trigger and peak descriptor calculation
    signal_delay: out std_logic_vector(4 downto 0); -- amount of delays to set for Self Trigger Latency (8 x signal_delay, signal delay is from 0 to 31 tics)
    reset_st_counters: out std_logic; -- reset for self trigger counter flags

    -- AXI-LITE interface

	S_AXI_ACLK	    : in std_logic; -- assume this is 100MHz
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
end stuff;

architecture stuff_arch of stuff is

	signal axi_awaddr: std_logic_vector(31 downto 0);
	signal axi_awready: std_logic;
	signal axi_wready: std_logic;
	signal axi_bresp: std_logic_vector(1 downto 0);
	signal axi_bvalid: std_logic;
	signal axi_araddr: std_logic_vector(31 downto 0);
	signal axi_arready: std_logic;
	signal axi_rdata: std_logic_vector(31 downto 0);
	signal axi_rresp: std_logic_vector(1 downto 0);
	signal axi_rvalid: std_logic;
	signal axi_arready_reg: std_logic;
    signal axi_arvalid: std_logic;    
	signal reg_rden: std_logic;
	signal reg_wren: std_logic;
	signal reg_wren_full: std_logic;
	signal reg_data_out:std_logic_vector(31 downto 0);
	signal aw_en: std_logic;
   
    component fanmon is
    port(
        clock: in std_logic;
        reset: in std_logic;
        tach: in std_logic;
        rpm: out std_logic_vector(11 downto 0)
      );
    end component;

    signal reset: std_logic;
    signal fan_count_reg: std_logic_vector(11 downto 0) := X"000";
    signal fan_speed_cfg_reg: std_logic_vector(7 downto 0);
    signal fan_ctrl_reg: std_logic;
    signal fan0_rpm, fan1_rpm: std_logic_vector(11 downto 0);
    signal stat_led_reg: std_logic_vector(5 downto 0) := "000000";
    signal hvbias_en_reg: std_logic := '0';
    signal mux_a_reg, mux_en_reg: std_logic_vector(1 downto 0) := "00";
    signal core_enable_reg: std_logic_vector(39 downto 0) := DEFAULT_core_enable;
    signal adhoc_reg: std_logic_vector(7 downto 0) := DEFAULT_st_adhoc_command; 
    signal reset_st_counters_reg: std_logic := '0';
    signal signal_delay_reg: std_logic_vector(4 downto 0) := DEFAULT_st_config_command(20 downto 16);
    signal st_config_reg: std_logic_vector(13 downto 0) := DEFAULT_st_config_command(15 downto 2); 
    signal filter_output_selector_reg: std_logic_vector(1 downto 0) := DEFAULT_st_config_command(1 downto 0); 
    signal afe_comp_enable_reg: std_logic_vector(39 downto 0) := DEFAULT_st_comp_command;
    signal invert_enable_reg: std_logic_vector(39 downto 0) := DEFAULT_st_invert_command;
    signal selftrigger_reg_data_out: std_logic_vector(31 downto 0);
    signal selftrigger_reg_hit: std_logic;

    -- register offsets are relative to the base address specified for this AXI-LITE slave instance

    constant FANCTRL_OFFSET:                std_logic_vector(6 downto 0) := "0000000"; -- base+0
    constant FAN0SPD_OFFSET:                std_logic_vector(6 downto 0) := "0000100"; -- base+4
    constant FAN1SPD_OFFSET:                std_logic_vector(6 downto 0) := "0001000"; -- base+8
    constant HVBIAS_OFFSET:                 std_logic_vector(6 downto 0) := "0001100"; -- base+12
    constant MUXEN_OFFSET:                  std_logic_vector(6 downto 0) := "0010000"; -- base+16
    constant MUXA_OFFSET:                   std_logic_vector(6 downto 0) := "0010100"; -- base+20
    constant LED_OFFSET:                    std_logic_vector(6 downto 0) := "0011000"; -- base+24
    constant VER_OFFSET:                    std_logic_vector(6 downto 0) := "0011100"; -- base+28
    constant CORE_EN_LO_OFFSET:             std_logic_vector(6 downto 0) := "0100000"; -- base+32
    constant CORE_EN_HI_OFFSET:             std_logic_vector(6 downto 0) := "0100100"; -- base+36
    constant ST_ADHOC_OFFSET:               std_logic_vector(6 downto 0) := "0101000"; -- base+40
    constant ST_CONFIG_OFFSET:              std_logic_vector(6 downto 0) := "0101100"; -- base+44
    constant ST_DELAY_OFFSET:               std_logic_vector(6 downto 0) := "0110000"; -- base+48
    constant ST_FILTER_OUTPUT_SEL_OFFSET:   std_logic_vector(6 downto 0) := "0110100"; -- base+52
    constant ST_RESET_COUNTERS_OFFSET:      std_logic_vector(6 downto 0) := "0111000"; -- base+56
    constant ST_AFE_COMP_ENABLE_LO_OFFSET:  std_logic_vector(6 downto 0) := "0111100"; -- base+60
    constant ST_AFE_COMP_ENABLE_HI_OFFSET:  std_logic_vector(6 downto 0) := "1000000"; -- base+64
    constant ST_INVERT_ENABLE_LO_OFFSET:    std_logic_vector(6 downto 0) := "1000100"; -- base+68
    constant ST_INVERT_ENABLE_HI_OFFSET:    std_logic_vector(6 downto 0) := "1001000"; -- base+72

begin

reset <= not S_AXI_ARESETN;

-- fan pwm control logic

-- The fan speed is directly proportional to the duty cycle of the PWM signal. 
-- Internally the fans have an analog circuit to do this, so the fan speed is 
-- in theory infinitely adjustable.

-- The output fan_ctrl is inverted by Q2 on the board and is common to both fans.
--
-- if fan_ctrl=0 the fan PWM signal will be HIGH and fans run at FULL SPEED. 
-- if fan_ctrl=1 the PWM signal will be LOW and the fans will be STOPPED.
-- if fan_ctrl is 25kHz clock (high 25%, low 75%) then the fans will be running at 75%
-- if fan_ctrl is 25kHz clock (high 75%, low 25%) then the fans will be running at 25%

-- take the 100MHz AXI clock and divide it by 4096 to produce 24.4kHz clock
-- suitable for driving the fan speed pwm signal. duty cycle is controlled by
-- fan_speed_cfg_reg: 0 = fan off, 255 = fan full speed.

fanspeed_proc: process(S_AXI_ACLK)
begin
    if rising_edge(S_AXI_ACLK) then
        if (reset='1') then
            fan_count_reg <= (others=>'0');
            fan_ctrl_reg <= '0';
        else
            fan_count_reg <= std_logic_vector( unsigned(fan_count_reg) + 1 );
            if (fan_count_reg = X"000") then
                fan_ctrl_reg <= '1'; 
            elsif (fan_count_reg(11 downto 4)=fan_speed_cfg_reg) then
                fan_ctrl_reg <= '0';
            end if;
        end if;
    end if;
end process fanspeed_proc;

-- fan speed monitoring

fanmon0_inst: fanmon
port map( clock => S_AXI_ACLK, reset => reset, tach => fan_tach(0), rpm => fan0_rpm );

fanmon1_inst: fanmon
port map( clock => S_AXI_ACLK, reset => reset, tach => fan_tach(1), rpm => fan1_rpm );

selftrigger_reg_bank_inst: entity work.legacy_stuff_selftrigger_register_bank
port map(
    clk                      => S_AXI_ACLK,
    resetn                   => S_AXI_ARESETN,
    reg_wren_i               => reg_wren_full,
    reg_addr_i               => axi_awaddr(6 downto 0),
    reg_wdata_i              => S_AXI_WDATA,
    reg_raddr_i              => axi_araddr(6 downto 0),
    reg_rdata_o              => selftrigger_reg_data_out,
    reg_rhit_o               => selftrigger_reg_hit,
    core_chan_enable_o       => core_enable_reg,
    adhoc_o                  => adhoc_reg,
    filter_output_selector_o => filter_output_selector_reg,
    afe_comp_enable_o        => afe_comp_enable_reg,
    invert_enable_o          => invert_enable_reg,
    st_config_o              => st_config_reg,
    signal_delay_o           => signal_delay_reg,
    reset_st_counters_o      => reset_st_counters_reg
);

-- AXI-LITE slave interface logic

S_AXI_AWREADY <= axi_awready;
S_AXI_WREADY <= axi_wready;
S_AXI_BRESP	<= axi_bresp;
S_AXI_BVALID <= axi_bvalid;
S_AXI_ARREADY <= axi_arready;
S_AXI_RDATA	<= axi_rdata;
S_AXI_RRESP	<= axi_rresp;
S_AXI_RVALID <= axi_rvalid;

-- Implement axi_awready generation
-- axi_awready is asserted for one S_AXI_ACLK clock cycle when both
-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
-- de-asserted when reset is low.

process (S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then 
    if S_AXI_ARESETN = '0' then
      axi_awready <= '0';
      aw_en <= '1';
    else
      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
        -- slave is ready to accept write address when
        -- there is a valid write address and write data
        -- on the write address and data bus. This design 
        -- expects no outstanding transactions. 
           axi_awready <= '1';
           aw_en <= '0';
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
           aw_en <= '1';
           axi_awready <= '0';
      else
        axi_awready <= '0';
      end if;
    end if;
  end if;
end process;

-- Implement axi_awaddr latching
-- This process is used to latch the address when both 
-- S_AXI_AWVALID and S_AXI_WVALID are valid. 

process (S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then 
    if S_AXI_ARESETN = '0' then
      axi_awaddr <= (others => '0');
    else
      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
        -- Write Address latching
        axi_awaddr <= S_AXI_AWADDR;
      end if;
    end if;
  end if;                   
end process; 

-- Implement axi_wready generation
-- axi_wready is asserted for one S_AXI_ACLK clock cycle when both
-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
-- de-asserted when reset is low. 

process (S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then 
    if S_AXI_ARESETN = '0' then
      axi_wready <= '0';
    else
      if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
          -- slave is ready to accept write data when 
          -- there is a valid write address and write data
          -- on the write address and data bus. This design 
          -- expects no outstanding transactions.           
          axi_wready <= '1';
      else
        axi_wready <= '0';
      end if;
    end if;
  end if;
end process; 

-- Implement memory mapped register select and write logic generation
-- The write data is accepted and written to memory mapped registers when
-- axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
-- select byte enables of slave registers while writing.
-- These registers are cleared when reset (active low) is applied.
-- Slave register write enable is asserted when valid address and data are available
-- and the slave is ready to accept the write address and write data.

reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;
reg_wren_full <= reg_wren when S_AXI_WSTRB = "1111" else '0';

process (S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then 
    if (S_AXI_ARESETN = '0') then
        fan_speed_cfg_reg <= X"FF";
        hvbias_en_reg <= '0';
        mux_en_reg <= "00";
        mux_a_reg <= "00";
        stat_led_reg <= "000000";
    else
      if (reg_wren = '1' and S_AXI_WSTRB = "1111") then

        -- treat all of these register writes as if they are full 32 bits
        -- e.g. the four write strobe bits should be high

        case ( axi_awaddr(6 downto 0) ) is

          when FANCTRL_OFFSET => 
            fan_speed_cfg_reg <= S_AXI_WDATA(7 downto 0);

          when HVBIAS_OFFSET => 
            hvbias_en_reg <= S_AXI_WDATA(0);

          when MUXEN_OFFSET => 
            mux_en_reg <= S_AXI_WDATA(1 downto 0);

          when MUXA_OFFSET => 
            mux_a_reg <= S_AXI_WDATA(1 downto 0);

          when LED_OFFSET => 
            stat_led_reg <= S_AXI_WDATA(5 downto 0);

          when others =>
            null;
             
        end case;

      end if;
    end if;
  end if;                   
end process; 

-- Implement write response logic generation
-- The write response and response valid signals are asserted by the slave 
-- when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
-- This marks the acceptance of address and indicates the status of 
-- write transaction.

process (S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then 
    if S_AXI_ARESETN = '0' then
      axi_bvalid  <= '0';
      axi_bresp   <= "00"; --need to work more on the responses
    else
      if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
        axi_bvalid <= '1';
        axi_bresp  <= "00"; 
      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then   --check if bready is asserted while bvalid is high)
        axi_bvalid <= '0';                                   -- (there is a possibility that bready is always asserted high)
      end if;
    end if;
  end if;                   
end process; 

-- Implement axi_arready generation
-- axi_arready is asserted for one S_AXI_ACLK clock cycle when
-- S_AXI_ARVALID is asserted. axi_awready is 
-- de-asserted when reset (active low) is asserted. 
-- The read address is also latched when S_AXI_ARVALID is 
-- asserted. axi_araddr is reset to zero on reset assertion.

process (S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then 
    if S_AXI_ARESETN = '0' then
      axi_arready <= '0';
      axi_araddr  <= (others => '1');
    else
      if (axi_arready = '0' and S_AXI_ARVALID = '1') then
        -- indicates that the slave has acceped the valid read address
        axi_arready <= '1';
        -- Read Address latching 
        axi_araddr  <= S_AXI_ARADDR;           
      else
        axi_arready <= '0';
      end if;
    end if;
  end if;                   
end process; 

-- Implement axi_arvalid generation
-- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
-- S_AXI_ARVALID and axi_arready are asserted. The slave registers 
-- data are available on the axi_rdata bus at this instance. The 
-- assertion of axi_rvalid marks the validity of read data on the 
-- bus and axi_rresp indicates the status of read transaction.axi_rvalid 
-- is deasserted on reset (active low). axi_rresp and axi_rdata are 
-- cleared to zero on reset (active low). 

process (S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then
    if S_AXI_ARESETN = '0' then
      axi_rvalid <= '0';
      axi_rresp  <= "00";
    else
      if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
        -- Valid read data is available at the read data bus
        axi_rvalid <= '1';
        axi_rresp  <= "00"; -- 'OKAY' response
      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
        -- Read data is accepted by the master
        axi_rvalid <= '0';
      end if;            
    end if;
  end if;
end process;

-- Implement memory mapped register select and read logic generation
-- Slave register read enable is asserted when valid address is available
-- and the slave is ready to accept the read address.
-- reg_data_out is 32 bits

reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

reg_data_out <= (X"000000" & fan_speed_cfg_reg)                   when (axi_araddr(6 downto 0)=FANCTRL_OFFSET) else
                (X"00000" & fan0_rpm)                             when (axi_araddr(6 downto 0)=FAN0SPD_OFFSET) else
                (X"00000" & fan1_rpm)                             when (axi_araddr(6 downto 0)=FAN1SPD_OFFSET) else
                (X"0000000" & "000" & hvbias_en_reg)              when (axi_araddr(6 downto 0)=HVBIAS_OFFSET) else
                (X"0000000" & "00" & mux_en_reg)                  when (axi_araddr(6 downto 0)=MUXEN_OFFSET) else
                (X"0000000" & "00" & mux_a_reg)                   when (axi_araddr(6 downto 0)=MUXA_OFFSET) else
                (X"000000" & "00" & stat_led_reg)                 when (axi_araddr(6 downto 0)=LED_OFFSET) else
                ("0000" & version)                                when (axi_araddr(6 downto 0)=VER_OFFSET) else
                selftrigger_reg_data_out                          when (selftrigger_reg_hit='1') else
                X"00000000";

-- Output register or memory read data
process( S_AXI_ACLK ) is
begin
  if (rising_edge (S_AXI_ACLK)) then
    if ( S_AXI_ARESETN = '0' ) then
      axi_rdata  <= (others => '0');
    else
      if (reg_rden = '1') then
        -- When there is a valid read address (S_AXI_ARVALID) with 
        -- acceptance of read address by the slave (axi_arready), 
        -- output the read dada 
        -- Read address mux
          axi_rdata <= reg_data_out; -- register read data
      end if;   
    end if;
  end if;
end process;

-- assign registers to the outputs

fan_ctrl <= not fan_ctrl_reg; -- compensate for inverter Q2 on the board
mux_a <= mux_a_reg;
mux_en <= mux_en_reg;
hvbias_en <= hvbias_en_reg;
stat_led <= stat_led_reg; -- PL general board LEDs active high
core_chan_enable <= core_enable_reg;
adhoc <= adhoc_reg;
reset_st_counters <= reset_st_counters_reg;
filter_output_selector <= filter_output_selector_reg;
afe_comp_enable <= afe_comp_enable_reg;
invert_enable <= invert_enable_reg;
st_config <= st_config_reg;
signal_delay <= signal_delay_reg;

end stuff_arch;
