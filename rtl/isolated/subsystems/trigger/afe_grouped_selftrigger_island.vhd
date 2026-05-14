library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;
use work.grouped_transport_pkg.all;

entity afe_grouped_selftrigger_island is
  generic (
    CHANNELS_PER_AFE_G      : positive := 8;
    CHANNEL_ID_BASE_G       : natural  := 0;
    CHANNELS_PER_PRODUCER_G : positive := 8;
    ENABLE_AFE_COMPENSATOR_G: boolean  := true;
    ENABLE_INVERT_CONTROL_G : boolean  := true;
    FIXED_CFD_G             : boolean  := false;
    USE_COMPACT_DESCRIPTOR_G : boolean  := true;
    TRIGGER_LATENCY_G       : natural  := 64;
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
    grouped_readout_ready_i : in  std_logic_vector(
      0 to (CHANNELS_PER_AFE_G / CHANNELS_PER_PRODUCER_G) - 1
    );
    grouped_readout_o   : out grouped_source_stream_array_t(
      0 to (CHANNELS_PER_AFE_G / CHANNELS_PER_PRODUCER_G) - 1
    )
  );
end entity afe_grouped_selftrigger_island;

architecture rtl of afe_grouped_selftrigger_island is
  constant PRODUCER_COUNT_C : positive := CHANNELS_PER_AFE_G / CHANNELS_PER_PRODUCER_G;

  signal descriptor_control_s : peak_descriptor_control_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal trigger_result_s     : trigger_xcorr_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal descriptor_result_s  : peak_descriptor_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal descriptor_trailer_s : peak_descriptor_trailer_bank_t(0 to CHANNELS_PER_AFE_G - 1);
  signal frame_match_s        : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal desc_valid_s         : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal desc_s               : stc3_frame_descriptor_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal desc_taken_s         : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal desc_released_s      : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal desc_trailer_s       : peak_descriptor_trailer_bank_t(0 to CHANNELS_PER_AFE_G - 1);
  signal ring_rd_addr_s       : slv11_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal ring_dout_s          : sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal serializer_ready_s   : std_logic_array_t(0 to PRODUCER_COUNT_C - 1);
  signal serializer_rd_en_s   : std_logic_array_t(0 to PRODUCER_COUNT_C - 1);
  signal serializer_dout_s    : slv72_array_t(0 to PRODUCER_COUNT_C - 1);
begin
  assert PRODUCER_COUNT_C * CHANNELS_PER_PRODUCER_G = CHANNELS_PER_AFE_G
    report "afe_grouped_selftrigger_island requires CHANNELS_PER_AFE_G to be divisible by CHANNELS_PER_PRODUCER_G"
    severity failure;

  trigger_bank_inst : entity work.afe_trigger_bank
    generic map (
      CHANNEL_COUNT_G          => CHANNELS_PER_AFE_G,
      ENABLE_AFE_COMPENSATOR_G => ENABLE_AFE_COMPENSATOR_G,
      ENABLE_INVERT_CONTROL_G  => ENABLE_INVERT_CONTROL_G,
      FIXED_CFD_G              => FIXED_CFD_G,
      USE_COMPACT_DESCRIPTOR_G => USE_COMPACT_DESCRIPTOR_G,
      TRIGGER_LATENCY_G        => TRIGGER_LATENCY_G
    )
    port map (
      clock_i              => clock_i,
      reset_i              => reset_i,
      timestamp_i          => timestamp_i,
      din_i                => din_i,
      trigger_control_i    => trigger_control_i,
      descriptor_control_i => descriptor_control_s,
      trigger_result_o     => trigger_result_s,
      descriptor_result_o  => descriptor_result_s,
      descriptor_trailer_o => descriptor_trailer_s
    );

  gen_channel : for idx in 0 to CHANNELS_PER_AFE_G - 1 generate
    constant CHANNEL_ID_C : std_logic_vector(7 downto 0) :=
      std_logic_vector(to_unsigned(CHANNEL_ID_BASE_G + idx, 8));
  begin
    descriptor_control_s(idx).config      <= descriptor_config_i;
    descriptor_control_s(idx).frame_match <= frame_match_s(idx);

    frame_source_inst : entity work.stc3_frame_source
      generic map (
        RING_MEMORY_PRIMITIVE_G => RING_MEMORY_PRIMITIVE_G
      )
      port map (
        ch_id_i                => CHANNEL_ID_C,
        version_i              => version_i,
        threshold_xc_i         => trigger_control_i(idx).threshold_xc,
        signal_delay_i         => signal_delay_i,
        clock_i                => clock_i,
        reset_i                => reset_i,
        reset_st_counters_i    => reset_st_counters_i,
        enable_i               => trigger_result_s(idx).enabled,
        force_trigger_i        => force_trigger_i,
        timestamp_i            => timestamp_i,
        din_i                  => din_i(idx),
        trigger_i              => trigger_result_s(idx),
        trailer_capture_i      => descriptor_result_s(idx).trailer_available,
        trailer_i              => descriptor_trailer_s(idx),
        frame_match_o          => frame_match_s(idx),
        record_count_o         => record_count_o(idx),
        full_count_o           => full_count_o(idx),
        busy_count_o           => busy_count_o(idx),
        spacing_reject_count_o => open,
        queue_reject_count_o   => open,
        ring_reject_count_o    => open,
        output_reject_count_o  => open,
        trigger_count_o        => trigger_count_o(idx),
        packet_count_o         => packet_count_o(idx),
        delayed_sample_o       => delayed_sample_o(idx),
        desc_valid_o           => desc_valid_s(idx),
        desc_o                 => desc_s(idx),
        desc_trailer_o         => desc_trailer_s(idx),
        desc_taken_i           => desc_taken_s(idx),
        desc_released_i        => desc_released_s(idx),
        ring_rd_addr_i         => ring_rd_addr_s(idx),
        ring_dout_o            => ring_dout_s(idx)
      );
  end generate gen_channel;

  gen_producer : for producer_idx in 0 to PRODUCER_COUNT_C - 1 generate
    constant CHANNEL_BASE_C : natural := producer_idx * CHANNELS_PER_PRODUCER_G;
  begin
    grouped_serializer_inst : entity work.afe_stc3_stream_serializer
      generic map (
        CHANNELS_PER_AFE_G => CHANNELS_PER_PRODUCER_G
      )
      port map (
        clock_i             => clock_i,
        reset_i             => reset_i,
        reset_st_counters_i => reset_st_counters_i,
        desc_valid_i        => desc_valid_s(CHANNEL_BASE_C to CHANNEL_BASE_C + CHANNELS_PER_PRODUCER_G - 1),
        desc_i              => desc_s(CHANNEL_BASE_C to CHANNEL_BASE_C + CHANNELS_PER_PRODUCER_G - 1),
        desc_trailer_i      => desc_trailer_s(CHANNEL_BASE_C to CHANNEL_BASE_C + CHANNELS_PER_PRODUCER_G - 1),
        desc_taken_o        => desc_taken_s(CHANNEL_BASE_C to CHANNEL_BASE_C + CHANNELS_PER_PRODUCER_G - 1),
        desc_released_o     => desc_released_s(CHANNEL_BASE_C to CHANNEL_BASE_C + CHANNELS_PER_PRODUCER_G - 1),
        ring_rd_addr_o      => ring_rd_addr_s(CHANNEL_BASE_C to CHANNEL_BASE_C + CHANNELS_PER_PRODUCER_G - 1),
        ring_dout_i         => ring_dout_s(CHANNEL_BASE_C to CHANNEL_BASE_C + CHANNELS_PER_PRODUCER_G - 1),
        ready_o             => serializer_ready_s(producer_idx),
        rd_en_i             => serializer_rd_en_s(producer_idx),
        dout_o              => serializer_dout_s(producer_idx)
      );

    serializer_rd_en_s(producer_idx) <= serializer_ready_s(producer_idx) and
                                        grouped_readout_ready_i(producer_idx);

    grouped_readout_o(producer_idx).data  <= serializer_dout_s(producer_idx)(63 downto 0);
    grouped_readout_o(producer_idx).valid <= serializer_ready_s(producer_idx);
    grouped_readout_o(producer_idx).last  <= '1'
      when (serializer_ready_s(producer_idx) = '1' and serializer_dout_s(producer_idx)(71 downto 64) = X"ED")
      else '0';
  end generate gen_producer;

  trigger_result_o    <= trigger_result_s;
  descriptor_result_o <= descriptor_result_s;
end architecture rtl;
