library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity afe_selftrigger_island is
  generic (
    CHANNELS_PER_AFE_G : positive := 8;
    CHANNEL_ID_BASE_G  : natural  := 0
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
    afe_ready_o         : out std_logic;
    afe_rd_en_i         : in  std_logic;
    afe_dout_o          : out std_logic_vector(71 downto 0);
    ready_o             : out std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    rd_en_i             : in  std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    dout_o              : out slv72_array_t(0 to CHANNELS_PER_AFE_G - 1)
  );
end entity afe_selftrigger_island;

architecture rtl of afe_selftrigger_island is
  signal descriptor_control_s : peak_descriptor_control_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal trigger_result_s     : trigger_xcorr_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal descriptor_result_s  : peak_descriptor_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal descriptor_trailer_s : peak_descriptor_trailer_bank_t(0 to CHANNELS_PER_AFE_G - 1);
  signal frame_match_s        : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal source_desc_valid_s  : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal source_desc_s        : stc3_frame_descriptor_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal source_trailer_s     : peak_descriptor_trailer_bank_t(0 to CHANNELS_PER_AFE_G - 1);
  signal source_desc_taken_s  : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal source_ring_addr_s   : slv11_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal source_ring_dout_s   : sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
  signal serializer_ready_s   : std_logic;
  signal serializer_dout_s    : std_logic_vector(71 downto 0);
begin
  trigger_bank_inst : entity work.afe_trigger_bank
    generic map (
      CHANNEL_COUNT_G => CHANNELS_PER_AFE_G
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
    descriptor_control_s(idx).config <= descriptor_config_i;
    descriptor_control_s(idx).frame_match <= frame_match_s(idx);

    frame_source_inst : entity work.stc3_frame_source
      port map (
        ch_id_i             => CHANNEL_ID_C,
        version_i           => version_i,
        threshold_xc_i      => trigger_control_i(idx).threshold_xc,
        signal_delay_i      => signal_delay_i,
        clock_i             => clock_i,
        reset_i             => reset_i,
        reset_st_counters_i => reset_st_counters_i,
        enable_i            => trigger_result_s(idx).enabled,
        force_trigger_i     => force_trigger_i,
        timestamp_i         => timestamp_i,
        din_i               => din_i(idx),
        trigger_i           => trigger_result_s(idx),
        trailer_capture_i   => descriptor_result_s(idx).trailer_available,
        trailer_i           => descriptor_trailer_s(idx),
        frame_match_o       => frame_match_s(idx),
        record_count_o      => record_count_o(idx),
        full_count_o        => full_count_o(idx),
        busy_count_o        => busy_count_o(idx),
        spacing_reject_count_o => open,
        queue_reject_count_o   => open,
        ring_reject_count_o    => open,
        output_reject_count_o  => open,
        trigger_count_o     => trigger_count_o(idx),
        packet_count_o      => packet_count_o(idx),
        delayed_sample_o    => delayed_sample_o(idx),
        desc_valid_o        => source_desc_valid_s(idx),
        desc_o              => source_desc_s(idx),
        desc_trailer_o      => source_trailer_s(idx),
        desc_taken_i        => source_desc_taken_s(idx),
        ring_rd_addr_i      => source_ring_addr_s(idx),
        ring_dout_o         => source_ring_dout_s(idx)
      );
  end generate gen_channel;

  serializer_inst : entity work.afe_stc3_stream_serializer
    generic map (
      CHANNELS_PER_AFE_G => CHANNELS_PER_AFE_G
    )
    port map (
      clock_i             => clock_i,
      reset_i             => reset_i,
      reset_st_counters_i => reset_st_counters_i,
      desc_valid_i        => source_desc_valid_s,
      desc_i              => source_desc_s,
      desc_trailer_i      => source_trailer_s,
      desc_taken_o        => source_desc_taken_s,
      ring_rd_addr_o      => source_ring_addr_s,
      ring_dout_i         => source_ring_dout_s,
      ready_o             => serializer_ready_s,
      rd_en_i             => afe_rd_en_i or rd_en_i(0),
      dout_o              => serializer_dout_s
    );

  afe_ready_o <= serializer_ready_s;
  afe_dout_o  <= serializer_dout_s;
  ready_o(0) <= serializer_ready_s;
  dout_o(0)  <= serializer_dout_s;

  gen_transport_passthrough_off : for idx in 1 to CHANNELS_PER_AFE_G - 1 generate
  begin
    ready_o(idx) <= '0';
    dout_o(idx)  <= (others => '0');
  end generate gen_transport_passthrough_off;

  trigger_result_o    <= trigger_result_s;
  descriptor_result_o <= descriptor_result_s;
end architecture rtl;
