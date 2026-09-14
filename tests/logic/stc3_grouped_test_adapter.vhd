library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.daphne_subsystem_pkg.all;
use work.grouped_frame_pkg.all;

entity stc3_grouped_test_adapter is
  port (
    ch_id_i                  : in  std_logic_vector(7 downto 0);
    version_i                : in  std_logic_vector(3 downto 0);
    threshold_xc_i           : in  std_logic_vector(27 downto 0);
    signal_delay_i           : in  std_logic_vector(4 downto 0);
    clock_i                  : in  std_logic;
    reset_i                  : in  std_logic;
    reset_st_counters_i      : in  std_logic;
    enable_i                 : in  std_logic;
    force_trigger_i          : in  std_logic;
    force_calibration_tag_i  : in  std_logic_vector(1 downto 0);
    timestamp_i              : in  std_logic_vector(63 downto 0);
    din_i                    : in  std_logic_vector(13 downto 0);
    trigger_i                : in  trigger_xcorr_result_t;
    continuation_enable_i    : in std_logic := '1';
    positive_pulse_i         : in std_logic := '0';
    activity_threshold_i     : in std_logic_vector(13 downto 0) := "00000001000000";
    quiet_samples_i          : in std_logic_vector(8 downto 0) := "000100000";
    continuation_count_o     : out std_logic_vector(63 downto 0);
    continuation_drop_count_o : out std_logic_vector(63 downto 0);
    covered_trigger_count_o  : out std_logic_vector(63 downto 0);
    descriptor_overflow_count_o : out std_logic_vector(63 downto 0);
    trailer_capture_i        : in  std_logic;
    trailer_i                : in  peak_descriptor_trailer_t;
    frame_match_o            : out std_logic;
    record_count_o           : out std_logic_vector(63 downto 0);
    full_count_o             : out std_logic_vector(63 downto 0);
    busy_count_o             : out std_logic_vector(63 downto 0);
    spacing_reject_count_o   : out std_logic_vector(63 downto 0);
    queue_reject_count_o     : out std_logic_vector(63 downto 0);
    ring_reject_count_o      : out std_logic_vector(63 downto 0);
    output_reject_count_o    : out std_logic_vector(63 downto 0);
    trigger_count_o          : out std_logic_vector(63 downto 0);
    packet_count_o           : out std_logic_vector(63 downto 0);
    delayed_sample_o         : out std_logic_vector(13 downto 0);
    ready_o                  : out std_logic;
    rd_en_i                  : in  std_logic;
    dout_o                   : out std_logic_vector(71 downto 0)
  );
end entity stc3_grouped_test_adapter;

-- Test-only adapter: exercise the grouped source with the existing packet,
-- descriptor, calibration, timestamp-wrap and overload contract benches.
architecture test of stc3_grouped_test_adapter is
  signal fast : std_logic := '0';
  signal desc : grouped_descriptor_array_t(0 to 3):=(others=>(others=>'0'));
  signal valid,busy,wr,commit : std_logic_array_t(0 to 3):=(others=>'0');
  signal addr : ring_address_array_t(0 to 3);
  signal samples : sample14_array_t(0 to 3):=(others=>(others=>'0'));
  signal waddr : unsigned(11 downto 0);
  signal data : std_logic_vector(71 downto 0);
  signal overflow : std_logic;
begin
  fast<=not fast after 1600 ps;
  engine : entity work.afe_stc3_stream_serializer
    port map(clock_i=>clock_i,reset_i=>reset_i,builder_clock_i=>fast,builder_reset_i=>reset_i,
      desc_i=>desc,desc_valid_i=>valid,desc_busy_o=>busy,ring_rd_addr_o=>addr,ring_data_i=>samples,
      packet_wr_o=>wr,packet_commit_o=>commit,packet_addr_o=>waddr,packet_data_o=>data,packet_overflow_o=>overflow);
  source : entity work.stc3_frame_source
    port map(builder_clock_i=>fast,desc_o=>desc(0),desc_valid_o=>valid(0),desc_busy_i=>busy(0),
      ring_rd_addr_i=>addr(0),ring_data_o=>samples(0),packet_wr_i=>wr(0),packet_commit_i=>commit(0),
      packet_addr_i=>waddr,packet_data_i=>data,packet_overflow_i=>overflow,
      ch_id_i=>ch_id_i,
      version_i=>version_i,
      threshold_xc_i=>threshold_xc_i,
      signal_delay_i=>signal_delay_i,
      clock_i=>clock_i,
      reset_i=>reset_i,
      reset_st_counters_i=>reset_st_counters_i,
      enable_i=>enable_i,
      force_trigger_i=>force_trigger_i,
      force_calibration_tag_i=>force_calibration_tag_i,
      timestamp_i=>timestamp_i,
      din_i=>din_i,
      trigger_i=>trigger_i,
      continuation_enable_i=>continuation_enable_i,
      positive_pulse_i=>positive_pulse_i,
      activity_threshold_i=>activity_threshold_i,
      quiet_samples_i=>quiet_samples_i,
      continuation_count_o=>continuation_count_o,
      continuation_drop_count_o=>continuation_drop_count_o,
      covered_trigger_count_o=>covered_trigger_count_o,
      descriptor_overflow_count_o=>descriptor_overflow_count_o,
      trailer_capture_i=>trailer_capture_i,
      trailer_i=>trailer_i,
      frame_match_o=>frame_match_o,
      record_count_o=>record_count_o,
      full_count_o=>full_count_o,
      busy_count_o=>busy_count_o,
      spacing_reject_count_o=>spacing_reject_count_o,
      queue_reject_count_o=>queue_reject_count_o,
      ring_reject_count_o=>ring_reject_count_o,
      output_reject_count_o=>output_reject_count_o,
      trigger_count_o=>trigger_count_o,
      packet_count_o=>packet_count_o,
      delayed_sample_o=>delayed_sample_o,
      ready_o=>ready_o,
      rd_en_i=>rd_en_i,
      dout_o=>dout_o);
end architecture;
