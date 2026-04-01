library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity daphne_composable_top_smoke_tb is
end entity daphne_composable_top_smoke_tb;

architecture tb of daphne_composable_top_smoke_tb is
  constant AFE_COUNT_C      : positive := 1;
  constant CHANNELS_TOTAL_C : natural := AFE_COUNT_C * 8;
  constant CLK_PERIOD_C     : time := 10 ns;

  signal clock_s                : std_logic := '0';
  signal clk500_s               : std_logic := '0';
  signal clk125_s               : std_logic := '0';
  signal trig_in_s              : std_logic := '0';
  signal afe_p_s                : array_5x9_type := (others => (others => '0'));
  signal afe_n_s                : array_5x9_type := (others => (others => '0'));
  signal afe_clk_p_s            : std_logic;
  signal afe_clk_n_s            : std_logic;
  signal frontend_axi_aresetn_s : std_logic := '0';
  signal frontend_axi_awaddr_s  : std_logic_vector(31 downto 0) := (others => '0');
  signal frontend_axi_awprot_s  : std_logic_vector(2 downto 0) := (others => '0');
  signal frontend_axi_awvalid_s : std_logic := '0';
  signal frontend_axi_awready_s : std_logic;
  signal frontend_axi_wdata_s   : std_logic_vector(31 downto 0) := (others => '0');
  signal frontend_axi_wstrb_s   : std_logic_vector(3 downto 0) := (others => '0');
  signal frontend_axi_wvalid_s  : std_logic := '0';
  signal frontend_axi_wready_s  : std_logic;
  signal frontend_axi_bresp_s   : std_logic_vector(1 downto 0);
  signal frontend_axi_bvalid_s  : std_logic;
  signal frontend_axi_bready_s  : std_logic := '0';
  signal frontend_axi_araddr_s  : std_logic_vector(31 downto 0) := (others => '0');
  signal frontend_axi_arprot_s  : std_logic_vector(2 downto 0) := (others => '0');
  signal frontend_axi_arvalid_s : std_logic := '0';
  signal frontend_axi_arready_s : std_logic;
  signal frontend_axi_rdata_s   : std_logic_vector(31 downto 0);
  signal frontend_axi_rresp_s   : std_logic_vector(1 downto 0);
  signal frontend_axi_rvalid_s  : std_logic;
  signal frontend_axi_rready_s  : std_logic := '0';
  signal timing_resetn_s        : std_logic := '0';
  signal timing_ctrl_s          : timing_control_t := TIMING_CONTROL_NULL;
  signal timing_stat_s          : timing_status_t;
  signal timing_timestamp_s     : std_logic_vector(63 downto 0);
  signal timing_sync_s          : std_logic_vector(7 downto 0);
  signal timing_sync_stb_s      : std_logic;
  signal hermes_descriptor_s    : trigger_descriptor_t := TRIGGER_DESCRIPTOR_NULL;
  signal hermes_taken_s         : std_logic;
  signal hermes_status_s        : hermes_boundary_status_t;
  signal config_valid_s         : std_logic_vector(AFE_COUNT_C - 1 downto 0) := (others => '0');
  signal config_cmd_s           : afe_config_command_bank_t(0 to AFE_COUNT_C - 1) := (others => AFE_CONFIG_COMMAND_NULL);
  signal config_status_s        : afe_config_status_bank_t(0 to AFE_COUNT_C - 1);
  signal afe_miso_s             : std_logic_vector(AFE_COUNT_C - 1 downto 0) := (others => '0');
  signal afe_sclk_s             : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal afe_sen_s              : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal afe_mosi_s             : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trim_sclk_s            : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trim_mosi_s            : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trim_ldac_n_s          : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trim_sync_n_s          : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal offset_sclk_s          : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal offset_mosi_s          : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal offset_ldac_n_s        : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal offset_sync_n_s        : std_logic_vector(AFE_COUNT_C - 1 downto 0);
  signal trigger_control_s      : trigger_xcorr_control_array_t(0 to CHANNELS_TOTAL_C - 1) := (others => TRIGGER_XCORR_CONTROL_NULL);
  signal rd_en_s                : std_logic_array_t(0 to CHANNELS_TOTAL_C - 1) := (others => '0');
  signal frontend_dout_s        : array_5x9x16_type;
  signal frontend_trig_s        : std_logic;
  signal trigger_result_s       : trigger_xcorr_result_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal descriptor_result_s    : peak_descriptor_result_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal record_count_s         : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal full_count_s           : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal busy_count_s           : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal trigger_count_s        : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal packet_count_s         : slv64_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal delayed_sample_s       : sample14_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal ready_s                : std_logic_array_t(0 to CHANNELS_TOTAL_C - 1);
  signal dout_s                 : slv72_array_t(0 to CHANNELS_TOTAL_C - 1);
begin
  clock_s  <= not clock_s after CLK_PERIOD_C / 2;
  clk500_s <= not clk500_s after CLK_PERIOD_C / 2;
  clk125_s <= not clk125_s after CLK_PERIOD_C;

  dut : entity work.daphne_composable_top
    generic map (
      AFE_COUNT_G          => AFE_COUNT_C,
      ENABLE_SELFTRIGGER_G => false,
      ENABLE_TIMING_G      => false,
      ENABLE_HERMES_G      => false,
      ENABLE_SPYBUFFER_G   => false
    )
    port map (
      afe_p                 => afe_p_s,
      afe_n                 => afe_n_s,
      afe_clk_p             => afe_clk_p_s,
      afe_clk_n             => afe_clk_n_s,
      clk500                => clk500_s,
      clk125                => clk125_s,
      clock                 => clock_s,
      trig_in               => trig_in_s,
      frontend_axi_aclk     => clock_s,
      frontend_axi_aresetn  => frontend_axi_aresetn_s,
      frontend_axi_awaddr   => frontend_axi_awaddr_s,
      frontend_axi_awprot   => frontend_axi_awprot_s,
      frontend_axi_awvalid  => frontend_axi_awvalid_s,
      frontend_axi_awready  => frontend_axi_awready_s,
      frontend_axi_wdata    => frontend_axi_wdata_s,
      frontend_axi_wstrb    => frontend_axi_wstrb_s,
      frontend_axi_wvalid   => frontend_axi_wvalid_s,
      frontend_axi_wready   => frontend_axi_wready_s,
      frontend_axi_bresp    => frontend_axi_bresp_s,
      frontend_axi_bvalid   => frontend_axi_bvalid_s,
      frontend_axi_bready   => frontend_axi_bready_s,
      frontend_axi_araddr   => frontend_axi_araddr_s,
      frontend_axi_arprot   => frontend_axi_arprot_s,
      frontend_axi_arvalid  => frontend_axi_arvalid_s,
      frontend_axi_arready  => frontend_axi_arready_s,
      frontend_axi_rdata    => frontend_axi_rdata_s,
      frontend_axi_rresp    => frontend_axi_rresp_s,
      frontend_axi_rvalid   => frontend_axi_rvalid_s,
      frontend_axi_rready   => frontend_axi_rready_s,
      timing_clk_axi_i      => clock_s,
      timing_resetn_axi_i   => timing_resetn_s,
      timing_ctrl_i         => timing_ctrl_s,
      timing_stat_o         => timing_stat_s,
      timing_timestamp_o    => timing_timestamp_s,
      timing_sync_o         => timing_sync_s,
      timing_sync_stb_o     => timing_sync_stb_s,
      hermes_descriptor_i   => hermes_descriptor_s,
      hermes_descriptor_taken_o => hermes_taken_s,
      hermes_stat_o         => hermes_status_s,
      config_valid_i        => config_valid_s,
      config_cmd_i          => config_cmd_s,
      config_status_o       => config_status_s,
      afe_miso_i            => afe_miso_s,
      afe_sclk_o            => afe_sclk_s,
      afe_sen_o             => afe_sen_s,
      afe_mosi_o            => afe_mosi_s,
      trim_sclk_o           => trim_sclk_s,
      trim_mosi_o           => trim_mosi_s,
      trim_ldac_n_o         => trim_ldac_n_s,
      trim_sync_n_o         => trim_sync_n_s,
      offset_sclk_o         => offset_sclk_s,
      offset_mosi_o         => offset_mosi_s,
      offset_ldac_n_o       => offset_ldac_n_s,
      offset_sync_n_o       => offset_sync_n_s,
      reset_st_counters_i   => '0',
      force_trigger_i       => '0',
      timestamp_i           => x"0011223344556677",
      version_i             => x"2",
      signal_delay_i        => "00101",
      descriptor_config_i   => (others => '0'),
      trigger_control_i     => trigger_control_s,
      rd_en_i               => rd_en_s,
      frontend_dout_o       => frontend_dout_s,
      frontend_trig_o       => frontend_trig_s,
      trigger_result_o      => trigger_result_s,
      descriptor_result_o   => descriptor_result_s,
      record_count_o        => record_count_s,
      full_count_o          => full_count_s,
      busy_count_o          => busy_count_s,
      trigger_count_o       => trigger_count_s,
      packet_count_o        => packet_count_s,
      delayed_sample_o      => delayed_sample_s,
      ready_o               => ready_s,
      dout_o                => dout_s
    );

  stimulus : process
  begin
    afe_p_s(0)(0) <= '1';
    afe_n_s(0)(0) <= '0';
    afe_p_s(0)(1) <= '0';
    afe_n_s(0)(1) <= '1';
    trig_in_s <= '1';

    wait for 4 * CLK_PERIOD_C;
    frontend_axi_aresetn_s <= '1';
    timing_resetn_s <= '1';
    wait for 6 * CLK_PERIOD_C;

    assert frontend_dout_s(0)(0) = x"FFFE"
      report "Public top should expose the validate frontend-island pattern for lane 0"
      severity failure;
    assert frontend_dout_s(0)(1) = x"0001"
      report "Public top should expose the validate frontend-island pattern for lane 1"
      severity failure;
    assert frontend_trig_s = '1'
      report "Public top should pass the validate frontend trigger through unchanged"
      severity failure;

    assert timing_stat_s = TIMING_STATUS_NULL
      report "Disabled timing path should stay at the null status in the public top"
      severity failure;
    assert hermes_taken_s = '0'
      report "Disabled Hermes path should ignore descriptors in the public top"
      severity failure;
    assert hermes_status_s = HERMES_BOUNDARY_STATUS_NULL
      report "Disabled Hermes path should stay at the null status in the public top"
      severity failure;
    assert trigger_result_s(0) = TRIGGER_XCORR_RESULT_NULL
      report "Disabled self-trigger path should keep the first trigger result null in the public top"
      severity failure;
    assert dout_s(CHANNELS_TOTAL_C - 1) = (dout_s(CHANNELS_TOTAL_C - 1)'range => '0')
      report "Disabled self-trigger path should keep emitted records zeroed in the public top"
      severity failure;

    assert false report "daphne_composable_top_smoke_tb completed successfully" severity note;
    wait;
  end process;
end architecture tb;
