library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity daphne_composable_core_top_formal is
  port (
    clock_i             : in std_logic;
    reset_i             : in std_logic;
    timing_clk_axi_i    : in std_logic;
    timing_resetn_axi_i : in std_logic;
    timing_ctrl_a       : in timing_control_t;
    timing_ctrl_b       : in timing_control_t;
    hermes_descriptor_a : in trigger_descriptor_t;
    hermes_descriptor_b : in trigger_descriptor_t;
    timestamp_a         : in std_logic_vector(63 downto 0);
    timestamp_b         : in std_logic_vector(63 downto 0);
    din_a               : in sample14_array_t(0 to 39);
    din_b               : in sample14_array_t(0 to 39);
    trigger_control_a   : in trigger_xcorr_control_array_t(0 to 39);
    trigger_control_b   : in trigger_xcorr_control_array_t(0 to 39);
    rd_en_a             : in std_logic_array_t(0 to 39);
    rd_en_b             : in std_logic_array_t(0 to 39)
  );
end entity daphne_composable_core_top_formal;

architecture formal of daphne_composable_core_top_formal is
  constant CONFIG_VALID_C   : std_logic_vector(4 downto 0) := (others => '0');
  constant AFE_MISO_C       : std_logic_vector(4 downto 0) := (others => '0');
  constant VERSION_C        : std_logic_vector(3 downto 0) := (others => '0');
  constant SIGNAL_DELAY_C   : std_logic_vector(4 downto 0) := (others => '0');
  constant DESCRIPTOR_CFG_C : std_logic_vector(13 downto 0) := (others => '0');
  constant CONFIG_CMD_C     : afe_config_command_bank_t(0 to 4) :=
    (others => AFE_CONFIG_COMMAND_NULL);

  signal timing_stat_a             : timing_status_t;
  signal timing_stat_b             : timing_status_t;
  signal timing_timestamp_a        : std_logic_vector(63 downto 0);
  signal timing_timestamp_b        : std_logic_vector(63 downto 0);
  signal timing_sync_a             : std_logic_vector(7 downto 0);
  signal timing_sync_b             : std_logic_vector(7 downto 0);
  signal timing_sync_stb_a         : std_logic;
  signal timing_sync_stb_b         : std_logic;
  signal timing_stat_ref_a         : timing_status_t;
  signal timing_stat_ref_b         : timing_status_t;
  signal timing_timestamp_ref_a    : std_logic_vector(63 downto 0);
  signal timing_timestamp_ref_b    : std_logic_vector(63 downto 0);
  signal timing_sync_ref_a         : std_logic_vector(7 downto 0);
  signal timing_sync_ref_b         : std_logic_vector(7 downto 0);
  signal timing_sync_stb_ref_a     : std_logic;
  signal timing_sync_stb_ref_b     : std_logic;
  signal hermes_descriptor_taken_a : std_logic;
  signal hermes_descriptor_taken_b : std_logic;
  signal hermes_stat_a             : hermes_boundary_status_t;
  signal hermes_stat_b             : hermes_boundary_status_t;
  signal config_status_a           : afe_config_status_bank_t(0 to 4);
  signal config_status_b           : afe_config_status_bank_t(0 to 4);
  signal afe_sclk_a                : std_logic_vector(4 downto 0);
  signal afe_sclk_b                : std_logic_vector(4 downto 0);
  signal afe_sen_a                 : std_logic_vector(4 downto 0);
  signal afe_sen_b                 : std_logic_vector(4 downto 0);
  signal afe_mosi_a                : std_logic_vector(4 downto 0);
  signal afe_mosi_b                : std_logic_vector(4 downto 0);
  signal trim_sclk_a               : std_logic_vector(4 downto 0);
  signal trim_sclk_b               : std_logic_vector(4 downto 0);
  signal trim_mosi_a               : std_logic_vector(4 downto 0);
  signal trim_mosi_b               : std_logic_vector(4 downto 0);
  signal trim_ldac_n_a             : std_logic_vector(4 downto 0);
  signal trim_ldac_n_b             : std_logic_vector(4 downto 0);
  signal trim_sync_n_a             : std_logic_vector(4 downto 0);
  signal trim_sync_n_b             : std_logic_vector(4 downto 0);
  signal offset_sclk_a             : std_logic_vector(4 downto 0);
  signal offset_sclk_b             : std_logic_vector(4 downto 0);
  signal offset_mosi_a             : std_logic_vector(4 downto 0);
  signal offset_mosi_b             : std_logic_vector(4 downto 0);
  signal offset_ldac_n_a           : std_logic_vector(4 downto 0);
  signal offset_ldac_n_b           : std_logic_vector(4 downto 0);
  signal offset_sync_n_a           : std_logic_vector(4 downto 0);
  signal offset_sync_n_b           : std_logic_vector(4 downto 0);
  signal trigger_result_a          : trigger_xcorr_result_array_t(0 to 39);
  signal trigger_result_b          : trigger_xcorr_result_array_t(0 to 39);
  signal descriptor_result_a       : peak_descriptor_result_array_t(0 to 39);
  signal descriptor_result_b       : peak_descriptor_result_array_t(0 to 39);
  signal record_count_a            : slv64_array_t(0 to 39);
  signal record_count_b            : slv64_array_t(0 to 39);
  signal full_count_a              : slv64_array_t(0 to 39);
  signal full_count_b              : slv64_array_t(0 to 39);
  signal busy_count_a              : slv64_array_t(0 to 39);
  signal busy_count_b              : slv64_array_t(0 to 39);
  signal trigger_count_a           : slv64_array_t(0 to 39);
  signal trigger_count_b           : slv64_array_t(0 to 39);
  signal packet_count_a            : slv64_array_t(0 to 39);
  signal packet_count_b            : slv64_array_t(0 to 39);
  signal delayed_sample_a          : sample14_array_t(0 to 39);
  signal delayed_sample_b          : sample14_array_t(0 to 39);
  signal ready_a                   : std_logic_array_t(0 to 39);
  signal ready_b                   : std_logic_array_t(0 to 39);
  signal dout_a                    : slv72_array_t(0 to 39);
  signal dout_b                    : slv72_array_t(0 to 39);
begin
  dut_a : entity work.daphne_composable_core_top
    generic map (
      AFE_COUNT_G          => 5,
      ENABLE_SELFTRIGGER_G => false,
      ENABLE_TIMING_G      => false,
      ENABLE_HERMES_G      => false
    )
    port map (
      clock_i                   => clock_i,
      reset_i                   => reset_i,
      timing_clk_axi_i          => timing_clk_axi_i,
      timing_resetn_axi_i       => timing_resetn_axi_i,
      timing_ctrl_i             => timing_ctrl_a,
      timing_stat_o             => timing_stat_a,
      timing_timestamp_o        => timing_timestamp_a,
      timing_sync_o             => timing_sync_a,
      timing_sync_stb_o         => timing_sync_stb_a,
      hermes_descriptor_i       => hermes_descriptor_a,
      hermes_descriptor_taken_o => hermes_descriptor_taken_a,
      hermes_stat_o             => hermes_stat_a,
      config_valid_i            => CONFIG_VALID_C,
      config_cmd_i              => CONFIG_CMD_C,
      config_status_o           => config_status_a,
      afe_miso_i                => AFE_MISO_C,
      afe_sclk_o                => afe_sclk_a,
      afe_sen_o                 => afe_sen_a,
      afe_mosi_o                => afe_mosi_a,
      trim_sclk_o               => trim_sclk_a,
      trim_mosi_o               => trim_mosi_a,
      trim_ldac_n_o             => trim_ldac_n_a,
      trim_sync_n_o             => trim_sync_n_a,
      offset_sclk_o             => offset_sclk_a,
      offset_mosi_o             => offset_mosi_a,
      offset_ldac_n_o           => offset_ldac_n_a,
      offset_sync_n_o           => offset_sync_n_a,
      reset_st_counters_i       => '0',
      force_trigger_i           => '0',
      timestamp_i               => timestamp_a,
      version_i                 => VERSION_C,
      signal_delay_i            => SIGNAL_DELAY_C,
      descriptor_config_i       => DESCRIPTOR_CFG_C,
      din_i                     => din_a,
      trigger_control_i         => trigger_control_a,
      rd_en_i                   => rd_en_a,
      trigger_result_o          => trigger_result_a,
      descriptor_result_o       => descriptor_result_a,
      record_count_o            => record_count_a,
      full_count_o              => full_count_a,
      busy_count_o              => busy_count_a,
      trigger_count_o           => trigger_count_a,
      packet_count_o            => packet_count_a,
      delayed_sample_o          => delayed_sample_a,
      ready_o                   => ready_a,
      dout_o                    => dout_a
    );

  dut_b : entity work.daphne_composable_core_top
    generic map (
      AFE_COUNT_G          => 5,
      ENABLE_SELFTRIGGER_G => false,
      ENABLE_TIMING_G      => false,
      ENABLE_HERMES_G      => false
    )
    port map (
      clock_i                   => clock_i,
      reset_i                   => reset_i,
      timing_clk_axi_i          => timing_clk_axi_i,
      timing_resetn_axi_i       => timing_resetn_axi_i,
      timing_ctrl_i             => timing_ctrl_b,
      timing_stat_o             => timing_stat_b,
      timing_timestamp_o        => timing_timestamp_b,
      timing_sync_o             => timing_sync_b,
      timing_sync_stb_o         => timing_sync_stb_b,
      hermes_descriptor_i       => hermes_descriptor_b,
      hermes_descriptor_taken_o => hermes_descriptor_taken_b,
      hermes_stat_o             => hermes_stat_b,
      config_valid_i            => CONFIG_VALID_C,
      config_cmd_i              => CONFIG_CMD_C,
      config_status_o           => config_status_b,
      afe_miso_i                => AFE_MISO_C,
      afe_sclk_o                => afe_sclk_b,
      afe_sen_o                 => afe_sen_b,
      afe_mosi_o                => afe_mosi_b,
      trim_sclk_o               => trim_sclk_b,
      trim_mosi_o               => trim_mosi_b,
      trim_ldac_n_o             => trim_ldac_n_b,
      trim_sync_n_o             => trim_sync_n_b,
      offset_sclk_o             => offset_sclk_b,
      offset_mosi_o             => offset_mosi_b,
      offset_ldac_n_o           => offset_ldac_n_b,
      offset_sync_n_o           => offset_sync_n_b,
      reset_st_counters_i       => '0',
      force_trigger_i           => '0',
      timestamp_i               => timestamp_b,
      version_i                 => VERSION_C,
      signal_delay_i            => SIGNAL_DELAY_C,
      descriptor_config_i       => DESCRIPTOR_CFG_C,
      din_i                     => din_b,
      trigger_control_i         => trigger_control_b,
      rd_en_i                   => rd_en_b,
      trigger_result_o          => trigger_result_b,
      descriptor_result_o       => descriptor_result_b,
      record_count_o            => record_count_b,
      full_count_o              => full_count_b,
      busy_count_o              => busy_count_b,
      trigger_count_o           => trigger_count_b,
      packet_count_o            => packet_count_b,
      delayed_sample_o          => delayed_sample_b,
      ready_o                   => ready_b,
      dout_o                    => dout_b
    );

  timing_ref_a : entity work.timing_subsystem_boundary
    port map (
      clk_axi       => timing_clk_axi_i,
      resetn_axi    => timing_resetn_axi_i,
      timing_ctrl_i => timing_ctrl_a,
      timing_stat_o => timing_stat_ref_a,
      timestamp_o   => timing_timestamp_ref_a,
      sync_o        => timing_sync_ref_a,
      sync_stb_o    => timing_sync_stb_ref_a
    );

  timing_ref_b : entity work.timing_subsystem_boundary
    port map (
      clk_axi       => timing_clk_axi_i,
      resetn_axi    => timing_resetn_axi_i,
      timing_ctrl_i => timing_ctrl_b,
      timing_stat_o => timing_stat_ref_b,
      timestamp_o   => timing_timestamp_ref_b,
      sync_o        => timing_sync_ref_b,
      sync_stb_o    => timing_sync_stb_ref_b
    );

  assert timing_stat_a = timing_stat_ref_a
    report "core top must expose the timing boundary status image directly, independent of ENABLE_TIMING_G"
    severity failure;

  assert timing_stat_b = timing_stat_ref_b
    report "core top timing status must follow the boundary contract for arbitrary timing control payloads"
    severity failure;

  assert timing_timestamp_a = timing_timestamp_ref_a
    report "core top must expose the timing boundary timestamp image directly, independent of ENABLE_TIMING_G"
    severity failure;

  assert timing_timestamp_b = timing_timestamp_ref_b
    report "core top timing timestamp must follow the boundary contract for arbitrary timing control payloads"
    severity failure;

  assert timing_sync_a = timing_sync_ref_a
    report "core top must expose the timing boundary sync bus directly, independent of ENABLE_TIMING_G"
    severity failure;

  assert timing_sync_b = timing_sync_ref_b
    report "core top timing sync bus must follow the boundary contract for arbitrary timing control payloads"
    severity failure;

  assert timing_sync_stb_a = timing_sync_stb_ref_a
    report "core top must expose the timing boundary sync strobe directly, independent of ENABLE_TIMING_G"
    severity failure;

  assert timing_sync_stb_b = timing_sync_stb_ref_b
    report "core top timing sync strobe must follow the boundary contract for arbitrary timing control payloads"
    severity failure;

  assert hermes_descriptor_taken_a = '0'
    report "core top must not consume descriptors when Hermes is disabled"
    severity failure;

  assert hermes_descriptor_taken_b = '0'
    report "disabled Hermes path must ignore descriptor payloads"
    severity failure;

  assert hermes_stat_a = HERMES_BOUNDARY_STATUS_NULL
    report "core top must expose null Hermes status when Hermes is disabled"
    severity failure;

  assert hermes_stat_b = HERMES_BOUNDARY_STATUS_NULL
    report "disabled Hermes path must remain descriptor-independent"
    severity failure;

  gen_channel : for idx in 0 to 39 generate
  begin
    assert trigger_result_a(idx) = TRIGGER_XCORR_RESULT_NULL
      report "core top must null out self-trigger results when self-triggering is disabled"
      severity failure;

    assert trigger_result_b(idx) = TRIGGER_XCORR_RESULT_NULL
      report "disabled self-trigger path must ignore channel-local trigger inputs"
      severity failure;

    assert descriptor_result_a(idx) = PEAK_DESCRIPTOR_RESULT_NULL
      report "core top must null out descriptor results when self-triggering is disabled"
      severity failure;

    assert descriptor_result_b(idx) = PEAK_DESCRIPTOR_RESULT_NULL
      report "disabled descriptor path must ignore channel-local trigger inputs"
      severity failure;

    assert record_count_a(idx) = (record_count_a(idx)'range => '0')
      report "record counters must stay low when self-triggering is disabled"
      severity failure;

    assert record_count_b(idx) = (record_count_b(idx)'range => '0')
      report "disabled self-trigger counters must remain input-independent"
      severity failure;

    assert full_count_a(idx) = (full_count_a(idx)'range => '0')
      report "FIFO full counters must stay low when self-triggering is disabled"
      severity failure;

    assert full_count_b(idx) = (full_count_b(idx)'range => '0')
      report "disabled full counters must remain input-independent"
      severity failure;

    assert busy_count_a(idx) = (busy_count_a(idx)'range => '0')
      report "busy counters must stay low when self-triggering is disabled"
      severity failure;

    assert busy_count_b(idx) = (busy_count_b(idx)'range => '0')
      report "disabled busy counters must remain input-independent"
      severity failure;

    assert trigger_count_a(idx) = (trigger_count_a(idx)'range => '0')
      report "trigger counters must stay low when self-triggering is disabled"
      severity failure;

    assert trigger_count_b(idx) = (trigger_count_b(idx)'range => '0')
      report "disabled trigger counters must remain input-independent"
      severity failure;

    assert packet_count_a(idx) = (packet_count_a(idx)'range => '0')
      report "packet counters must stay low when self-triggering is disabled"
      severity failure;

    assert packet_count_b(idx) = (packet_count_b(idx)'range => '0')
      report "disabled packet counters must remain input-independent"
      severity failure;

    assert delayed_sample_a(idx) = (delayed_sample_a(idx)'range => '0')
      report "delayed samples must stay low when self-triggering is disabled"
      severity failure;

    assert delayed_sample_b(idx) = (delayed_sample_b(idx)'range => '0')
      report "disabled delayed samples must remain input-independent"
      severity failure;

    assert ready_a(idx) = '0'
      report "ready flags must stay low when self-triggering is disabled"
      severity failure;

    assert ready_b(idx) = '0'
      report "disabled ready flags must remain input-independent"
      severity failure;

    assert dout_a(idx) = (dout_a(idx)'range => '0')
      report "record stream words must stay low when self-triggering is disabled"
      severity failure;

    assert dout_b(idx) = (dout_b(idx)'range => '0')
      report "disabled record stream words must remain input-independent"
      severity failure;
  end generate gen_channel;
end architecture formal;
