library ieee;
use ieee.std_logic_1164.all;

use std.env.all;

entity k26c_board_spy_trigger_plane_smoke_tb is
end entity k26c_board_spy_trigger_plane_smoke_tb;

architecture tb of k26c_board_spy_trigger_plane_smoke_tb is
  constant CLOCK_PERIOD_C : time := 16 ns;

  signal clock_s            : std_logic := '0';
  signal reset_s            : std_logic := '1';
  signal software_trigger_s : std_logic := '0';
  signal external_trigger_s : std_logic := '0';
  signal trigger_source_s   : std_logic_vector(1 downto 0) := "11";
  signal trigger_inhibit_s  : std_logic := '0';
  signal adhoc_s            : std_logic_vector(7 downto 0) := x"A5";
  signal ti_trigger_s       : std_logic_vector(7 downto 0) := (others => '0');
  signal ti_trigger_stbr_s  : std_logic := '0';
  signal spy_trigger_s      : std_logic;
begin
  clock_s <= not clock_s after CLOCK_PERIOD_C / 2;

  dut : entity work.k26c_board_spy_trigger_plane
    port map (
      clock_i            => clock_s,
      reset_i            => reset_s,
      software_trigger_i => software_trigger_s,
      external_trigger_i => external_trigger_s,
      trigger_source_i   => trigger_source_s,
      trigger_inhibit_i  => trigger_inhibit_s,
      adhoc_i            => adhoc_s,
      ti_trigger_i       => ti_trigger_s,
      ti_trigger_stbr_i  => ti_trigger_stbr_s,
      spy_trigger_o      => spy_trigger_s
    );

  stimulus : process
  begin
    wait for 3 * CLOCK_PERIOD_C;
    wait until rising_edge(clock_s);
    reset_s <= '0';
    wait until rising_edge(clock_s);
    wait for 1 ns;

    trigger_source_s <= "00";
    software_trigger_s <= '1';
    wait for 1 ns;
    assert spy_trigger_s = '1'
      report "Software mode did not pass the software trigger"
      severity failure;

    software_trigger_s <= '0';
    external_trigger_s <= '1';
    wait for 1 ns;
    assert spy_trigger_s = '0'
      report "Software mode did not reject the external trigger"
      severity failure;

    trigger_source_s <= "01";
    wait for 1 ns;
    assert spy_trigger_s = '1'
      report "External mode did not pass the external trigger"
      severity failure;

    external_trigger_s <= '0';
    software_trigger_s <= '1';
    wait for 1 ns;
    assert spy_trigger_s = '0'
      report "External mode did not reject the software trigger"
      severity failure;

    software_trigger_s <= '0';
    trigger_source_s <= "10";
    ti_trigger_s <= adhoc_s;
    ti_trigger_stbr_s <= '1';
    wait until rising_edge(clock_s);
    wait for 1 ns;
    ti_trigger_stbr_s <= '0';
    assert spy_trigger_s = '1'
      report "Timing mode did not pass a matching timing/ad-hoc trigger"
      severity failure;

    for i in 0 to 1 loop
      wait until rising_edge(clock_s);
      wait for 1 ns;
      assert spy_trigger_s = '1'
        report "Timing trigger was not stretched for three acquisition clocks"
        severity failure;
    end loop;
    wait until rising_edge(clock_s);
    wait for 1 ns;
    assert spy_trigger_s = '0'
      report "Timing trigger did not self-clear"
      severity failure;

    ti_trigger_s <= not adhoc_s;
    ti_trigger_stbr_s <= '1';
    wait until rising_edge(clock_s);
    wait for 1 ns;
    ti_trigger_stbr_s <= '0';
    assert spy_trigger_s = '0'
      report "Timing mode accepted a non-matching timing code"
      severity failure;

    trigger_source_s <= "11";
    software_trigger_s <= '1';
    wait for 1 ns;
    assert spy_trigger_s = '1'
      report "Legacy OR mode did not pass the software trigger"
      severity failure;

    software_trigger_s <= '0';
    external_trigger_s <= '1';
    wait for 1 ns;
    assert spy_trigger_s = '1'
      report "Legacy OR mode did not pass the external trigger"
      severity failure;

    trigger_inhibit_s <= '1';
    wait for 1 ns;
    assert spy_trigger_s = '0'
      report "Trigger inhibit did not block an asserted source"
      severity failure;

    software_trigger_s <= '1';
    ti_trigger_s <= adhoc_s;
    ti_trigger_stbr_s <= '1';
    wait until rising_edge(clock_s);
    wait for 1 ns;
    assert spy_trigger_s = '0'
      report "Trigger inhibit did not block simultaneous trigger sources"
      severity failure;

    trigger_inhibit_s <= '0';
    wait for 1 ns;
    assert spy_trigger_s = '1'
      report "Clearing trigger inhibit did not restore the selected sources"
      severity failure;

    assert false
      report "k26c_board_spy_trigger_plane_smoke_tb completed successfully"
      severity note;
    stop;
    wait;
  end process stimulus;
end architecture tb;
