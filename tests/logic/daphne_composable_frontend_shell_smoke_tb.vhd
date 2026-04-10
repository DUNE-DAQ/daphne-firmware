library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity daphne_composable_frontend_shell_smoke_tb is
end entity daphne_composable_frontend_shell_smoke_tb;

architecture tb of daphne_composable_frontend_shell_smoke_tb is
  constant AFE_COUNT_C      : positive := 1;
  constant CHANNELS_TOTAL_C : natural := AFE_COUNT_C * 8;
  constant CLK_PERIOD_C     : time := 10 ns;

  signal clock_s             : std_logic := '0';
  signal frontend_resetn_s   : std_logic := '0';
  signal timing_resetn_s     : std_logic := '0';

  signal timing_ctrl_s       : timing_control_t := TIMING_CONTROL_NULL;
  signal timing_stat_s       : timing_status_t;
  signal timing_timestamp_s  : std_logic_vector(63 downto 0);
  signal timing_sync_s       : std_logic_vector(7 downto 0);
  signal timing_sync_stb_s   : std_logic;

  signal hermes_descriptor_s : trigger_descriptor_t := TRIGGER_DESCRIPTOR_NULL;
  signal hermes_taken_s      : std_logic;
  signal hermes_status_s     : hermes_boundary_status_t;

  signal config_valid_s      : std_logic_vector(AFE_COUNT_C - 1 downto 0) := (others => '0');
  signal config_cmd_s        : afe_config_command_bank_t(0 to AFE_COUNT_C - 1) := (others => AFE_CONFIG_COMMAND_NULL);
  signal config_status_s     : afe_config_status_bank_t(0 to AFE_COUNT_C - 1);
  signal afe_miso_s          : std_logic_vector(AFE_COUNT_C - 1 downto 0) := (others => '0');
  signal afe_sclk_s          : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal afe_sen_s           : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal afe_mosi_s          : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trim_sclk_s         : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trim_mosi_s         : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trim_ldac_n_s       : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trim_sync_n_s       : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal offset_sclk_s       : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal offset_mosi_s       : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal offset_ldac_n_s     : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal offset_sync_n_s     : std_logic_vector(AFE_COUNT_C - 1 downto 0);

  signal trigger_control_s   : trigger_xcorr_control_array_t(0 to CHANNELS_TOTAL_C - 1) := (others => TRIGGER_XCORR_CONTROL_NULL);
  signal trigger_result_s    : trigger_xcorr_result_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal descriptor_result_s : peak_descriptor_result_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal record_count_s      : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal full_count_s        : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal busy_count_s        : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal trigger_count_s     : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal packet_count_s      : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal delayed_sample_s    : sample14_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal ready_s             : std_logic_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal rd_en_s             : std_logic_array_t(0 to CHANNELS_TOTAL_C - 1) := (others => '0');
  signal dout_s              : slv72_array_t(0 to CHANNELS_TOTAL_C - 1);

  signal frontend_dout_in_s  : array_5x9x16_type := (others => (others => (others => '0')));
  signal frontend_dout_out_s : array_5x9x16_type;
  signal frontend_trig_in_s  : std_logic := '0';
  signal frontend_trig_out_s : std_logic;
begin
  clock_s <= not clock_s after CLK_PERIOD_C / 2;

  dut : entity work.daphne_composable_frontend_shell
    generic map (
      AFE_COUNT_G          => AFE_COUNT_C,
      ENABLE_SELFTRIGGER_G => false,
      ENABLE_TIMING_G      => false,
      ENABLE_HERMES_G      => true
    )
    port map (
      clock_i                   => clock_s,
      frontend_resetn_i         => frontend_resetn_s,
      timing_clk_axi_i          => clock_s,
      timing_resetn_axi_i       => timing_resetn_s,
      timing_ctrl_i             => timing_ctrl_s,
      timing_stat_o             => timing_stat_s,
      timing_timestamp_o        => timing_timestamp_s,
      timing_sync_o             => timing_sync_s,
      timing_sync_stb_o         => timing_sync_stb_s,
      hermes_descriptor_i       => hermes_descriptor_s,
      hermes_descriptor_taken_o => hermes_taken_s,
      hermes_stat_o             => hermes_status_s,
      config_valid_i            => config_valid_s,
      config_cmd_i              => config_cmd_s,
      config_status_o           => config_status_s,
      afe_miso_i                => afe_miso_s,
      afe_sclk_o                => afe_sclk_s,
      afe_sen_o                 => afe_sen_s,
      afe_mosi_o                => afe_mosi_s,
      trim_sclk_o               => trim_sclk_s,
      trim_mosi_o               => trim_mosi_s,
      trim_ldac_n_o             => trim_ldac_n_s,
      trim_sync_n_o             => trim_sync_n_s,
      offset_sclk_o             => offset_sclk_s,
      offset_mosi_o             => offset_mosi_s,
      offset_ldac_n_o           => offset_ldac_n_s,
      offset_sync_n_o           => offset_sync_n_s,
      reset_st_counters_i       => '0',
      force_trigger_i           => '0',
      timestamp_i               => x"0011223344556677",
      version_i                 => x"3",
      signal_delay_i            => "00011",
      descriptor_config_i       => (others => '1'),
      frontend_dout_i           => frontend_dout_in_s,
      frontend_trig_i           => frontend_trig_in_s,
      trigger_control_i         => trigger_control_s,
      rd_en_i                   => rd_en_s,
      frontend_dout_o           => frontend_dout_out_s,
      frontend_trig_o           => frontend_trig_out_s,
      trigger_result_o          => trigger_result_s,
      descriptor_result_o       => descriptor_result_s,
      record_count_o            => record_count_s,
      full_count_o              => full_count_s,
      busy_count_o              => busy_count_s,
      trigger_count_o           => trigger_count_s,
      packet_count_o            => packet_count_s,
      delayed_sample_o          => delayed_sample_s,
      ready_o                   => ready_s,
      dout_o                    => dout_s
    );

  stimulus : process
  begin
    frontend_dout_in_s(0)(0) <= x"1234";
    frontend_dout_in_s(0)(1) <= x"5678";
    frontend_trig_in_s <= '1';
    timing_ctrl_s.use_endpoint_clock <= '1';
    timing_ctrl_s.mmcm0_reset <= '0';
    timing_ctrl_s.mmcm1_reset <= '0';
    timing_ctrl_s.endpoint_reset <= '0';
    timing_ctrl_s.endpoint_addr <= x"00A5";
    hermes_descriptor_s.valid <= '1';
    hermes_descriptor_s.channel_id <= x"22";
    hermes_descriptor_s.version_id <= "0101";
    hermes_descriptor_s.payload <= x"AA55AA55AA55AA55";

    wait for 4 * CLK_PERIOD_C;
    frontend_resetn_s <= '1';
    timing_resetn_s <= '1';
    wait for 6 * CLK_PERIOD_C;

    assert frontend_dout_out_s(0)(0) = x"1234"
      report "Frontend shell should pass the first captured lane through unchanged"
      severity failure;
    assert frontend_dout_out_s(0)(1) = x"5678"
      report "Frontend shell should pass the second captured lane through unchanged"
      severity failure;
    assert frontend_trig_out_s = '1'
      report "Frontend shell should pass the frontend trigger flag through unchanged"
      severity failure;

    assert timing_stat_s.mmcm0_locked = '1'
      report "Frontend shell should expose mmcm0 lock once endpoint timing is selected and released"
      severity failure;
    assert timing_stat_s.mmcm1_locked = '1'
      report "Frontend shell should expose mmcm1 lock once endpoint timing is selected and released"
      severity failure;
    assert timing_stat_s.endpoint_ready = '1'
      report "Frontend shell should expose endpoint readiness once endpoint timing is released and locked"
      severity failure;
    assert timing_stat_s.endpoint_state = x"F"
      report "Frontend shell should expose the ready endpoint state once endpoint timing is fully released"
      severity failure;
    assert timing_stat_s.timestamp_valid = '1'
      report "Frontend shell should expose timestamp validity once endpoint timing is ready"
      severity failure;
    assert timing_timestamp_s = x"00A500A500A500A5"
      report "Frontend shell should expose the ready-gated endpoint timestamp image"
      severity failure;
    assert timing_sync_s = x"A5"
      report "Frontend shell should expose the ready-gated endpoint sync byte"
      severity failure;
    assert timing_sync_stb_s = '1'
      report "Frontend shell should expose the modeled endpoint sync strobe when the selected address enables it"
      severity failure;
    assert hermes_taken_s = '0'
      report "Enabled Hermes shell path should stall descriptor handoff when the modeled backpressure bit is set"
      severity failure;
    assert hermes_status_s.link_up = '1'
      report "Enabled Hermes shell path should report link-up once reset is released"
      severity failure;
    assert hermes_status_s.ready = '0'
      report "Enabled Hermes shell path should drop ready when the modeled backpressure bit is set"
      severity failure;
    assert hermes_status_s.backpressure = '1'
      report "Enabled Hermes shell path should report backpressure when the modeled stall bit is set"
      severity failure;
    assert hermes_status_s.transport_busy = '1'
      report "Enabled Hermes shell path should report a live transport transaction while the descriptor is stalled"
      severity failure;

    assert trigger_result_s(0) = TRIGGER_XCORR_RESULT_NULL
      report "Disabled self-trigger path should keep the first trigger result null"
      severity failure;
    assert descriptor_result_s(CHANNELS_TOTAL_C - 1) = PEAK_DESCRIPTOR_RESULT_NULL
      report "Disabled self-trigger path should keep the last descriptor result null"
      severity failure;
    assert dout_s(CHANNELS_TOTAL_C - 1) = (dout_s(CHANNELS_TOTAL_C - 1)'range => '0')
      report "Disabled self-trigger path should keep emitted records zeroed"
      severity failure;

    assert false report "daphne_composable_frontend_shell_smoke_tb completed successfully" severity note;
    wait;
  end process;
end architecture tb;
