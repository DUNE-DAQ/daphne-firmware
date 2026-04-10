library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity daphne_composable_top_analog_formal is
  port (
    clock_i             : in std_logic;
    clk500_i            : in std_logic;
    clk125_i            : in std_logic;
    trig_in_i           : in std_logic;
    frontend_axi_aclk_i : in std_logic;
    afe_p_i             : in array_5x9_type;
    afe_n_i             : in array_5x9_type
  );
end entity daphne_composable_top_analog_formal;

architecture formal of daphne_composable_top_analog_formal is
  constant STEP_LAST_C     : integer := 4;
  constant CONFIG_VALID_C  : std_logic_vector(4 downto 0) := (others => '0');
  constant AFE_MISO_C      : std_logic_vector(4 downto 0) := (others => '0');
  constant HIGH_5_C        : std_logic_vector(4 downto 0) := (others => '1');
  constant LOW_5_C         : std_logic_vector(4 downto 0) := (others => '0');
  constant VERSION_C       : std_logic_vector(3 downto 0) := (others => '0');
  constant SIGNAL_DELAY_C  : std_logic_vector(4 downto 0) := (others => '0');
  constant DESCRIPTOR_CFG_C : std_logic_vector(13 downto 0) := (others => '0');
  constant CONFIG_CMD_C    : afe_config_command_bank_t(0 to 4) :=
    (others => AFE_CONFIG_COMMAND_NULL);
  constant TRIGGER_CTRL_C  : trigger_xcorr_control_array_t(0 to 39) :=
    (others => TRIGGER_XCORR_CONTROL_NULL);
  constant RD_EN_C         : std_logic_array_t(0 to 39) := (others => '0');

  signal step_s                 : integer range 0 to STEP_LAST_C := 0;
  signal frontend_resetn_s      : std_logic := '0';
  signal frontend_dout_ref_i    : array_5x9x16_type;
  signal shell_config_status_o  : afe_config_status_bank_t(0 to 4);
  signal shell_afe_sclk_o       : std_logic_vector(4 downto 0);
  signal shell_afe_sen_o        : std_logic_vector(4 downto 0);
  signal shell_afe_mosi_o       : std_logic_vector(4 downto 0);
  signal shell_trim_sclk_o      : std_logic_vector(4 downto 0);
  signal shell_trim_mosi_o      : std_logic_vector(4 downto 0);
  signal shell_trim_ldac_n_o    : std_logic_vector(4 downto 0);
  signal shell_trim_sync_n_o    : std_logic_vector(4 downto 0);
  signal shell_offset_sclk_o    : std_logic_vector(4 downto 0);
  signal shell_offset_mosi_o    : std_logic_vector(4 downto 0);
  signal shell_offset_ldac_n_o  : std_logic_vector(4 downto 0);
  signal shell_offset_sync_n_o  : std_logic_vector(4 downto 0);
  signal config_status_o        : afe_config_status_bank_t(0 to 4);
  signal afe_sclk_o             : std_logic_vector(4 downto 0);
  signal afe_sen_o              : std_logic_vector(4 downto 0);
  signal afe_mosi_o             : std_logic_vector(4 downto 0);
  signal trim_sclk_o            : std_logic_vector(4 downto 0);
  signal trim_mosi_o            : std_logic_vector(4 downto 0);
  signal trim_ldac_n_o          : std_logic_vector(4 downto 0);
  signal trim_sync_n_o          : std_logic_vector(4 downto 0);
  signal offset_sclk_o          : std_logic_vector(4 downto 0);
  signal offset_mosi_o          : std_logic_vector(4 downto 0);
  signal offset_ldac_n_o        : std_logic_vector(4 downto 0);
  signal offset_sync_n_o        : std_logic_vector(4 downto 0);
begin
  gen_reference_afe : for afe in 0 to 4 generate
    gen_reference_lane : for lane in 0 to 8 generate
    begin
      frontend_dout_ref_i(afe)(lane)(15 downto 1) <= (15 downto 1 => afe_p_i(afe)(lane));
      frontend_dout_ref_i(afe)(lane)(0)            <= afe_n_i(afe)(lane);
    end generate gen_reference_lane;
  end generate gen_reference_afe;

  reset_sequence_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      case step_s is
        when 0 =>
          frontend_resetn_s <= '0';
          step_s            <= 1;
        when 1 =>
          frontend_resetn_s <= '0';
          step_s            <= 2;
        when 2 =>
          frontend_resetn_s <= '1';
          step_s            <= 3;
        when 3 =>
          frontend_resetn_s <= '1';
          step_s            <= STEP_LAST_C;
        when others =>
          frontend_resetn_s <= '1';
          step_s            <= STEP_LAST_C;
      end case;
    end if;
  end process reset_sequence_proc;

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
      frontend_resetn_i         => frontend_resetn_s,
      timing_clk_axi_i          => frontend_axi_aclk_i,
      timing_resetn_axi_i       => '0',
      timing_ctrl_i             => TIMING_CONTROL_NULL,
      timing_stat_o             => open,
      timing_timestamp_o        => open,
      timing_sync_o             => open,
      timing_sync_stb_o         => open,
      hermes_descriptor_i       => TRIGGER_DESCRIPTOR_NULL,
      hermes_descriptor_taken_o => open,
      hermes_stat_o             => open,
      config_valid_i            => CONFIG_VALID_C,
      config_cmd_i              => CONFIG_CMD_C,
      config_status_o           => shell_config_status_o,
      afe_miso_i                => AFE_MISO_C,
      afe_sclk_o                => shell_afe_sclk_o,
      afe_sen_o                 => shell_afe_sen_o,
      afe_mosi_o                => shell_afe_mosi_o,
      trim_sclk_o               => shell_trim_sclk_o,
      trim_mosi_o               => shell_trim_mosi_o,
      trim_ldac_n_o             => shell_trim_ldac_n_o,
      trim_sync_n_o             => shell_trim_sync_n_o,
      offset_sclk_o             => shell_offset_sclk_o,
      offset_mosi_o             => shell_offset_mosi_o,
      offset_ldac_n_o           => shell_offset_ldac_n_o,
      offset_sync_n_o           => shell_offset_sync_n_o,
      reset_st_counters_i       => '0',
      force_trigger_i           => '0',
      timestamp_i               => (others => '0'),
      version_i                 => VERSION_C,
      signal_delay_i            => SIGNAL_DELAY_C,
      descriptor_config_i       => DESCRIPTOR_CFG_C,
      frontend_dout_i           => frontend_dout_ref_i,
      frontend_trig_i           => trig_in_i,
      trigger_control_i         => TRIGGER_CTRL_C,
      rd_en_i                   => RD_EN_C,
      frontend_dout_o           => open,
      frontend_trig_o           => open,
      trigger_result_o          => open,
      descriptor_result_o       => open,
      record_count_o            => open,
      full_count_o              => open,
      busy_count_o              => open,
      trigger_count_o           => open,
      packet_count_o            => open,
      delayed_sample_o          => open,
      ready_o                   => open,
      dout_o                    => open
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
      afe_p                    => afe_p_i,
      afe_n                    => afe_n_i,
      afe_clk_p                => open,
      afe_clk_n                => open,
      clk500                   => clk500_i,
      clk125                   => clk125_i,
      clock                    => clock_i,
      trig_in                  => trig_in_i,
      frontend_axi_aclk        => frontend_axi_aclk_i,
      frontend_axi_aresetn     => frontend_resetn_s,
      frontend_axi_awaddr      => (others => '0'),
      frontend_axi_awprot      => (others => '0'),
      frontend_axi_awvalid     => '0',
      frontend_axi_awready     => open,
      frontend_axi_wdata       => (others => '0'),
      frontend_axi_wstrb       => (others => '0'),
      frontend_axi_wvalid      => '0',
      frontend_axi_wready      => open,
      frontend_axi_bresp       => open,
      frontend_axi_bvalid      => open,
      frontend_axi_bready      => '0',
      frontend_axi_araddr      => (others => '0'),
      frontend_axi_arprot      => (others => '0'),
      frontend_axi_arvalid     => '0',
      frontend_axi_arready     => open,
      frontend_axi_rdata       => open,
      frontend_axi_rresp       => open,
      frontend_axi_rvalid      => open,
      frontend_axi_rready      => '0',
      timing_clk_axi_i         => frontend_axi_aclk_i,
      timing_resetn_axi_i      => '0',
      timing_ctrl_i            => TIMING_CONTROL_NULL,
      timing_stat_o            => open,
      timing_timestamp_o       => open,
      timing_sync_o            => open,
      timing_sync_stb_o        => open,
      hermes_descriptor_i      => TRIGGER_DESCRIPTOR_NULL,
      hermes_descriptor_taken_o => open,
      hermes_stat_o            => open,
      config_valid_i           => CONFIG_VALID_C,
      config_cmd_i             => CONFIG_CMD_C,
      config_status_o          => config_status_o,
      afe_miso_i               => AFE_MISO_C,
      afe_sclk_o               => afe_sclk_o,
      afe_sen_o                => afe_sen_o,
      afe_mosi_o               => afe_mosi_o,
      trim_sclk_o              => trim_sclk_o,
      trim_mosi_o              => trim_mosi_o,
      trim_ldac_n_o            => trim_ldac_n_o,
      trim_sync_n_o            => trim_sync_n_o,
      offset_sclk_o            => offset_sclk_o,
      offset_mosi_o            => offset_mosi_o,
      offset_ldac_n_o          => offset_ldac_n_o,
      offset_sync_n_o          => offset_sync_n_o,
      reset_st_counters_i      => '0',
      force_trigger_i          => '0',
      timestamp_i              => (others => '0'),
      version_i                => VERSION_C,
      signal_delay_i           => SIGNAL_DELAY_C,
      descriptor_config_i      => DESCRIPTOR_CFG_C,
      trigger_control_i        => TRIGGER_CTRL_C,
      rd_en_i                  => RD_EN_C,
      frontend_dout_o          => open,
      frontend_trig_o          => open,
      trigger_result_o         => open,
      descriptor_result_o      => open,
      record_count_o           => open,
      full_count_o             => open,
      busy_count_o             => open,
      trigger_count_o          => open,
      packet_count_o           => open,
      delayed_sample_o         => open,
      ready_o                  => open,
      dout_o                   => open
    );

  assert (step_s < STEP_LAST_C) or (afe_sclk_o = shell_afe_sclk_o)
    report "public composable top AFE serial clocks must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (afe_sen_o = shell_afe_sen_o)
    report "public composable top AFE chip-select outputs must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (afe_mosi_o = shell_afe_mosi_o)
    report "public composable top AFE MOSI outputs must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (trim_sclk_o = shell_trim_sclk_o)
    report "public composable top trim DAC clocks must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (trim_mosi_o = shell_trim_mosi_o)
    report "public composable top trim DAC MOSI outputs must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (trim_ldac_n_o = shell_trim_ldac_n_o)
    report "public composable top trim DAC LDAC outputs must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (trim_sync_n_o = shell_trim_sync_n_o)
    report "public composable top trim DAC sync outputs must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (offset_sclk_o = shell_offset_sclk_o)
    report "public composable top offset DAC clocks must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (offset_mosi_o = shell_offset_mosi_o)
    report "public composable top offset DAC MOSI outputs must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (offset_ldac_n_o = shell_offset_ldac_n_o)
    report "public composable top offset DAC LDAC outputs must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (offset_sync_n_o = shell_offset_sync_n_o)
    report "public composable top offset DAC sync outputs must match the standalone frontend shell after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (afe_sclk_o = HIGH_5_C)
    report "public composable top AFE serial clocks must return to idle-high after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (afe_sen_o = HIGH_5_C)
    report "public composable top AFE chip-select outputs must return inactive-high after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (afe_mosi_o = LOW_5_C)
    report "public composable top AFE MOSI outputs must return idle-low after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (trim_sclk_o = HIGH_5_C)
    report "public composable top trim DAC clocks must return to idle-high after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (trim_mosi_o = LOW_5_C)
    report "public composable top trim DAC MOSI outputs must return idle-low after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (trim_ldac_n_o = HIGH_5_C)
    report "public composable top trim DAC LDAC outputs must return inactive-high after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (trim_sync_n_o = HIGH_5_C)
    report "public composable top trim DAC sync outputs must return inactive-high after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (offset_sclk_o = HIGH_5_C)
    report "public composable top offset DAC clocks must return to idle-high after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (offset_mosi_o = LOW_5_C)
    report "public composable top offset DAC MOSI outputs must return idle-low after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (offset_ldac_n_o = HIGH_5_C)
    report "public composable top offset DAC LDAC outputs must return inactive-high after reset release"
    severity failure;

  assert (step_s < STEP_LAST_C) or (offset_sync_n_o = HIGH_5_C)
    report "public composable top offset DAC sync outputs must return inactive-high after reset release"
    severity failure;

  gen_afe : for afe in 0 to 4 generate
  begin
    assert (step_s < STEP_LAST_C) or
           (config_status_o(afe).afe_busy = shell_config_status_o(afe).afe_busy)
      report "public composable top AFE busy flags must match the standalone frontend shell after reset release"
      severity failure;

    assert (step_s < STEP_LAST_C) or
           (config_status_o(afe).trim_busy = shell_config_status_o(afe).trim_busy)
      report "public composable top trim busy flags must match the standalone frontend shell after reset release"
      severity failure;

    assert (step_s < STEP_LAST_C) or
           (config_status_o(afe).offset_busy = shell_config_status_o(afe).offset_busy)
      report "public composable top offset busy flags must match the standalone frontend shell after reset release"
      severity failure;

    assert (step_s < STEP_LAST_C) or
           (config_status_o(afe).ready = shell_config_status_o(afe).ready)
      report "public composable top analog ready flags must match the standalone frontend shell after reset release"
      severity failure;

    assert (step_s < STEP_LAST_C) or (config_status_o(afe).afe_busy = '0')
      report "public composable top AFE busy flags must be clear after reset release"
      severity failure;

    assert (step_s < STEP_LAST_C) or (config_status_o(afe).trim_busy = '0')
      report "public composable top trim busy flags must be clear after reset release"
      severity failure;

    assert (step_s < STEP_LAST_C) or (config_status_o(afe).offset_busy = '0')
      report "public composable top offset busy flags must be clear after reset release"
      severity failure;

    assert (step_s < STEP_LAST_C) or (config_status_o(afe).ready = '0')
      report "public composable top analog ready flags must stay low when configuration-valid inputs are held low"
      severity failure;
  end generate gen_afe;
end architecture formal;
