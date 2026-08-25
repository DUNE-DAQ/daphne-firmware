library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

use work.daphne_subsystem_pkg.all;

entity stc3_record_builder_smoke_tb is
end entity stc3_record_builder_smoke_tb;

architecture tb of stc3_record_builder_smoke_tb is
  constant CLOCK_PERIOD_C : time := 10 ns;

  signal clock_s             : std_logic := '0';
  signal reset_s             : std_logic := '1';
  signal reset_counters_s    : std_logic := '0';
  signal enable_s            : std_logic := '1';
  signal force_trigger_s     : std_logic := '0';
  signal trigger_s           : trigger_xcorr_result_t := TRIGGER_XCORR_RESULT_NULL;
  signal frame_match_s       : std_logic;
  signal record_count_s      : std_logic_vector(63 downto 0);
  signal full_count_s        : std_logic_vector(63 downto 0);
  signal busy_count_s        : std_logic_vector(63 downto 0);
  signal trigger_count_s     : std_logic_vector(63 downto 0);
  signal packet_count_s      : std_logic_vector(63 downto 0);
  signal delayed_sample_s    : std_logic_vector(13 downto 0);
  signal ready_s             : std_logic;
  signal dout_s              : std_logic_vector(71 downto 0);

  procedure wait_cycles(signal clock : in std_logic; constant count : positive) is
  begin
    for idx in 1 to count loop
      wait until rising_edge(clock);
      wait for 1 ns;
    end loop;
  end procedure wait_cycles;
begin
  clock_s <= not clock_s after CLOCK_PERIOD_C / 2;

  dut : entity work.stc3_record_builder
    port map (
      ch_id_i             => X"03",
      version_i           => X"A",
      threshold_xc_i      => X"0000123",
      signal_delay_i      => "10000",
      clock_i             => clock_s,
      reset_i             => reset_s,
      reset_st_counters_i => reset_counters_s,
      enable_i            => enable_s,
      force_trigger_i     => force_trigger_s,
      din_i               => (others => '0'),
      trigger_i           => trigger_s,
      trailer_capture_i   => '0',
      trailer_i           => PEAK_DESCRIPTOR_TRAILER_NULL,
      frame_match_o       => frame_match_s,
      record_count_o      => record_count_s,
      full_count_o        => full_count_s,
      busy_count_o        => busy_count_s,
      trigger_count_o     => trigger_count_s,
      packet_count_o      => packet_count_s,
      delayed_sample_o    => delayed_sample_s,
      ready_o             => ready_s,
      rd_en_i             => '0',
      dout_o              => dout_s
    );

  stimulus : process
  begin
    wait_cycles(clock_s, 3);
    reset_s <= '0';
    wait_cycles(clock_s, 2);

    -- Accept one trigger, then issue another while the record builder is busy.
    trigger_s.trigger_pulse <= '1';
    wait_cycles(clock_s, 1);
    trigger_s.trigger_pulse <= '0';
    wait_cycles(clock_s, 1);
    trigger_s.trigger_pulse <= '1';
    wait_cycles(clock_s, 1);
    trigger_s.trigger_pulse <= '0';
    wait_cycles(clock_s, 8);

    assert unsigned(record_count_s) = 1
      report "accepted trigger did not increment the record counter"
      severity failure;
    assert unsigned(packet_count_s) = 1
      report "accepted trigger did not increment the packet counter"
      severity failure;
    assert unsigned(trigger_count_s) = 2
      report "trigger counter did not observe both trigger pulses"
      severity failure;
    assert unsigned(busy_count_s) = 1
      report "busy counter did not observe the trigger issued while busy"
      severity failure;

    reset_counters_s <= '1';
    wait_cycles(clock_s, 1);

    assert record_count_s = X"0000000000000000"
      report "counter reset did not clear the record counter"
      severity failure;
    assert packet_count_s = X"0000000000000000"
      report "counter reset did not clear the packet counter"
      severity failure;
    assert trigger_count_s = X"0000000000000000"
      report "counter reset did not clear the trigger counter"
      severity failure;
    assert busy_count_s = X"0000000000000000"
      report "counter reset did not clear the busy counter"
      severity failure;
    assert full_count_s = X"0000000000000000"
      report "counter reset did not clear the full counter"
      severity failure;

    reset_counters_s <= '0';
    wait_cycles(clock_s, 1);

    report "stc3_record_builder_smoke_tb PASS" severity note;
    stop;
    wait;
  end process stimulus;
end architecture tb;
