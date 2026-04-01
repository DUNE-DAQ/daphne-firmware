library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity daphne_composable_frontend_shell is
  generic (
    AFE_COUNT_G          : positive range 1 to 5 := 5;
    ENABLE_SELFTRIGGER_G : boolean := true;
    ENABLE_TIMING_G      : boolean := true;
    ENABLE_HERMES_G      : boolean := true;
    ENABLE_SPYBUFFER_G   : boolean := true
  );
  port (
    clock_i                   : in  std_logic;
    frontend_resetn_i         : in  std_logic;
    timing_clk_axi_i          : in  std_logic;
    timing_resetn_axi_i       : in  std_logic;
    timing_ctrl_i             : in  timing_control_t;
    timing_stat_o             : out timing_status_t;
    timing_timestamp_o        : out std_logic_vector(63 downto 0);
    timing_sync_o             : out std_logic_vector(7 downto 0);
    timing_sync_stb_o         : out std_logic;
    hermes_descriptor_i       : in  trigger_descriptor_t;
    hermes_descriptor_taken_o : out std_logic;
    hermes_stat_o             : out hermes_boundary_status_t;
    config_valid_i            : in  std_logic_vector(AFE_COUNT_G - 1 downto 0);
    config_cmd_i              : in  afe_config_command_bank_t(0 to AFE_COUNT_G - 1);
    config_status_o           : out afe_config_status_bank_t(0 to AFE_COUNT_G - 1);
    afe_miso_i                : in  std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_sclk_o                : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_sen_o                 : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_mosi_o                : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_sclk_o               : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_mosi_o               : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_ldac_n_o             : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_sync_n_o             : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_sclk_o             : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_mosi_o             : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_ldac_n_o           : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_sync_n_o           : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    reset_st_counters_i       : in  std_logic;
    force_trigger_i           : in  std_logic;
    timestamp_i               : in  std_logic_vector(63 downto 0);
    version_i                 : in  std_logic_vector(3 downto 0);
    signal_delay_i            : in  std_logic_vector(4 downto 0);
    descriptor_config_i       : in  std_logic_vector(13 downto 0);
    frontend_dout_i           : in  array_5x9x16_type;
    frontend_trig_i           : in  std_logic;
    trigger_control_i         : in  trigger_xcorr_control_array_t(0 to (AFE_COUNT_G * 8) - 1);
    rd_en_i                   : in  std_logic_array_t(0 to (AFE_COUNT_G * 8) - 1);
    frontend_dout_o           : out array_5x9x16_type;
    frontend_trig_o           : out std_logic;
    trigger_result_o          : out trigger_xcorr_result_array_t(0 to (AFE_COUNT_G * 8) - 1);
    descriptor_result_o       : out peak_descriptor_result_array_t(0 to (AFE_COUNT_G * 8) - 1);
    record_count_o            : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    full_count_o              : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    busy_count_o              : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    trigger_count_o           : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    packet_count_o            : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    delayed_sample_o          : out sample14_array_t(0 to (AFE_COUNT_G * 8) - 1);
    ready_o                   : out std_logic_array_t(0 to (AFE_COUNT_G * 8) - 1);
    dout_o                    : out slv72_array_t(0 to (AFE_COUNT_G * 8) - 1)
  );
end entity daphne_composable_frontend_shell;

architecture rtl of daphne_composable_frontend_shell is
  signal trigger_samples_s : sample14_array_t(0 to (AFE_COUNT_G * 8) - 1);
begin
  frontend_to_trigger_inst : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => AFE_COUNT_G
    )
    port map (
      afe_dout_i        => frontend_dout_i,
      trigger_samples_o => trigger_samples_s
    );

  frontend_dout_o <= frontend_dout_i;
  frontend_trig_o <= frontend_trig_i;

  core_top_inst : entity work.daphne_composable_core_top
    generic map (
      AFE_COUNT_G          => AFE_COUNT_G,
      ENABLE_SELFTRIGGER_G => ENABLE_SELFTRIGGER_G,
      ENABLE_TIMING_G      => ENABLE_TIMING_G,
      ENABLE_HERMES_G      => ENABLE_HERMES_G
    )
    port map (
      clock_i                   => clock_i,
      reset_i                   => not frontend_resetn_i,
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
      config_valid_i            => config_valid_i,
      config_cmd_i              => config_cmd_i,
      config_status_o           => config_status_o,
      afe_miso_i                => afe_miso_i,
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
      reset_st_counters_i       => reset_st_counters_i,
      force_trigger_i           => force_trigger_i,
      timestamp_i               => timestamp_i,
      version_i                 => version_i,
      signal_delay_i            => signal_delay_i,
      descriptor_config_i       => descriptor_config_i,
      din_i                     => trigger_samples_s,
      trigger_control_i         => trigger_control_i,
      rd_en_i                   => rd_en_i,
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

  -- ENABLE_SPYBUFFER_G remains at this shell level so the public composable top
  -- can grow to own the future frame/spybuffer plumbing without changing its
  -- generic contract. The current shell validates the frontend-to-trigger seam
  -- and delegates timing/Hermes/AFE ownership to the vendor-neutral core top.
end architecture rtl;
