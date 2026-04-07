library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity legacy_trigger_control_adapter_smoke_tb is
end entity legacy_trigger_control_adapter_smoke_tb;

architecture tb of legacy_trigger_control_adapter_smoke_tb is
  constant CHANNEL_COUNT_C : positive := 4;

  signal core_chan_enable_s       : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := "1010";
  signal afe_comp_enable_s        : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := "0110";
  signal invert_enable_s          : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := "1100";
  signal threshold_xc_s           : slv28_array_t(0 to CHANNEL_COUNT_C - 1);
  signal adhoc_s                  : std_logic_vector(7 downto 0) := x"5A";
  signal filter_output_selector_s : std_logic_vector(1 downto 0) := "10";
  signal ti_trigger_s             : std_logic_vector(7 downto 0) := x"C3";
  signal ti_trigger_stbr_s        : std_logic := '1';
  signal descriptor_config_s      : std_logic_vector(13 downto 0) := "10100101100101";
  signal signal_delay_s           : std_logic_vector(4 downto 0) := "10110";
  signal reset_st_counters_s      : std_logic := '1';
  signal trigger_control_s        : trigger_xcorr_control_array_t(0 to CHANNEL_COUNT_C - 1);
  signal descriptor_config_out_s  : std_logic_vector(13 downto 0);
  signal signal_delay_out_s       : std_logic_vector(4 downto 0);
  signal reset_st_counters_out_s  : std_logic;
begin
  dut : entity work.legacy_trigger_control_adapter
    generic map (
      CHANNEL_COUNT_G => CHANNEL_COUNT_C
    )
    port map (
      core_chan_enable_i       => core_chan_enable_s,
      afe_comp_enable_i        => afe_comp_enable_s,
      invert_enable_i          => invert_enable_s,
      threshold_xc_i           => threshold_xc_s,
      adhoc_i                  => adhoc_s,
      filter_output_selector_i => filter_output_selector_s,
      ti_trigger_i             => ti_trigger_s,
      ti_trigger_stbr_i        => ti_trigger_stbr_s,
      descriptor_config_i      => descriptor_config_s,
      signal_delay_i           => signal_delay_s,
      reset_st_counters_i      => reset_st_counters_s,
      trigger_control_o        => trigger_control_s,
      descriptor_config_o      => descriptor_config_out_s,
      signal_delay_o           => signal_delay_out_s,
      reset_st_counters_o      => reset_st_counters_out_s
    );

  stimulus : process
  begin
    for idx in 0 to CHANNEL_COUNT_C - 1 loop
      threshold_xc_s(idx) <= std_logic_vector(to_unsigned(idx + 16, 28));
    end loop;

    wait for 1 ns;

    assert descriptor_config_out_s = descriptor_config_s
      report "Descriptor config was not forwarded"
      severity failure;
    assert signal_delay_out_s = signal_delay_s
      report "Signal delay was not forwarded"
      severity failure;
    assert reset_st_counters_out_s = reset_st_counters_s
      report "Counter reset was not forwarded"
      severity failure;

    for idx in 0 to CHANNEL_COUNT_C - 1 loop
      assert trigger_control_s(idx).enable = core_chan_enable_s(idx)
        report "Enable bit mismatch at channel " & integer'image(idx)
        severity failure;
      assert trigger_control_s(idx).afe_comp_enable = afe_comp_enable_s(idx)
        report "AFE compensation bit mismatch at channel " & integer'image(idx)
        severity failure;
      assert trigger_control_s(idx).invert_enable = invert_enable_s(idx)
        report "Invert bit mismatch at channel " & integer'image(idx)
        severity failure;
      assert trigger_control_s(idx).filter_output_selector = filter_output_selector_s
        report "Filter selector mismatch at channel " & integer'image(idx)
        severity failure;
      assert trigger_control_s(idx).threshold_xc = threshold_xc_s(idx)
        report "Threshold mismatch at channel " & integer'image(idx)
        severity failure;
      assert trigger_control_s(idx).adhoc = adhoc_s
        report "Adhoc trigger mismatch at channel " & integer'image(idx)
        severity failure;
      assert trigger_control_s(idx).ti_trigger = ti_trigger_s
        report "Timing trigger bus mismatch at channel " & integer'image(idx)
        severity failure;
      assert trigger_control_s(idx).ti_trigger_stbr = ti_trigger_stbr_s
        report "Timing trigger strobe mismatch at channel " & integer'image(idx)
        severity failure;
    end loop;

    wait;
  end process;
end architecture tb;
