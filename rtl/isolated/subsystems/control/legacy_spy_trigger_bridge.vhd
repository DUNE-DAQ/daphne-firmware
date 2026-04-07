library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity legacy_spy_trigger_bridge is
  port (
    clock_i             : in  std_logic;
    reset_i             : in  std_logic;
    readiness_i         : in  acquisition_readiness_t;
    frontend_trigger_i  : in  std_logic;
    adhoc_i             : in  std_logic_vector(7 downto 0);
    ti_trigger_i        : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr_i   : in  std_logic;
    timing_trigger_o    : out std_logic;
    spy_enable_o        : out std_logic;
    spy_trigger_o       : out std_logic
  );
end entity legacy_spy_trigger_bridge;

architecture rtl of legacy_spy_trigger_bridge is
  signal ti_trigger_en_s   : std_logic;
  signal ti_trigger_en0_s  : std_logic := '0';
  signal ti_trigger_en1_s  : std_logic := '0';
  signal ti_trigger_en2_s  : std_logic := '0';
  signal timing_trigger_s  : std_logic;
begin
  ti_trigger_en_s <= '1' when (ti_trigger_i = adhoc_i and ti_trigger_stbr_i = '1') else '0';

  process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        ti_trigger_en0_s <= '0';
        ti_trigger_en1_s <= '0';
        ti_trigger_en2_s <= '0';
      else
        ti_trigger_en0_s <= ti_trigger_en_s;
        ti_trigger_en1_s <= ti_trigger_en0_s;
        ti_trigger_en2_s <= ti_trigger_en1_s;
      end if;
    end if;
  end process;

  timing_trigger_s <= ti_trigger_en0_s or ti_trigger_en1_s or ti_trigger_en2_s;
  timing_trigger_o <= timing_trigger_s;
  spy_trigger_o    <= frontend_trigger_i or timing_trigger_s;

  spy_boundary_inst : entity work.spy_buffer_boundary
    port map (
      clk          => clock_i,
      reset        => reset_i,
      readiness_i  => readiness_i,
      spy_enable_o => spy_enable_o
    );
end architecture rtl;
