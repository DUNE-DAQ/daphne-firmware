library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity afe_subsystem_fabric is
  generic (
    AFE_COUNT_G        : positive range 1 to 5 := 5;
    CHANNELS_PER_AFE_G : positive := 8;
    CHANNEL_ID_BASE_G  : natural  := 0;
    ENABLE_SELFTRIGGER_G : boolean := true
  );
  port (
    clock_i             : in  std_logic;
    reset_i             : in  std_logic;
    reset_st_counters_i : in  std_logic;
    config_valid_i      : in  std_logic_vector(AFE_COUNT_G - 1 downto 0);
    config_cmd_i        : in  afe_config_command_bank_t(0 to AFE_COUNT_G - 1);
    config_status_o     : out afe_config_status_bank_t(0 to AFE_COUNT_G - 1);
    afe_miso_i          : in  std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_sclk_o          : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_sen_o           : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_mosi_o          : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_sclk_o         : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_mosi_o         : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_ldac_n_o       : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_sync_n_o       : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_sclk_o       : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_mosi_o       : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_ldac_n_o     : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_sync_n_o     : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    timestamp_i         : in  std_logic_vector(63 downto 0);
    version_i           : in  std_logic_vector(3 downto 0);
    signal_delay_i      : in  std_logic_vector(4 downto 0);
    descriptor_config_i : in  std_logic_vector(13 downto 0);
    force_trigger_i     : in  std_logic;
    din_i               : in  sample14_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    trigger_control_i   : in  trigger_xcorr_control_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    trigger_result_o    : out trigger_xcorr_result_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    descriptor_result_o : out peak_descriptor_result_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    record_count_o      : out slv64_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    full_count_o        : out slv64_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    busy_count_o        : out slv64_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    trigger_count_o     : out slv64_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    packet_count_o      : out slv64_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    delayed_sample_o    : out sample14_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    ready_o             : out std_logic_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    rd_en_i             : in  std_logic_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1);
    dout_o              : out slv72_array_t(0 to (AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1)
  );
end entity afe_subsystem_fabric;

architecture rtl of afe_subsystem_fabric is
begin
  gen_afe : for afe_idx in 0 to AFE_COUNT_G - 1 generate
    constant CHANNEL_BASE_C : natural := afe_idx * CHANNELS_PER_AFE_G;
    signal din_afe_s               : sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal trigger_control_afe_s   : trigger_xcorr_control_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal trigger_result_afe_s    : trigger_xcorr_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal descriptor_result_afe_s : peak_descriptor_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal record_count_afe_s      : slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal full_count_afe_s        : slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal busy_count_afe_s        : slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal trigger_count_afe_s     : slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal packet_count_afe_s      : slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal delayed_sample_afe_s    : sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal ready_afe_s             : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal rd_en_afe_s             : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    signal dout_afe_s              : slv72_array_t(0 to CHANNELS_PER_AFE_G - 1);
  begin
    gen_channel : for ch_idx in 0 to CHANNELS_PER_AFE_G - 1 generate
    begin
      din_afe_s(ch_idx) <= din_i(CHANNEL_BASE_C + ch_idx);
      trigger_control_afe_s(ch_idx) <= trigger_control_i(CHANNEL_BASE_C + ch_idx);
      rd_en_afe_s(ch_idx) <= rd_en_i(CHANNEL_BASE_C + ch_idx);

      trigger_result_o(CHANNEL_BASE_C + ch_idx) <= trigger_result_afe_s(ch_idx);
      descriptor_result_o(CHANNEL_BASE_C + ch_idx) <= descriptor_result_afe_s(ch_idx);
      record_count_o(CHANNEL_BASE_C + ch_idx) <= record_count_afe_s(ch_idx);
      full_count_o(CHANNEL_BASE_C + ch_idx) <= full_count_afe_s(ch_idx);
      busy_count_o(CHANNEL_BASE_C + ch_idx) <= busy_count_afe_s(ch_idx);
      trigger_count_o(CHANNEL_BASE_C + ch_idx) <= trigger_count_afe_s(ch_idx);
      packet_count_o(CHANNEL_BASE_C + ch_idx) <= packet_count_afe_s(ch_idx);
      delayed_sample_o(CHANNEL_BASE_C + ch_idx) <= delayed_sample_afe_s(ch_idx);
      ready_o(CHANNEL_BASE_C + ch_idx) <= ready_afe_s(ch_idx);
      dout_o(CHANNEL_BASE_C + ch_idx) <= dout_afe_s(ch_idx);
    end generate gen_channel;

    afe_island_inst : entity work.afe_subsystem_island
      generic map (
        CHANNELS_PER_AFE_G => CHANNELS_PER_AFE_G,
        CHANNEL_ID_BASE_G  => CHANNEL_ID_BASE_G + CHANNEL_BASE_C,
        ENABLE_SELFTRIGGER_G => ENABLE_SELFTRIGGER_G
      )
      port map (
        clock_i             => clock_i,
        reset_i             => reset_i,
        reset_st_counters_i => reset_st_counters_i,
        config_valid_i      => config_valid_i(afe_idx),
        config_cmd_i        => config_cmd_i(afe_idx),
        config_status_o     => config_status_o(afe_idx),
        afe_miso_i          => afe_miso_i(afe_idx),
        afe_sclk_o          => afe_sclk_o(afe_idx),
        afe_sen_o           => afe_sen_o(afe_idx),
        afe_mosi_o          => afe_mosi_o(afe_idx),
        trim_sclk_o         => trim_sclk_o(afe_idx),
        trim_mosi_o         => trim_mosi_o(afe_idx),
        trim_ldac_n_o       => trim_ldac_n_o(afe_idx),
        trim_sync_n_o       => trim_sync_n_o(afe_idx),
        offset_sclk_o       => offset_sclk_o(afe_idx),
        offset_mosi_o       => offset_mosi_o(afe_idx),
        offset_ldac_n_o     => offset_ldac_n_o(afe_idx),
        offset_sync_n_o     => offset_sync_n_o(afe_idx),
        timestamp_i         => timestamp_i,
        version_i           => version_i,
        signal_delay_i      => signal_delay_i,
        descriptor_config_i => descriptor_config_i,
        force_trigger_i     => force_trigger_i,
        din_i               => din_afe_s,
        trigger_control_i   => trigger_control_afe_s,
        trigger_result_o    => trigger_result_afe_s,
        descriptor_result_o => descriptor_result_afe_s,
        record_count_o      => record_count_afe_s,
        full_count_o        => full_count_afe_s,
        busy_count_o        => busy_count_afe_s,
        trigger_count_o     => trigger_count_afe_s,
        packet_count_o      => packet_count_afe_s,
        delayed_sample_o    => delayed_sample_afe_s,
        ready_o             => ready_afe_s,
        rd_en_i             => rd_en_afe_s,
        dout_o              => dout_afe_s
      );
  end generate gen_afe;
end architecture rtl;
