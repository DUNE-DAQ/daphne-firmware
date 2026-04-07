library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity legacy_control_plane_bridge is
  generic (
    CHANNEL_COUNT_G : positive := 40
  );
  port (
    analog_stat_i            : in  analog_status_t;
    timing_stat_i            : in  timing_status_t;
    frontend_align_stat_i    : in  frontend_alignment_status_t;
    core_chan_enable_i       : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    afe_comp_enable_i        : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    invert_enable_i          : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    threshold_xc_i           : in  slv28_array_t(0 to CHANNEL_COUNT_G - 1);
    adhoc_i                  : in  std_logic_vector(7 downto 0);
    filter_output_selector_i : in  std_logic_vector(1 downto 0);
    ti_trigger_i             : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr_i        : in  std_logic;
    descriptor_config_i      : in  std_logic_vector(13 downto 0);
    signal_delay_i           : in  std_logic_vector(4 downto 0);
    reset_st_counters_i      : in  std_logic;
    frontend_prereq_o        : out frontend_prereq_t;
    acquisition_ready_o      : out acquisition_readiness_t;
    trigger_control_o        : out trigger_xcorr_control_array_t(0 to CHANNEL_COUNT_G - 1);
    descriptor_config_o      : out std_logic_vector(13 downto 0);
    signal_delay_o           : out std_logic_vector(4 downto 0);
    reset_st_counters_o      : out std_logic
  );
end entity legacy_control_plane_bridge;

architecture rtl of legacy_control_plane_bridge is
  signal timing_ready_s : std_logic;
begin
  timing_ready_s <= timing_stat_i.mmcm0_locked and timing_stat_i.mmcm1_locked;

  frontend_prereq_o.config_ready <= analog_stat_i.config_ready;
  frontend_prereq_o.timing_ready <= timing_ready_s;

  acquisition_ready_o.config_ready    <= analog_stat_i.config_ready;
  acquisition_ready_o.timing_ready    <= timing_ready_s;
  acquisition_ready_o.alignment_ready <= frontend_align_stat_i.alignment_valid;

  trigger_control_adapter_inst : entity work.trigger_control_adapter
    generic map (
      CHANNEL_COUNT_G => CHANNEL_COUNT_G
    )
    port map (
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
      trigger_control_o        => trigger_control_o,
      descriptor_config_o      => descriptor_config_o,
      signal_delay_o           => signal_delay_o,
      reset_st_counters_o      => reset_st_counters_o
    );
end architecture rtl;
