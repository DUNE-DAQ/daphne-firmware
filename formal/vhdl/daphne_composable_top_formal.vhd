library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity daphne_composable_top_formal is
  port (
    clock_i             : in std_logic;
    clk500_i            : in std_logic;
    clk125_i            : in std_logic;
    trig_in_i           : in std_logic;
    frontend_axi_aclk_i : in std_logic;
    frontend_resetn_i   : in std_logic;
    timing_resetn_axi_i : in std_logic;
    timing_ctrl_i       : in timing_control_t;
    hermes_descriptor_i : in trigger_descriptor_t;
    afe_p_i             : in array_5x9_type;
    afe_n_i             : in array_5x9_type
  );
end entity daphne_composable_top_formal;

architecture formal of daphne_composable_top_formal is
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

  signal afe_clk_p_o             : std_logic;
  signal afe_clk_n_o             : std_logic;
  signal frontend_axi_awready_o  : std_logic;
  signal frontend_axi_wready_o   : std_logic;
  signal frontend_axi_bresp_o    : std_logic_vector(1 downto 0);
  signal frontend_axi_bvalid_o   : std_logic;
  signal frontend_axi_arready_o  : std_logic;
  signal frontend_axi_rdata_o    : std_logic_vector(31 downto 0);
  signal frontend_axi_rresp_o    : std_logic_vector(1 downto 0);
  signal frontend_axi_rvalid_o   : std_logic;
  signal timing_stat_o           : timing_status_t;
  signal timing_timestamp_o      : std_logic_vector(63 downto 0);
  signal timing_sync_o           : std_logic_vector(7 downto 0);
  signal timing_sync_stb_o       : std_logic;
  signal hermes_descriptor_taken_o : std_logic;
  signal hermes_stat_o           : hermes_boundary_status_t;
  signal config_status_o         : afe_config_status_bank_t(0 to 4);
  signal afe_sclk_o              : std_logic_vector(4 downto 0);
  signal afe_sen_o               : std_logic_vector(4 downto 0);
  signal afe_mosi_o              : std_logic_vector(4 downto 0);
  signal trim_sclk_o             : std_logic_vector(4 downto 0);
  signal trim_mosi_o             : std_logic_vector(4 downto 0);
  signal trim_ldac_n_o           : std_logic_vector(4 downto 0);
  signal trim_sync_n_o           : std_logic_vector(4 downto 0);
  signal offset_sclk_o           : std_logic_vector(4 downto 0);
  signal offset_mosi_o           : std_logic_vector(4 downto 0);
  signal offset_ldac_n_o         : std_logic_vector(4 downto 0);
  signal offset_sync_n_o         : std_logic_vector(4 downto 0);
  signal frontend_dout_o         : array_5x9x16_type;
  signal frontend_trig_o         : std_logic;
  signal trigger_result_o        : trigger_xcorr_result_array_t(0 to 39);
  signal descriptor_result_o     : peak_descriptor_result_array_t(0 to 39);
  signal record_count_o          : slv64_array_t(0 to 39);
  signal full_count_o            : slv64_array_t(0 to 39);
  signal busy_count_o            : slv64_array_t(0 to 39);
  signal trigger_count_o         : slv64_array_t(0 to 39);
  signal packet_count_o          : slv64_array_t(0 to 39);
  signal delayed_sample_o        : sample14_array_t(0 to 39);
  signal ready_o                 : std_logic_array_t(0 to 39);
  signal dout_o                  : slv72_array_t(0 to 39);
  signal shell_timing_stat_o     : timing_status_t;
  signal shell_timing_timestamp_o : std_logic_vector(63 downto 0);
  signal shell_timing_sync_o     : std_logic_vector(7 downto 0);
  signal shell_timing_sync_stb_o : std_logic;
  signal timing_stat_ref_o       : timing_status_t;
  signal timing_timestamp_ref_o  : std_logic_vector(63 downto 0);
  signal timing_sync_ref_o       : std_logic_vector(7 downto 0);
  signal timing_sync_stb_ref_o   : std_logic;
  signal shell_hermes_descriptor_taken_o : std_logic;
  signal shell_hermes_stat_o     : hermes_boundary_status_t;
  signal shell_frontend_dout_o   : array_5x9x16_type;
  signal shell_frontend_trig_o   : std_logic;
  signal shell_trigger_result_o  : trigger_xcorr_result_array_t(0 to 39);
  signal shell_descriptor_result_o : peak_descriptor_result_array_t(0 to 39);
  signal shell_record_count_o    : slv64_array_t(0 to 39);
  signal shell_full_count_o      : slv64_array_t(0 to 39);
  signal shell_busy_count_o      : slv64_array_t(0 to 39);
  signal shell_trigger_count_o   : slv64_array_t(0 to 39);
  signal shell_packet_count_o    : slv64_array_t(0 to 39);
  signal shell_delayed_sample_o  : sample14_array_t(0 to 39);
  signal shell_ready_o           : std_logic_array_t(0 to 39);
  signal shell_dout_o            : slv72_array_t(0 to 39);
  signal trigger_samples_probe   : sample14_array_t(0 to 39);
  signal frontend_trig_ref_i     : std_logic;
  signal frontend_dout_ref_i     : array_5x9x16_type;
begin
  frontend_trig_ref_i <= trig_in_i;

  gen_reference_afe : for afe in 0 to 4 generate
    gen_reference_lane : for lane in 0 to 8 generate
    begin
      frontend_dout_ref_i(afe)(lane)(15 downto 1) <= (15 downto 1 => afe_p_i(afe)(lane));
      frontend_dout_ref_i(afe)(lane)(0)            <= afe_n_i(afe)(lane);
    end generate gen_reference_lane;
  end generate gen_reference_afe;

  probe_adapter : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => 5
    )
    port map (
      afe_dout_i        => frontend_dout_o,
      trigger_samples_o => trigger_samples_probe
    );

  -- Keep the public-top proof tied to the standalone shell seam contract.
  reference_shell : entity work.daphne_composable_frontend_shell
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
      timing_clk_axi_i          => frontend_axi_aclk_i,
      timing_resetn_axi_i       => timing_resetn_axi_i,
      timing_ctrl_i             => timing_ctrl_i,
      timing_stat_o             => shell_timing_stat_o,
      timing_timestamp_o        => shell_timing_timestamp_o,
      timing_sync_o             => shell_timing_sync_o,
      timing_sync_stb_o         => shell_timing_sync_stb_o,
      hermes_descriptor_i       => hermes_descriptor_i,
      hermes_descriptor_taken_o => shell_hermes_descriptor_taken_o,
      hermes_stat_o             => shell_hermes_stat_o,
      config_valid_i            => CONFIG_VALID_C,
      config_cmd_i              => CONFIG_CMD_C,
      config_status_o           => open,
      afe_miso_i                => AFE_MISO_C,
      afe_sclk_o                => open,
      afe_sen_o                 => open,
      afe_mosi_o                => open,
      trim_sclk_o               => open,
      trim_mosi_o               => open,
      trim_ldac_n_o             => open,
      trim_sync_n_o             => open,
      offset_sclk_o             => open,
      offset_mosi_o             => open,
      offset_ldac_n_o           => open,
      offset_sync_n_o           => open,
      reset_st_counters_i       => '0',
      force_trigger_i           => '0',
      timestamp_i               => (others => '0'),
      version_i                 => VERSION_C,
      signal_delay_i            => SIGNAL_DELAY_C,
      descriptor_config_i       => DESCRIPTOR_CFG_C,
      frontend_dout_i           => frontend_dout_ref_i,
      frontend_trig_i           => frontend_trig_ref_i,
      trigger_control_i         => TRIGGER_CTRL_C,
      rd_en_i                   => RD_EN_C,
      frontend_dout_o           => shell_frontend_dout_o,
      frontend_trig_o           => shell_frontend_trig_o,
      trigger_result_o          => shell_trigger_result_o,
      descriptor_result_o       => shell_descriptor_result_o,
      record_count_o            => shell_record_count_o,
      full_count_o              => shell_full_count_o,
      busy_count_o              => shell_busy_count_o,
      trigger_count_o           => shell_trigger_count_o,
      packet_count_o            => shell_packet_count_o,
      delayed_sample_o          => shell_delayed_sample_o,
      ready_o                   => shell_ready_o,
      dout_o                    => shell_dout_o
    );

  timing_ref : entity work.timing_subsystem_boundary
    port map (
      clk_axi       => frontend_axi_aclk_i,
      resetn_axi    => timing_resetn_axi_i,
      timing_ctrl_i => timing_ctrl_i,
      timing_stat_o => timing_stat_ref_o,
      timestamp_o   => timing_timestamp_ref_o,
      sync_o        => timing_sync_ref_o,
      sync_stb_o    => timing_sync_stb_ref_o
    );

  dut : entity work.daphne_composable_top
    generic map (
      AFE_COUNT_G          => 5,
      ENABLE_SELFTRIGGER_G => false,
      ENABLE_TIMING_G      => false,
      ENABLE_HERMES_G      => false,
      ENABLE_SPYBUFFER_G   => false
    )
    port map (
      afe_p                 => afe_p_i,
      afe_n                 => afe_n_i,
      afe_clk_p             => afe_clk_p_o,
      afe_clk_n             => afe_clk_n_o,
      clk500                => clk500_i,
      clk125                => clk125_i,
      clock                 => clock_i,
      trig_in               => trig_in_i,
      frontend_axi_aclk     => frontend_axi_aclk_i,
      frontend_axi_aresetn  => frontend_resetn_i,
      frontend_axi_awaddr   => (others => '0'),
      frontend_axi_awprot   => (others => '0'),
      frontend_axi_awvalid  => '0',
      frontend_axi_awready  => frontend_axi_awready_o,
      frontend_axi_wdata    => (others => '0'),
      frontend_axi_wstrb    => (others => '0'),
      frontend_axi_wvalid   => '0',
      frontend_axi_wready   => frontend_axi_wready_o,
      frontend_axi_bresp    => frontend_axi_bresp_o,
      frontend_axi_bvalid   => frontend_axi_bvalid_o,
      frontend_axi_bready   => '0',
      frontend_axi_araddr   => (others => '0'),
      frontend_axi_arprot   => (others => '0'),
      frontend_axi_arvalid  => '0',
      frontend_axi_arready  => frontend_axi_arready_o,
      frontend_axi_rdata    => frontend_axi_rdata_o,
      frontend_axi_rresp    => frontend_axi_rresp_o,
      frontend_axi_rvalid   => frontend_axi_rvalid_o,
      frontend_axi_rready   => '0',
      timing_clk_axi_i      => frontend_axi_aclk_i,
      timing_resetn_axi_i   => timing_resetn_axi_i,
      timing_ctrl_i         => timing_ctrl_i,
      timing_stat_o         => timing_stat_o,
      timing_timestamp_o    => timing_timestamp_o,
      timing_sync_o         => timing_sync_o,
      timing_sync_stb_o     => timing_sync_stb_o,
      hermes_descriptor_i   => hermes_descriptor_i,
      hermes_descriptor_taken_o => hermes_descriptor_taken_o,
      hermes_stat_o         => hermes_stat_o,
      config_valid_i        => CONFIG_VALID_C,
      config_cmd_i          => CONFIG_CMD_C,
      config_status_o       => config_status_o,
      afe_miso_i            => AFE_MISO_C,
      afe_sclk_o            => afe_sclk_o,
      afe_sen_o             => afe_sen_o,
      afe_mosi_o            => afe_mosi_o,
      trim_sclk_o           => trim_sclk_o,
      trim_mosi_o           => trim_mosi_o,
      trim_ldac_n_o         => trim_ldac_n_o,
      trim_sync_n_o         => trim_sync_n_o,
      offset_sclk_o         => offset_sclk_o,
      offset_mosi_o         => offset_mosi_o,
      offset_ldac_n_o       => offset_ldac_n_o,
      offset_sync_n_o       => offset_sync_n_o,
      reset_st_counters_i   => '0',
      force_trigger_i       => '0',
      timestamp_i           => (others => '0'),
      version_i             => VERSION_C,
      signal_delay_i        => SIGNAL_DELAY_C,
      descriptor_config_i   => DESCRIPTOR_CFG_C,
      trigger_control_i     => TRIGGER_CTRL_C,
      rd_en_i               => RD_EN_C,
      frontend_dout_o       => frontend_dout_o,
      frontend_trig_o       => frontend_trig_o,
      trigger_result_o      => trigger_result_o,
      descriptor_result_o   => descriptor_result_o,
      record_count_o        => record_count_o,
      full_count_o          => full_count_o,
      busy_count_o          => busy_count_o,
      trigger_count_o       => trigger_count_o,
      packet_count_o        => packet_count_o,
      delayed_sample_o      => delayed_sample_o,
      ready_o               => ready_o,
      dout_o                => dout_o
    );

  assert afe_clk_p_o = clock_i
    report "public composable top validate path must forward the frontend clock pattern from the stub"
    severity failure;

  assert afe_clk_n_o = not clock_i
    report "public composable top validate path must drive the inverted frontend clock pattern from the stub"
    severity failure;

  assert frontend_dout_o = shell_frontend_dout_o
    report "public composable top must preserve the standalone frontend shell seam lane image exactly"
    severity failure;

  assert frontend_trig_o = trig_in_i
    report "public composable top must preserve the frontend trigger path through the validate stub"
    severity failure;

  assert frontend_trig_o = shell_frontend_trig_o
    report "public composable top must match the standalone frontend shell trigger output"
    severity failure;

  assert frontend_axi_awready_o = '0'
    report "validate frontend stub must keep AXI write address ready low"
    severity failure;

  assert frontend_axi_wready_o = '0'
    report "validate frontend stub must keep AXI write data ready low"
    severity failure;

  assert frontend_axi_bresp_o = (frontend_axi_bresp_o'range => '0')
    report "validate frontend stub must keep AXI write response zeroed"
    severity failure;

  assert frontend_axi_bvalid_o = '0'
    report "validate frontend stub must keep AXI write response invalid"
    severity failure;

  assert frontend_axi_arready_o = '0'
    report "validate frontend stub must keep AXI read address ready low"
    severity failure;

  assert frontend_axi_rdata_o = (frontend_axi_rdata_o'range => '0')
    report "validate frontend stub must keep AXI read data zeroed"
    severity failure;

  assert frontend_axi_rresp_o = (frontend_axi_rresp_o'range => '0')
    report "validate frontend stub must keep AXI read response zeroed"
    severity failure;

  assert frontend_axi_rvalid_o = '0'
    report "validate frontend stub must keep AXI read response invalid"
    severity failure;

  assert timing_stat_o = timing_stat_ref_o
    report "public composable top timing status must follow the timing boundary contract"
    severity failure;

  assert timing_stat_o = shell_timing_stat_o
    report "public composable top timing status must match the standalone frontend shell contract"
    severity failure;

  assert timing_timestamp_o = timing_timestamp_ref_o
    report "public composable top timing timestamp must follow the timing boundary contract"
    severity failure;

  assert timing_timestamp_o = shell_timing_timestamp_o
    report "public composable top timing timestamp must match the standalone frontend shell contract"
    severity failure;

  assert timing_sync_o = timing_sync_ref_o
    report "public composable top timing sync bus must follow the timing boundary contract"
    severity failure;

  assert timing_sync_o = shell_timing_sync_o
    report "public composable top timing sync must match the standalone frontend shell contract"
    severity failure;

  assert timing_sync_stb_o = timing_sync_stb_ref_o
    report "public composable top timing sync strobe must follow the timing boundary contract"
    severity failure;

  assert timing_sync_stb_o = shell_timing_sync_stb_o
    report "public composable top timing sync strobe must match the standalone frontend shell contract"
    severity failure;

  assert hermes_descriptor_taken_o = '0'
    report "public composable top must not consume descriptors when Hermes is disabled"
    severity failure;

  assert hermes_descriptor_taken_o = shell_hermes_descriptor_taken_o
    report "public composable top descriptor handoff must match the standalone frontend shell contract"
    severity failure;

  assert hermes_stat_o = HERMES_BOUNDARY_STATUS_NULL
    report "public composable top must expose null Hermes status when Hermes is disabled"
    severity failure;

  assert hermes_stat_o = shell_hermes_stat_o
    report "public composable top Hermes status must match the standalone frontend shell contract"
    severity failure;

  gen_afe : for afe in 0 to 4 generate
    gen_lane : for lane in 0 to 8 generate
    begin
      assert frontend_dout_o(afe)(lane)(15 downto 1) = (15 downto 1 => afe_p_i(afe)(lane))
        report "public composable top must preserve the validate frontend-island high bits for every lane"
        severity failure;

      assert frontend_dout_o(afe)(lane)(0) = afe_n_i(afe)(lane)
        report "public composable top must preserve the validate frontend-island low bit for every lane"
        severity failure;
    end generate gen_lane;
  end generate gen_afe;

  gen_adapter_afe : for afe in 0 to 4 generate
    gen_adapter_channel : for ch in 0 to 7 generate
    begin
      assert trigger_samples_probe((afe * 8) + ch) =
             frontend_dout_o(afe)(ch)(15 downto 2)
        report "public composable top must expose a frontend lane image that the adapter maps into the trigger path without reordering"
        severity failure;
    end generate gen_adapter_channel;
  end generate gen_adapter_afe;

  assert trigger_samples_probe(0) = frontend_dout_o(0)(0)(15 downto 2)
    report "public composable top channel 0 must adapt from AFE0 channel 0"
    severity failure;

  assert trigger_samples_probe(16) = frontend_dout_o(2)(0)(15 downto 2)
    report "public composable top must keep the flattened trigger-sample order contiguous across AFEs"
    severity failure;

  assert trigger_samples_probe(23) = frontend_dout_o(2)(7)(15 downto 2)
    report "public composable top must stop at the eighth data channel for each AFE before flattening"
    severity failure;

  assert trigger_samples_probe(39) = frontend_dout_o(4)(7)(15 downto 2)
    report "public composable top channel 39 must adapt from AFE4 channel 7"
    severity failure;

  gen_channel : for idx in 0 to 39 generate
  begin
    assert trigger_result_o(idx) = shell_trigger_result_o(idx)
      report "public composable top trigger results must match the standalone frontend shell contract"
      severity failure;

    assert trigger_result_o(idx) = TRIGGER_XCORR_RESULT_NULL
      report "public composable top must null out self-trigger results when self-triggering is disabled"
      severity failure;

    assert descriptor_result_o(idx) = shell_descriptor_result_o(idx)
      report "public composable top descriptor results must match the standalone frontend shell contract"
      severity failure;

    assert descriptor_result_o(idx) = PEAK_DESCRIPTOR_RESULT_NULL
      report "public composable top must null out descriptor results when self-triggering is disabled"
      severity failure;

    assert record_count_o(idx) = shell_record_count_o(idx)
      report "public composable top record counters must match the standalone frontend shell contract"
      severity failure;

    assert record_count_o(idx) = (record_count_o(idx)'range => '0')
      report "public composable top record counters must stay low when self-triggering is disabled"
      severity failure;

    assert full_count_o(idx) = shell_full_count_o(idx)
      report "public composable top full counters must match the standalone frontend shell contract"
      severity failure;

    assert full_count_o(idx) = (full_count_o(idx)'range => '0')
      report "public composable top full counters must stay low when self-triggering is disabled"
      severity failure;

    assert busy_count_o(idx) = shell_busy_count_o(idx)
      report "public composable top busy counters must match the standalone frontend shell contract"
      severity failure;

    assert busy_count_o(idx) = (busy_count_o(idx)'range => '0')
      report "public composable top busy counters must stay low when self-triggering is disabled"
      severity failure;

    assert trigger_count_o(idx) = shell_trigger_count_o(idx)
      report "public composable top trigger counters must match the standalone frontend shell contract"
      severity failure;

    assert trigger_count_o(idx) = (trigger_count_o(idx)'range => '0')
      report "public composable top trigger counters must stay low when self-triggering is disabled"
      severity failure;

    assert packet_count_o(idx) = shell_packet_count_o(idx)
      report "public composable top packet counters must match the standalone frontend shell contract"
      severity failure;

    assert packet_count_o(idx) = (packet_count_o(idx)'range => '0')
      report "public composable top packet counters must stay low when self-triggering is disabled"
      severity failure;

    assert delayed_sample_o(idx) = shell_delayed_sample_o(idx)
      report "public composable top delayed samples must match the standalone frontend shell contract"
      severity failure;

    assert delayed_sample_o(idx) = (delayed_sample_o(idx)'range => '0')
      report "public composable top delayed samples must stay low when self-triggering is disabled"
      severity failure;

    assert ready_o(idx) = shell_ready_o(idx)
      report "public composable top ready flags must match the standalone frontend shell contract"
      severity failure;

    assert ready_o(idx) = '0'
      report "public composable top ready flags must stay low when self-triggering is disabled"
      severity failure;

    assert dout_o(idx) = shell_dout_o(idx)
      report "public composable top record stream words must match the standalone frontend shell contract"
      severity failure;

    assert dout_o(idx) = (dout_o(idx)'range => '0')
      report "public composable top record stream words must stay low when self-triggering is disabled"
      severity failure;
  end generate gen_channel;
end architecture formal;
