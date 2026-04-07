library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

use work.daphne_subsystem_pkg.all;

entity legacy_spy_trigger_bridge_smoke_tb is
end entity legacy_spy_trigger_bridge_smoke_tb;

architecture tb of legacy_spy_trigger_bridge_smoke_tb is
  signal clock_s            : std_logic := '0';
  signal reset_s            : std_logic := '1';
  signal readiness_s        : acquisition_readiness_t := ACQUISITION_READINESS_NULL;
  signal frontend_trigger_s : std_logic := '0';
  signal adhoc_s            : std_logic_vector(7 downto 0) := x"5A";
  signal ti_trigger_s       : std_logic_vector(7 downto 0) := (others => '0');
  signal ti_trigger_stbr_s  : std_logic := '0';
  signal timing_trigger_s   : std_logic;
  signal spy_enable_s       : std_logic;
  signal spy_trigger_s      : std_logic;
begin
  clock_s <= not clock_s after 5 ns;

  dut : entity work.legacy_spy_trigger_bridge
    port map (
      clock_i            => clock_s,
      reset_i            => reset_s,
      readiness_i        => readiness_s,
      frontend_trigger_i => frontend_trigger_s,
      adhoc_i            => adhoc_s,
      ti_trigger_i       => ti_trigger_s,
      ti_trigger_stbr_i  => ti_trigger_stbr_s,
      timing_trigger_o   => timing_trigger_s,
      spy_enable_o       => spy_enable_s,
      spy_trigger_o      => spy_trigger_s
    );

  stimulus : process
  begin
    readiness_s.config_ready    <= '1';
    readiness_s.timing_ready    <= '1';
    readiness_s.alignment_ready <= '1';

    wait for 12 ns;
    reset_s <= '0';

    wait until rising_edge(clock_s);
    ti_trigger_s <= adhoc_s;
    ti_trigger_stbr_s <= '1';

    wait until rising_edge(clock_s);
    ti_trigger_stbr_s <= '0';
    wait for 1 ns;
    assert timing_trigger_s = '1'
      report "timing trigger should assert on the first stretched cycle"
      severity failure;
    assert spy_enable_s = '1'
      report "spy enable should follow readiness"
      severity failure;
    assert spy_trigger_s = '1'
      report "spy trigger should include the stretched timing pulse"
      severity failure;

    wait until rising_edge(clock_s);
    wait for 1 ns;
    assert timing_trigger_s = '1'
      report "timing trigger should remain asserted on the second stretched cycle"
      severity failure;

    wait until rising_edge(clock_s);
    wait for 1 ns;
    assert timing_trigger_s = '1'
      report "timing trigger should remain asserted on the third stretched cycle"
      severity failure;

    wait until rising_edge(clock_s);
    wait for 1 ns;
    assert timing_trigger_s = '0'
      report "timing trigger should deassert after the stretch window"
      severity failure;

    frontend_trigger_s <= '1';
    wait for 1 ns;
    assert spy_trigger_s = '1'
      report "frontend trigger should also drive spy trigger"
      severity failure;

    stop;
    wait;
  end process;
end architecture tb;
