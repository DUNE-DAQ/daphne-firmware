library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity peak_descriptor_compact_smoke_tb is
end entity peak_descriptor_compact_smoke_tb;

architecture tb of peak_descriptor_compact_smoke_tb is
  constant CLK_PERIOD_C : time := 10 ns;

  signal clock_s   : std_logic := '0';
  signal reset_s   : std_logic := '1';
  signal trigger_s : trigger_xcorr_result_t := TRIGGER_XCORR_RESULT_NULL;
  signal control_s : peak_descriptor_control_t := PEAK_DESCRIPTOR_CONTROL_NULL;
  signal result_s  : peak_descriptor_result_t;
  signal trailer_s : peak_descriptor_trailer_t;
begin
  clock_s <= not clock_s after CLK_PERIOD_C / 2;

  dut : entity work.peak_descriptor_compact
    generic map (
      FRAME_SAMPLE_COUNT_G => 512,
      PRETRIGGER_SAMPLES_G => 64
    )
    port map (
      clock_i   => clock_s,
      reset_i   => reset_s,
      trigger_i => trigger_s,
      control_i => control_s,
      result_o  => result_s,
      trailer_o => trailer_s
    );

  stimulus : process
    variable saw_trailer_v : boolean := false;
  begin
    wait for 3 * CLK_PERIOD_C;
    reset_s <= '0';
    wait until rising_edge(clock_s);
    wait for 1 ns;

    control_s.config(13 downto 7) <= std_logic_vector(to_signed(-2, 7));
    control_s.config(6)           <= '0';
    control_s.frame_match         <= '1';
    trigger_s.enabled             <= '1';
    trigger_s.trigger_pulse       <= '1';
    trigger_s.descriptor_sample   <= std_logic_vector(to_signed(-10, 14));

    wait until rising_edge(clock_s);
    wait for 1 ns;
    trigger_s.trigger_pulse <= '0';

    for idx in 0 to 35 loop
      trigger_s.descriptor_sample <= std_logic_vector(to_signed(-10, 14));
      wait until rising_edge(clock_s);
      wait for 1 ns;
      if result_s.trailer_available = '1' then
        saw_trailer_v := true;
      end if;
    end loop;

    for idx in 0 to 20 loop
      trigger_s.descriptor_sample <= std_logic_vector(to_signed(2, 14));
      wait until rising_edge(clock_s);
      wait for 1 ns;
      if result_s.trailer_available = '1' then
        saw_trailer_v := true;

        assert result_s.data_available = '1'
          report "Trailer pulse did not coincide with descriptor data availability"
          severity failure;
        assert trailer_s(0)(31) = '1'
          report "Descriptor trailer word 0 did not carry the descriptor-valid bit"
          severity failure;
        assert trailer_s(10)(31 downto 22) = std_logic_vector(to_unsigned(64, 10))
          report "Descriptor trailer word 10 did not preserve the pretrigger start time"
          severity failure;
        assert unsigned(result_s.adc_peak) = to_unsigned(10, result_s.adc_peak'length)
          report "Descriptor peak amplitude did not track the injected negative pulse"
          severity failure;
        assert unsigned(result_s.adc_integral) >= to_unsigned(300, result_s.adc_integral'length)
          report "Descriptor integral is too small for the injected pulse"
          severity failure;
      end if;
    end loop;

    assert saw_trailer_v
      report "Compact peak descriptor did not emit a trailer"
      severity failure;

    assert false
      report "peak_descriptor_compact_smoke_tb completed successfully"
      severity note;
    wait;
  end process stimulus;
end architecture tb;
