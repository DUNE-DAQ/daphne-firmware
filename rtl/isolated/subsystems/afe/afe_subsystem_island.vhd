library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity afe_subsystem_island is
  generic (
    CHANNELS_PER_AFE_G : positive := 8;
    CHANNEL_ID_BASE_G  : natural  := 0
  );
  port (
    clock_i             : in  std_logic;
    reset_i             : in  std_logic;
    reset_st_counters_i : in  std_logic;
    config_valid_i      : in  std_logic;
    config_cmd_i        : in  afe_config_command_t;
    config_status_o     : out afe_config_status_t;
    afe_miso_i          : in  std_logic;
    afe_sclk_o          : out std_logic;
    afe_sen_o           : out std_logic;
    afe_mosi_o          : out std_logic;
    trim_sclk_o         : out std_logic;
    trim_mosi_o         : out std_logic;
    trim_ldac_n_o       : out std_logic;
    trim_sync_n_o       : out std_logic;
    offset_sclk_o       : out std_logic;
    offset_mosi_o       : out std_logic;
    offset_ldac_n_o     : out std_logic;
    offset_sync_n_o     : out std_logic;
    timestamp_i         : in  std_logic_vector(63 downto 0);
    version_i           : in  std_logic_vector(3 downto 0);
    signal_delay_i      : in  std_logic_vector(4 downto 0);
    descriptor_config_i : in  std_logic_vector(13 downto 0);
    force_trigger_i     : in  std_logic;
    din_i               : in  sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
    trigger_control_i   : in  trigger_xcorr_control_array_t(0 to CHANNELS_PER_AFE_G - 1);
    trigger_result_o    : out trigger_xcorr_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
    descriptor_result_o : out peak_descriptor_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
    record_count_o      : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    full_count_o        : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    busy_count_o        : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    trigger_count_o     : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    packet_count_o      : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    delayed_sample_o    : out sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
    ready_o             : out std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    rd_en_i             : in  std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    dout_o              : out slv72_array_t(0 to CHANNELS_PER_AFE_G - 1)
  );
end entity afe_subsystem_island;

architecture rtl of afe_subsystem_island is
begin
  analog_island_inst : entity work.afe_analog_island
    port map (
      clock_i         => clock_i,
      reset_i         => reset_i,
      config_valid_i  => config_valid_i,
      cmd_i           => config_cmd_i,
      status_o        => config_status_o,
      afe_miso_i      => afe_miso_i,
      afe_sclk_o      => afe_sclk_o,
      afe_sen_o       => afe_sen_o,
      afe_mosi_o      => afe_mosi_o,
      trim_sclk_o     => trim_sclk_o,
      trim_mosi_o     => trim_mosi_o,
      trim_ldac_n_o   => trim_ldac_n_o,
      trim_sync_n_o   => trim_sync_n_o,
      offset_sclk_o   => offset_sclk_o,
      offset_mosi_o   => offset_mosi_o,
      offset_ldac_n_o => offset_ldac_n_o,
      offset_sync_n_o => offset_sync_n_o
    );

  selftrigger_island_inst : entity work.afe_selftrigger_island
    generic map (
      CHANNELS_PER_AFE_G => CHANNELS_PER_AFE_G,
      CHANNEL_ID_BASE_G  => CHANNEL_ID_BASE_G
    )
    port map (
      clock_i             => clock_i,
      reset_i             => reset_i,
      reset_st_counters_i => reset_st_counters_i,
      timestamp_i         => timestamp_i,
      version_i           => version_i,
      signal_delay_i      => signal_delay_i,
      descriptor_config_i => descriptor_config_i,
      force_trigger_i     => force_trigger_i,
      din_i               => din_i,
      trigger_control_i   => trigger_control_i,
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
