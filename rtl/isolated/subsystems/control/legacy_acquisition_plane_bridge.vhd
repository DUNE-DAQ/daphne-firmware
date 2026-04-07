library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_acquisition_plane_bridge is
  generic (
    AFE_COUNT_G : positive range 1 to 5 := 5
  );
  port (
    clock_i                   : in  std_logic;
    reset_i                   : in  std_logic;
    analog_stat_i             : in  analog_status_t;
    timing_stat_i             : in  timing_status_t;
    frontend_align_stat_i     : in  frontend_alignment_status_t;
    frontend_dout_i           : in  array_5x9x16_type;
    frontend_trigger_i        : in  std_logic;
    core_chan_enable_i        : in  std_logic_vector((AFE_COUNT_G * 8) - 1 downto 0);
    afe_comp_enable_i         : in  std_logic_vector((AFE_COUNT_G * 8) - 1 downto 0);
    invert_enable_i           : in  std_logic_vector((AFE_COUNT_G * 8) - 1 downto 0);
    threshold_xc_i            : in  slv28_array_t(0 to (AFE_COUNT_G * 8) - 1);
    adhoc_i                   : in  std_logic_vector(7 downto 0);
    filter_output_selector_i  : in  std_logic_vector(1 downto 0);
    ti_trigger_i              : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr_i         : in  std_logic;
    descriptor_config_i       : in  std_logic_vector(13 downto 0);
    signal_delay_i            : in  std_logic_vector(4 downto 0);
    reset_st_counters_i       : in  std_logic;
    force_trigger_i           : in  std_logic;
    timestamp_i               : in  std_logic_vector(63 downto 0);
    version_i                 : in  std_logic_vector(3 downto 0);
    rd_en_i                   : in  std_logic_array_t(0 to (AFE_COUNT_G * 8) - 1);
    frontend_prereq_o         : out frontend_prereq_t;
    acquisition_ready_o       : out acquisition_readiness_t;
    timing_trigger_o          : out std_logic;
    spy_enable_o              : out std_logic;
    spy_trigger_o             : out std_logic;
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
end entity legacy_acquisition_plane_bridge;

architecture rtl of legacy_acquisition_plane_bridge is
  signal trigger_samples_s       : sample14_array_t(0 to (AFE_COUNT_G * 8) - 1);
  signal trigger_control_s       : trigger_xcorr_control_array_t(0 to (AFE_COUNT_G * 8) - 1);
  signal descriptor_config_s     : std_logic_vector(13 downto 0);
  signal signal_delay_s          : std_logic_vector(4 downto 0);
  signal reset_st_counters_int_s : std_logic;
  signal frontend_prereq_s       : frontend_prereq_t;
  signal acquisition_ready_s     : acquisition_readiness_t;
begin
  control_plane_bridge_inst : entity work.legacy_control_plane_bridge
    generic map (
      CHANNEL_COUNT_G => AFE_COUNT_G * 8
    )
    port map (
      analog_stat_i            => analog_stat_i,
      timing_stat_i            => timing_stat_i,
      frontend_align_stat_i    => frontend_align_stat_i,
      core_chan_enable_i       => core_chan_enable_i,
      afe_comp_enable_i        => afe_comp_enable_i,
      invert_enable_i          => invert_enable_i,
      threshold_xc_i           => threshold_xc_i,
      adhoc_i                  => adhoc_i,
      filter_output_selector_i => filter_output_selector_i,
      ti_trigger_i             => ti_trigger_i,
      ti_trigger_stbr_i        => ti_trigger_stbr_i,
      descriptor_config_i      => descriptor_config_i,
      signal_delay_i           => signal_delay_i,
      reset_st_counters_i      => reset_st_counters_i,
      frontend_prereq_o        => frontend_prereq_s,
      acquisition_ready_o      => acquisition_ready_s,
      trigger_control_o        => trigger_control_s,
      descriptor_config_o      => descriptor_config_s,
      signal_delay_o           => signal_delay_s,
      reset_st_counters_o      => reset_st_counters_int_s
    );

  frontend_prereq_o   <= frontend_prereq_s;
  acquisition_ready_o <= acquisition_ready_s;

  frontend_adapter_inst : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => AFE_COUNT_G
    )
    port map (
      afe_dout_i        => frontend_dout_i,
      trigger_samples_o => trigger_samples_s
    );

  spy_trigger_bridge_inst : entity work.legacy_spy_trigger_bridge
    port map (
      clock_i            => clock_i,
      reset_i            => reset_i,
      readiness_i        => acquisition_ready_s,
      frontend_trigger_i => frontend_trigger_i,
      adhoc_i            => adhoc_i,
      ti_trigger_i       => ti_trigger_i,
      ti_trigger_stbr_i  => ti_trigger_stbr_i,
      timing_trigger_o   => timing_trigger_o,
      spy_enable_o       => spy_enable_o,
      spy_trigger_o      => spy_trigger_o
    );

  selftrigger_fabric_inst : entity work.selftrigger_fabric
    generic map (
      AFE_COUNT_G        => AFE_COUNT_G,
      CHANNELS_PER_AFE_G => 8,
      CHANNEL_ID_BASE_G  => 0
    )
    port map (
      clock_i             => clock_i,
      reset_i             => reset_i,
      reset_st_counters_i => reset_st_counters_int_s,
      timestamp_i         => timestamp_i,
      version_i           => version_i,
      signal_delay_i      => signal_delay_s,
      descriptor_config_i => descriptor_config_s,
      force_trigger_i     => force_trigger_i,
      din_i               => trigger_samples_s,
      trigger_control_i   => trigger_control_s,
      trigger_result_o    => trigger_result_o,
      descriptor_result_o => descriptor_result_o,
      record_count_o      => record_count_o,
      full_count_o        => full_count_o,
      busy_count_o        => busy_count_o,
      trigger_count_o     => trigger_count_o,
      packet_count_o      => packet_count_o,
      delayed_sample_o    => delayed_sample_o,
      ready_o             => ready_o,
      rd_en_i             => rd_en_i,
      dout_o              => dout_o
    );
end architecture rtl;
