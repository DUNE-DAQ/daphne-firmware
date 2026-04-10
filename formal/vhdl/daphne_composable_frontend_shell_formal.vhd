library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity daphne_composable_frontend_shell_formal is
  port (
    clock_i             : in std_logic;
    frontend_resetn_i   : in std_logic;
    timing_clk_axi_i    : in std_logic;
    timing_resetn_axi_i : in std_logic;
    timing_ctrl_i       : in timing_control_t;
    hermes_descriptor_i : in trigger_descriptor_t;
    timestamp_i         : in std_logic_vector(63 downto 0);
    frontend_dout_i     : in array_5x9x16_type;
    frontend_trig_i     : in std_logic
  );
end entity daphne_composable_frontend_shell_formal;

architecture formal of daphne_composable_frontend_shell_formal is
  constant CONFIG_VALID_C   : std_logic_vector(4 downto 0) := (others => '0');
  constant AFE_MISO_C       : std_logic_vector(4 downto 0) := (others => '0');
  constant VERSION_C        : std_logic_vector(3 downto 0) := (others => '0');
  constant SIGNAL_DELAY_C   : std_logic_vector(4 downto 0) := (others => '0');
  constant DESCRIPTOR_CFG_C : std_logic_vector(13 downto 0) := (others => '0');
  constant CONFIG_CMD_C     : afe_config_command_bank_t(0 to 4) :=
    (others => AFE_CONFIG_COMMAND_NULL);
  constant TRIGGER_CTRL_C   : trigger_xcorr_control_array_t(0 to 39) :=
    (others => TRIGGER_XCORR_CONTROL_NULL);
  constant RD_EN_C          : std_logic_array_t(0 to 39) := (others => '0');

  signal timing_stat_o             : timing_status_t;
  signal timing_timestamp_o        : std_logic_vector(63 downto 0);
  signal timing_sync_o             : std_logic_vector(7 downto 0);
  signal timing_sync_stb_o         : std_logic;
  signal timing_stat_ref_o         : timing_status_t;
  signal timing_timestamp_ref_o    : std_logic_vector(63 downto 0);
  signal timing_sync_ref_o         : std_logic_vector(7 downto 0);
  signal timing_sync_stb_ref_o     : std_logic;
  signal hermes_descriptor_taken_o : std_logic;
  signal hermes_stat_o             : hermes_boundary_status_t;
  signal config_status_o           : afe_config_status_bank_t(0 to 4);
  signal afe_sclk_o                : std_logic_vector(4 downto 0);
  signal afe_sen_o                 : std_logic_vector(4 downto 0);
  signal afe_mosi_o                : std_logic_vector(4 downto 0);
  signal trim_sclk_o               : std_logic_vector(4 downto 0);
  signal trim_mosi_o               : std_logic_vector(4 downto 0);
  signal trim_ldac_n_o             : std_logic_vector(4 downto 0);
  signal trim_sync_n_o             : std_logic_vector(4 downto 0);
  signal offset_sclk_o             : std_logic_vector(4 downto 0);
  signal offset_mosi_o             : std_logic_vector(4 downto 0);
  signal offset_ldac_n_o           : std_logic_vector(4 downto 0);
  signal offset_sync_n_o           : std_logic_vector(4 downto 0);
  signal frontend_dout_o           : array_5x9x16_type;
  signal frontend_trig_o           : std_logic;
  signal trigger_result_o          : trigger_xcorr_result_array_t(0 to 39);
  signal descriptor_result_o       : peak_descriptor_result_array_t(0 to 39);
  signal record_count_o            : slv64_array_t(0 to 39);
  signal full_count_o              : slv64_array_t(0 to 39);
  signal busy_count_o              : slv64_array_t(0 to 39);
  signal trigger_count_o           : slv64_array_t(0 to 39);
  signal packet_count_o            : slv64_array_t(0 to 39);
  signal delayed_sample_o          : sample14_array_t(0 to 39);
  signal ready_o                   : std_logic_array_t(0 to 39);
  signal dout_o                    : slv72_array_t(0 to 39);
  signal trigger_samples_probe     : sample14_array_t(0 to 39);
begin
  probe_adapter : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => 5
    )
    port map (
      afe_dout_i        => frontend_dout_i,
      trigger_samples_o => trigger_samples_probe
    );

  dut : entity work.daphne_composable_frontend_shell
    generic map (
      AFE_COUNT_G          => 5,
      ENABLE_SELFTRIGGER_G => false,
      ENABLE_TIMING_G      => false,
      ENABLE_HERMES_G      => false,
      ENABLE_SPYBUFFER_G   => false
    )
    port map (
      clock_i                   => clock_i,
      frontend_resetn_i         => frontend_resetn_i,
      timing_clk_axi_i          => timing_clk_axi_i,
      timing_resetn_axi_i       => timing_resetn_axi_i,
      timing_ctrl_i             => timing_ctrl_i,
      timing_stat_o             => timing_stat_o,
      timing_timestamp_o        => timing_timestamp_o,
      timing_sync_o             => timing_sync_o,
      timing_sync_stb_o         => timing_sync_stb_o,
      hermes_descriptor_i       => hermes_descriptor_i,
      hermes_descriptor_taken_o => hermes_descriptor_taken_o,
      hermes_stat_o             => hermes_stat_o,
      config_valid_i            => CONFIG_VALID_C,
      config_cmd_i              => CONFIG_CMD_C,
      config_status_o           => config_status_o,
      afe_miso_i                => AFE_MISO_C,
      afe_sclk_o                => afe_sclk_o,
      afe_sen_o                 => afe_sen_o,
      afe_mosi_o                => afe_mosi_o,
      trim_sclk_o               => trim_sclk_o,
      trim_mosi_o               => trim_mosi_o,
      trim_ldac_n_o             => trim_ldac_n_o,
      trim_sync_n_o             => trim_sync_n_o,
      offset_sclk_o             => offset_sclk_o,
      offset_mosi_o             => offset_mosi_o,
      offset_ldac_n_o           => offset_ldac_n_o,
      offset_sync_n_o           => offset_sync_n_o,
      reset_st_counters_i       => '0',
      force_trigger_i           => '0',
      timestamp_i               => timestamp_i,
      version_i                 => VERSION_C,
      signal_delay_i            => SIGNAL_DELAY_C,
      descriptor_config_i       => DESCRIPTOR_CFG_C,
      frontend_dout_i           => frontend_dout_i,
      frontend_trig_i           => frontend_trig_i,
      trigger_control_i         => TRIGGER_CTRL_C,
      rd_en_i                   => RD_EN_C,
      frontend_dout_o           => frontend_dout_o,
      frontend_trig_o           => frontend_trig_o,
      trigger_result_o          => trigger_result_o,
      descriptor_result_o       => descriptor_result_o,
      record_count_o            => record_count_o,
      full_count_o              => full_count_o,
      busy_count_o              => busy_count_o,
      trigger_count_o           => trigger_count_o,
      packet_count_o            => packet_count_o,
      delayed_sample_o          => delayed_sample_o,
      ready_o                   => ready_o,
      dout_o                    => dout_o
    );

  timing_ref : entity work.timing_subsystem_boundary
    port map (
      clk_axi       => timing_clk_axi_i,
      resetn_axi    => timing_resetn_axi_i,
      timing_ctrl_i => timing_ctrl_i,
      timing_stat_o => timing_stat_ref_o,
      timestamp_o   => timing_timestamp_ref_o,
      sync_o        => timing_sync_ref_o,
      sync_stb_o    => timing_sync_stb_ref_o
    );

  assert frontend_dout_o = frontend_dout_i
    report "frontend shell must preserve frontend_dout_o exactly"
    severity failure;

  assert frontend_trig_o = frontend_trig_i
    report "frontend shell must preserve frontend_trig_o exactly"
    severity failure;

  assert timing_stat_o = timing_stat_ref_o
    report "frontend shell must expose the timing boundary status image directly, independent of ENABLE_TIMING_G"
    severity failure;

  assert timing_timestamp_o = timing_timestamp_ref_o
    report "frontend shell timing timestamp must follow the timing boundary contract"
    severity failure;

  assert timing_sync_o = timing_sync_ref_o
    report "frontend shell timing sync bus must follow the timing boundary contract"
    severity failure;

  assert timing_sync_stb_o = timing_sync_stb_ref_o
    report "frontend shell timing sync strobe must follow the timing boundary contract"
    severity failure;

  assert hermes_descriptor_taken_o = '0'
    report "frontend shell must not consume descriptors when Hermes is disabled"
    severity failure;

  assert hermes_stat_o = HERMES_BOUNDARY_STATUS_NULL
    report "frontend shell must expose null Hermes status when Hermes is disabled"
    severity failure;

  gen_channel : for idx in 0 to 39 generate
  begin
    assert trigger_result_o(idx) = TRIGGER_XCORR_RESULT_NULL
      report "frontend shell must null out self-trigger results when self-triggering is disabled"
      severity failure;

    assert descriptor_result_o(idx) = PEAK_DESCRIPTOR_RESULT_NULL
      report "frontend shell must null out descriptor results when self-triggering is disabled"
      severity failure;

    assert record_count_o(idx) = (record_count_o(idx)'range => '0')
      report "frontend shell record counters must stay low when self-triggering is disabled"
      severity failure;

    assert full_count_o(idx) = (full_count_o(idx)'range => '0')
      report "frontend shell full counters must stay low when self-triggering is disabled"
      severity failure;

    assert busy_count_o(idx) = (busy_count_o(idx)'range => '0')
      report "frontend shell busy counters must stay low when self-triggering is disabled"
      severity failure;

    assert trigger_count_o(idx) = (trigger_count_o(idx)'range => '0')
      report "frontend shell trigger counters must stay low when self-triggering is disabled"
      severity failure;

    assert packet_count_o(idx) = (packet_count_o(idx)'range => '0')
      report "frontend shell packet counters must stay low when self-triggering is disabled"
      severity failure;

    assert delayed_sample_o(idx) = (delayed_sample_o(idx)'range => '0')
      report "frontend shell delayed samples must stay low when self-triggering is disabled"
      severity failure;

    assert ready_o(idx) = '0'
      report "frontend shell ready flags must stay low when self-triggering is disabled"
      severity failure;

    assert dout_o(idx) = (dout_o(idx)'range => '0')
      report "frontend shell record stream words must stay low when self-triggering is disabled"
      severity failure;
  end generate gen_channel;
end architecture formal;
