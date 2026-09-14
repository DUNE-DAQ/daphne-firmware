library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;

-- One shared MMCM: 62.5 MHz * 20 / 4 = 312.5 MHz, VCO 1250 MHz.
-- Asynchronous assertion and eight local clock edges of reset recovery.
entity grouped_builder_clock is
  port(clock_i, reset_i : in std_logic;
    builder_clock_o, builder_reset_o, acquisition_reset_o : out std_logic);
end entity grouped_builder_clock;
architecture rtl of grouped_builder_clock is
  signal feedback_s, feedback_buf_s, clock_raw_s, clock_s, locked_s, reset_s : std_logic;
  signal fast_reset_s, adc_reset_s : std_logic_vector(7 downto 0) := (others=>'1');
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of fast_reset_s, adc_reset_s : signal is "TRUE";
begin
  mmcm_inst : MMCME4_BASE
    generic map(BANDWIDTH=>"OPTIMIZED", CLKFBOUT_MULT_F=>20.0,
      CLKIN1_PERIOD=>16.0, CLKOUT0_DIVIDE_F=>4.0, DIVCLK_DIVIDE=>1,
      STARTUP_WAIT=>false)
    port map(CLKIN1=>clock_i, CLKFBIN=>feedback_buf_s, RST=>reset_i, PWRDWN=>'0',
      CLKFBOUT=>feedback_s, CLKFBOUTB=>open, CLKOUT0=>clock_raw_s, CLKOUT0B=>open,
      CLKOUT1=>open, CLKOUT1B=>open, CLKOUT2=>open, CLKOUT2B=>open,
      CLKOUT3=>open, CLKOUT3B=>open, CLKOUT4=>open, CLKOUT5=>open, CLKOUT6=>open,
      LOCKED=>locked_s);
  feedback_buf : BUFG port map(I=>feedback_s, O=>feedback_buf_s);
  clock_buf : BUFG port map(I=>clock_raw_s, O=>clock_s);
  reset_s<=reset_i or not locked_s;
  process(clock_i, reset_s)
  begin
    if reset_s='1' then adc_reset_s<=(others=>'1');
    elsif rising_edge(clock_i) then adc_reset_s<=adc_reset_s(6 downto 0)&'0'; end if;
  end process;
  process(clock_s, reset_s)
  begin
    if reset_s='1' then fast_reset_s<=(others=>'1');
    elsif rising_edge(clock_s) then fast_reset_s<=fast_reset_s(6 downto 0)&'0'; end if;
  end process;
  builder_clock_o<=clock_s; builder_reset_o<=fast_reset_s(7); acquisition_reset_o<=adc_reset_s(7);
end architecture;
