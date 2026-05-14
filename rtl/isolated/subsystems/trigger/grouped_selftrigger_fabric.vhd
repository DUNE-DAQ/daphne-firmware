library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;
use work.grouped_transport_pkg.all;

entity grouped_selftrigger_fabric is
  generic (
    AFE_COUNT_G             : positive range 1 to 5 := 5;
    CHANNELS_PER_AFE_G      : positive := 8;
    CHANNEL_ID_BASE_G       : natural  := 0;
    CHANNELS_PER_PRODUCER_G : positive := 8;
    ENABLE_AFE_COMPENSATOR_G: boolean  := false;
    ENABLE_INVERT_CONTROL_G : boolean  := false;
    FIXED_CFD_G             : boolean  := true;
    USE_COMPACT_DESCRIPTOR_G : boolean  := true;
    TRIGGER_LATENCY_G       : natural  := 4;
    RING_MEMORY_PRIMITIVE_G : string   := "ultra"
  );
  port (
    clock_i             : in  std_logic;
    reset_i             : in  std_logic;
    reset_st_counters_i : in  std_logic;
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
    grouped_readout_ready_i : in  std_logic_vector(
      0 to ((AFE_COUNT_G * CHANNELS_PER_AFE_G) / CHANNELS_PER_PRODUCER_G) - 1
    );
    grouped_readout_o   : out grouped_source_stream_array_t(
      0 to ((AFE_COUNT_G * CHANNELS_PER_AFE_G) / CHANNELS_PER_PRODUCER_G) - 1
    )
  );
end entity grouped_selftrigger_fabric;

architecture rtl of grouped_selftrigger_fabric is
  constant PRODUCERS_PER_AFE_C : positive := CHANNELS_PER_AFE_G / CHANNELS_PER_PRODUCER_G;
begin
  assert PRODUCERS_PER_AFE_C * CHANNELS_PER_PRODUCER_G = CHANNELS_PER_AFE_G
    report "grouped_selftrigger_fabric requires CHANNELS_PER_AFE_G to be divisible by CHANNELS_PER_PRODUCER_G"
    severity failure;

  gen_afe : for afe_idx in 0 to AFE_COUNT_G - 1 generate
    constant CHANNEL_BASE_C  : natural := afe_idx * CHANNELS_PER_AFE_G;
    constant PRODUCER_BASE_C : natural := afe_idx * PRODUCERS_PER_AFE_C;
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
    signal grouped_ready_afe_s      : std_logic_vector(0 to PRODUCERS_PER_AFE_C - 1);
    signal grouped_readout_afe_s   : grouped_source_stream_array_t(0 to PRODUCERS_PER_AFE_C - 1);
  begin
    gen_channel : for ch_idx in 0 to CHANNELS_PER_AFE_G - 1 generate
    begin
      din_afe_s(ch_idx)             <= din_i(CHANNEL_BASE_C + ch_idx);
      trigger_control_afe_s(ch_idx) <= trigger_control_i(CHANNEL_BASE_C + ch_idx);

      trigger_result_o(CHANNEL_BASE_C + ch_idx)    <= trigger_result_afe_s(ch_idx);
      descriptor_result_o(CHANNEL_BASE_C + ch_idx) <= descriptor_result_afe_s(ch_idx);
      record_count_o(CHANNEL_BASE_C + ch_idx)      <= record_count_afe_s(ch_idx);
      full_count_o(CHANNEL_BASE_C + ch_idx)        <= full_count_afe_s(ch_idx);
      busy_count_o(CHANNEL_BASE_C + ch_idx)        <= busy_count_afe_s(ch_idx);
      trigger_count_o(CHANNEL_BASE_C + ch_idx)     <= trigger_count_afe_s(ch_idx);
      packet_count_o(CHANNEL_BASE_C + ch_idx)      <= packet_count_afe_s(ch_idx);
      delayed_sample_o(CHANNEL_BASE_C + ch_idx)    <= delayed_sample_afe_s(ch_idx);
    end generate gen_channel;

    gen_producer : for producer_idx in 0 to PRODUCERS_PER_AFE_C - 1 generate
    begin
      grouped_ready_afe_s(producer_idx) <= grouped_readout_ready_i(PRODUCER_BASE_C + producer_idx);
      grouped_readout_o(PRODUCER_BASE_C + producer_idx) <= grouped_readout_afe_s(producer_idx);
    end generate gen_producer;

    afe_grouped_selftrigger_island_inst : entity work.afe_grouped_selftrigger_island
      generic map (
        CHANNELS_PER_AFE_G      => CHANNELS_PER_AFE_G,
        CHANNEL_ID_BASE_G       => CHANNEL_ID_BASE_G + CHANNEL_BASE_C,
        CHANNELS_PER_PRODUCER_G => CHANNELS_PER_PRODUCER_G,
        ENABLE_AFE_COMPENSATOR_G=> ENABLE_AFE_COMPENSATOR_G,
        ENABLE_INVERT_CONTROL_G => ENABLE_INVERT_CONTROL_G,
        FIXED_CFD_G             => FIXED_CFD_G,
        USE_COMPACT_DESCRIPTOR_G => USE_COMPACT_DESCRIPTOR_G,
        TRIGGER_LATENCY_G       => TRIGGER_LATENCY_G,
        RING_MEMORY_PRIMITIVE_G => RING_MEMORY_PRIMITIVE_G
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
        grouped_readout_ready_i => grouped_ready_afe_s,
        grouped_readout_o   => grouped_readout_afe_s
      );
  end generate gen_afe;
end architecture rtl;
