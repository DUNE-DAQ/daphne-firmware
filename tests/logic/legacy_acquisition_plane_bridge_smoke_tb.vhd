library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_acquisition_plane_bridge_smoke_tb is
end entity legacy_acquisition_plane_bridge_smoke_tb;

architecture tb of legacy_acquisition_plane_bridge_smoke_tb is
  constant AFE_COUNT_C     : positive := 1;
  constant CHANNEL_COUNT_C : positive := AFE_COUNT_C * 8;

  signal clock_s                : std_logic := '0';
  signal reset_s                : std_logic := '0';
  signal analog_stat_s          : analog_status_t := ANALOG_STATUS_NULL;
  signal timing_stat_s          : timing_status_t := TIMING_STATUS_NULL;
  signal frontend_align_stat_s  : frontend_alignment_status_t := FRONTEND_ALIGNMENT_STATUS_NULL;
  signal frontend_dout_s        : array_5x9x16_type := (others => (others => (others => '0')));
  signal frontend_trigger_s     : std_logic := '0';
  signal core_chan_enable_s     : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := (others => '0');
  signal afe_comp_enable_s      : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := (others => '0');
  signal invert_enable_s        : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := (others => '0');
  signal threshold_xc_s         : slv28_array_t(0 to CHANNEL_COUNT_C - 1);
  signal adhoc_s                : std_logic_vector(7 downto 0) := x"00";
  signal filter_output_selector_s : std_logic_vector(1 downto 0) := "00";
  signal ti_trigger_s           : std_logic_vector(7 downto 0) := x"00";
  signal ti_trigger_stbr_s      : std_logic := '0';
  signal descriptor_config_s    : std_logic_vector(13 downto 0) := (others => '0');
  signal signal_delay_s         : std_logic_vector(4 downto 0) := (others => '0');
  signal reset_st_counters_s    : std_logic := '0';
  signal force_trigger_s        : std_logic := '0';
  signal timestamp_s            : std_logic_vector(63 downto 0) := (others => '0');
  signal version_s              : std_logic_vector(3 downto 0) := (others => '0');
  signal rd_en_s                : std_logic_array_t(0 to CHANNEL_COUNT_C - 1) := (others => '0');
  signal frontend_prereq_s      : frontend_prereq_t;
  signal acquisition_ready_s    : acquisition_readiness_t;
  signal timing_trigger_s       : std_logic;
  signal spy_enable_s           : std_logic;
  signal spy_trigger_s          : std_logic;
  signal trigger_result_s       : trigger_xcorr_result_array_t(0 to CHANNEL_COUNT_C - 1);
  signal descriptor_result_s    : peak_descriptor_result_array_t(0 to CHANNEL_COUNT_C - 1);
  signal record_count_s         : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal full_count_s           : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal busy_count_s           : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal trigger_count_s        : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal packet_count_s         : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal delayed_sample_s       : sample14_array_t(0 to CHANNEL_COUNT_C - 1);
  signal ready_s                : std_logic_array_t(0 to CHANNEL_COUNT_C - 1);
  signal dout_s                 : slv72_array_t(0 to CHANNEL_COUNT_C - 1);
begin
  clock_s <= not clock_s after 5 ns;

  dut : entity work.legacy_acquisition_plane_bridge
    generic map (
      AFE_COUNT_G => AFE_COUNT_C
    )
    port map (
      clock_i                  => clock_s,
      reset_i                  => reset_s,
      analog_stat_i            => analog_stat_s,
      timing_stat_i            => timing_stat_s,
      frontend_align_stat_i    => frontend_align_stat_s,
      frontend_dout_i          => frontend_dout_s,
      frontend_trigger_i       => frontend_trigger_s,
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
      force_trigger_i          => force_trigger_s,
      timestamp_i              => timestamp_s,
      version_i                => version_s,
      rd_en_i                  => rd_en_s,
      frontend_prereq_o        => frontend_prereq_s,
      acquisition_ready_o      => acquisition_ready_s,
      timing_trigger_o         => timing_trigger_s,
      spy_enable_o             => spy_enable_s,
      spy_trigger_o            => spy_trigger_s,
      trigger_result_o         => trigger_result_s,
      descriptor_result_o      => descriptor_result_s,
      record_count_o           => record_count_s,
      full_count_o             => full_count_s,
      busy_count_o             => busy_count_s,
      trigger_count_o          => trigger_count_s,
      packet_count_o           => packet_count_s,
      delayed_sample_o         => delayed_sample_s,
      ready_o                  => ready_s,
      dout_o                   => dout_s
    );

  stimulus : process
  begin
    for idx in 0 to CHANNEL_COUNT_C - 1 loop
      threshold_xc_s(idx) <= std_logic_vector(to_unsigned(idx + 1, 28));
    end loop;

    analog_stat_s.config_ready            <= '1';
    analog_stat_s.afe_ready               <= '1';
    analog_stat_s.dac_ready               <= '1';
    timing_stat_s.mmcm0_locked            <= '1';
    timing_stat_s.mmcm1_locked            <= '1';
    timing_stat_s.endpoint_ready          <= '1';
    timing_stat_s.timestamp_valid         <= '1';
    frontend_align_stat_s.idelayctrl_ready <= '1';
    frontend_align_stat_s.format_ok        <= '1';
    frontend_align_stat_s.training_ok      <= '1';
    frontend_align_stat_s.alignment_valid  <= '1';

    wait until rising_edge(clock_s);
    ti_trigger_s <= adhoc_s;
    ti_trigger_stbr_s <= '1';

    wait until rising_edge(clock_s);
    ti_trigger_stbr_s <= '0';
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
    assert spy_enable_s = '1'
      report "Spy enable should assert when readiness is complete"
      severity failure;
    assert timing_trigger_s = '1'
      report "Timing trigger should follow the stretched adhoc match"
      severity failure;
    assert spy_trigger_s = '1'
      report "Spy trigger should include the stretched timing pulse"
      severity failure;

    frontend_trigger_s <= '1';
    wait for 1 ns;
    assert spy_trigger_s = '1'
      report "Frontend trigger should also drive the spy trigger"
      severity failure;

    stop;
    wait;
  end process;
end architecture tb;
