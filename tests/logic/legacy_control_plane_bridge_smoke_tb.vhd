library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity legacy_control_plane_bridge_smoke_tb is
end entity legacy_control_plane_bridge_smoke_tb;

architecture tb of legacy_control_plane_bridge_smoke_tb is
  constant CHANNEL_COUNT_C : positive := 4;

  signal analog_stat_s            : analog_status_t := ANALOG_STATUS_NULL;
  signal timing_stat_s            : timing_status_t := TIMING_STATUS_NULL;
  signal frontend_align_stat_s    : frontend_alignment_status_t := FRONTEND_ALIGNMENT_STATUS_NULL;
  signal core_chan_enable_s       : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := "1010";
  signal afe_comp_enable_s        : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := "0110";
  signal invert_enable_s          : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := "1100";
  signal threshold_xc_s           : slv28_array_t(0 to CHANNEL_COUNT_C - 1);
  signal adhoc_s                  : std_logic_vector(7 downto 0) := x"96";
  signal filter_output_selector_s : std_logic_vector(1 downto 0) := "11";
  signal ti_trigger_s             : std_logic_vector(7 downto 0) := x"5A";
  signal ti_trigger_stbr_s        : std_logic := '1';
  signal descriptor_config_s      : std_logic_vector(13 downto 0) := "00110100101101";
  signal signal_delay_s           : std_logic_vector(4 downto 0) := "01011";
  signal reset_st_counters_s      : std_logic := '1';
  signal frontend_prereq_s        : frontend_prereq_t;
  signal acquisition_ready_s      : acquisition_readiness_t;
  signal trigger_control_s        : trigger_xcorr_control_array_t(0 to CHANNEL_COUNT_C - 1);
  signal descriptor_config_out_s  : std_logic_vector(13 downto 0);
  signal signal_delay_out_s       : std_logic_vector(4 downto 0);
  signal reset_st_counters_out_s  : std_logic;
begin
  dut : entity work.legacy_control_plane_bridge
    generic map (
      CHANNEL_COUNT_G => CHANNEL_COUNT_C
    )
    port map (
      analog_stat_i            => analog_stat_s,
      timing_stat_i            => timing_stat_s,
      frontend_align_stat_i    => frontend_align_stat_s,
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
      frontend_prereq_o        => frontend_prereq_s,
      acquisition_ready_o      => acquisition_ready_s,
      trigger_control_o        => trigger_control_s,
      descriptor_config_o      => descriptor_config_out_s,
      signal_delay_o           => signal_delay_out_s,
      reset_st_counters_o      => reset_st_counters_out_s
    );

  stimulus : process
  begin
    analog_stat_s.config_ready         <= '1';
    analog_stat_s.afe_ready            <= '1';
    analog_stat_s.dac_ready            <= '1';
    timing_stat_s.mmcm0_locked         <= '1';
    timing_stat_s.mmcm1_locked         <= '1';
    timing_stat_s.endpoint_ready       <= '1';
    timing_stat_s.timestamp_valid      <= '1';
    frontend_align_stat_s.alignment_valid <= '1';
    frontend_align_stat_s.idelayctrl_ready <= '1';
    frontend_align_stat_s.format_ok       <= '1';
    frontend_align_stat_s.training_ok     <= '1';

    for idx in 0 to CHANNEL_COUNT_C - 1 loop
      threshold_xc_s(idx) <= std_logic_vector(to_unsigned(idx + 64, 28));
    end loop;

    wait for 1 ns;

    assert frontend_prereq_s.config_ready = '1'
      report "Frontend prereq config_ready mismatch"
      severity failure;
    assert frontend_prereq_s.timing_ready = '1'
      report "Frontend prereq timing_ready mismatch"
      severity failure;
    assert acquisition_ready_s.config_ready = '1'
      report "Acquisition config_ready mismatch"
      severity failure;
    assert acquisition_ready_s.timing_ready = '1'
      report "Acquisition timing_ready mismatch"
      severity failure;
    assert acquisition_ready_s.alignment_ready = '1'
      report "Acquisition alignment_ready mismatch"
      severity failure;
    assert descriptor_config_out_s = descriptor_config_s
      report "Descriptor config mismatch"
      severity failure;
    assert signal_delay_out_s = signal_delay_s
      report "Signal delay mismatch"
      severity failure;
    assert reset_st_counters_out_s = reset_st_counters_s
      report "Counter reset mismatch"
      severity failure;

    for idx in 0 to CHANNEL_COUNT_C - 1 loop
      assert trigger_control_s(idx).enable = core_chan_enable_s(idx)
        report "Enable mismatch at channel " & integer'image(idx)
        severity failure;
      assert trigger_control_s(idx).threshold_xc = threshold_xc_s(idx)
        report "Threshold mismatch at channel " & integer'image(idx)
        severity failure;
    end loop;

    wait;
  end process;
end architecture tb;
