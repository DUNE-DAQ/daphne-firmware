library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity stc3_record_builder is
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
    timestamp_i              : in  std_logic_vector(63 downto 0);
    din_i                    : in  std_logic_vector(13 downto 0);
    trigger_i                : in  trigger_xcorr_result_t;
    frame_extend_i           : in  std_logic;
    trailer_capture_i        : in  std_logic;
    trailer_i                : in  peak_descriptor_trailer_t;
    frame_match_o            : out std_logic;
    frame_trigger_offset_o   : out std_logic_vector(9 downto 0);
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
end entity stc3_record_builder;

architecture rtl of stc3_record_builder is
  constant LIVE_COUNTER_WIDTH_C        : positive := 16;
  constant PRETRIGGER_SAMPLES_C        : natural := 64;
  constant FRAME_SAMPLE_COUNT_C        : natural := 512;
  constant FRAME_BLOCK_COUNT_C         : natural := FRAME_SAMPLE_COUNT_C / 32;
  constant FINAL_BLOCK_INDEX_C         : natural := FRAME_BLOCK_COUNT_C - 1;
  constant BLOCK_SAMPLE_COUNT_C        : natural := 32;
  constant WORDS_PER_BLOCK_C           : natural := 7;
  constant HEADER_WORD_COUNT_C         : natural := 8;
  constant RING_DEPTH_C                : positive := 2048;
  constant RING_ADDR_WIDTH_C           : positive := 11;
  constant FRAME_QUEUE_DEPTH_C         : positive := 4;

  subtype ring_addr_t is unsigned(RING_ADDR_WIDTH_C - 1 downto 0);

  type trigger_counter_state_type is (rst_trggr, wait4trig_trggr, rising_triggered);
  type serializer_state_t is (ser_idle, ser_header, ser_load, ser_emit);
  type sample_block_t is array (0 to BLOCK_SAMPLE_COUNT_C - 1) of std_logic_vector(13 downto 0);

  type frame_meta_t is record
    start_ptr      : ring_addr_t;
    sample0_ts     : std_logic_vector(63 downto 0);
    trigger_offset : std_logic_vector(9 downto 0);
    baseline       : std_logic_vector(13 downto 0);
    trigger_sample : std_logic_vector(13 downto 0);
    threshold_lsb  : std_logic_vector(13 downto 0);
    continuation   : std_logic;
  end record;

  type frame_meta_array_t is array (0 to FRAME_QUEUE_DEPTH_C - 1) of frame_meta_t;

  constant FRAME_META_NULL_C : frame_meta_t := (
    start_ptr      => (others => '0'),
    sample0_ts     => (others => '0'),
    trigger_offset => (others => '0'),
    baseline       => (others => '0'),
    trigger_sample => (others => '0'),
    threshold_lsb  => (others => '0'),
    continuation   => '0'
  );

  function wrap_add(addr : ring_addr_t; offset : natural) return ring_addr_t is
  begin
    return addr + to_unsigned(offset, addr'length);
  end function;

  function wrap_sub(addr : ring_addr_t; offset : natural) return ring_addr_t is
  begin
    return addr - to_unsigned(offset, addr'length);
  end function;

  function ring_distance(newer : ring_addr_t; older : ring_addr_t) return natural is
  begin
    return to_integer(newer - older);
  end function;

  function next_queue_idx(idx : integer) return integer is
  begin
    if idx = FRAME_QUEUE_DEPTH_C - 1 then
      return 0;
    end if;
    return idx + 1;
  end function;

  function subtract_clamped(value : unsigned; amount : natural) return unsigned is
  begin
    if value < to_unsigned(amount, value'length) then
      return (others => '0');
    end if;
    return value - to_unsigned(amount, value'length);
  end function;

  function pack_block_word(samples : sample_block_t; word_idx : natural) return std_logic_vector is
  begin
    case word_idx is
      when 0 =>
        return samples(4)(7 downto 0) & samples(3) & samples(2) & samples(1) & samples(0);
      when 1 =>
        return samples(9)(1 downto 0) & samples(8) & samples(7) & samples(6) & samples(5) & samples(4)(13 downto 8);
      when 2 =>
        return samples(13)(9 downto 0) & samples(12) & samples(11) & samples(10) & samples(9)(13 downto 2);
      when 3 =>
        return samples(18)(3 downto 0) & samples(17) & samples(16) & samples(15) & samples(14) & samples(13)(13 downto 10);
      when 4 =>
        return samples(22)(11 downto 0) & samples(21) & samples(20) & samples(19) & samples(18)(13 downto 4);
      when 5 =>
        return samples(27)(5 downto 0) & samples(26) & samples(25) & samples(24) & samples(23) & samples(22)(13 downto 12);
      when others =>
        return samples(31) & samples(30) & samples(29) & samples(28) & samples(27)(13 downto 6);
    end case;
  end function;

  signal serializer_state_s       : serializer_state_t := ser_idle;
  signal trig_count_state_s       : trigger_counter_state_type := rst_trggr;
  signal write_ptr_s              : ring_addr_t := (others => '0');
  signal ring_rd_addr_s           : ring_addr_t := (others => '0');
  signal ring_dout_s              : std_logic_vector(13 downto 0);
  signal frame_queue_s            : frame_meta_array_t := (others => FRAME_META_NULL_C);
  signal frame_queue_head_s       : integer range 0 to FRAME_QUEUE_DEPTH_C - 1 := 0;
  signal frame_queue_tail_s       : integer range 0 to FRAME_QUEUE_DEPTH_C - 1 := 0;
  signal frame_queue_count_s      : integer range 0 to FRAME_QUEUE_DEPTH_C := 0;
  signal active_frame_s           : frame_meta_t := FRAME_META_NULL_C;
  signal active_frame_valid_s     : std_logic := '0';
  signal active_trailer_s         : peak_descriptor_trailer_t := PEAK_DESCRIPTOR_TRAILER_NULL;
  signal block_samples_s          : sample_block_t := (others => (others => '0'));
  signal header_index_s           : integer range 0 to HEADER_WORD_COUNT_C - 1 := 0;
  signal block_index_s            : integer range 0 to FINAL_BLOCK_INDEX_C := 0;
  signal load_issue_index_s       : integer range 0 to BLOCK_SAMPLE_COUNT_C := 0;
  signal emit_index_s             : integer range 0 to WORDS_PER_BLOCK_C - 1 := 0;
  signal fifo_din_s               : std_logic_vector(71 downto 0) := (others => '0');
  signal fifo_wr_en_s             : std_logic := '0';
  signal fifo_sleep_s             : std_logic := '1';
  signal prog_empty_s             : std_logic;
  signal prog_full_s              : std_logic;
  signal trailer_reg_s            : peak_descriptor_trailer_t := PEAK_DESCRIPTOR_TRAILER_NULL;
  signal event_pulse_s            : std_logic;
  signal oldest_pending_valid_s   : std_logic;
  signal oldest_pending_ptr_s     : ring_addr_t := (others => '0');
  signal queue_head_ready_s       : std_logic;
  signal ring_safe_ok_s           : std_logic;
  signal queue_space_ok_s         : std_logic;
  signal can_accept_frame_s       : std_logic;
  signal coverage_valid_s         : std_logic := '0';
  signal coverage_end_ts_s        : unsigned(63 downto 0) := (others => '0');
  signal trigger_timestamp_s      : unsigned(63 downto 0);
  signal current_timestamp_s      : unsigned(63 downto 0);
  signal natural_sample0_ts_s     : unsigned(63 downto 0);
  signal clipped_sample0_ts_s     : unsigned(63 downto 0);
  signal frame_end_ts_s           : unsigned(63 downto 0);
  signal continuation_end_ts_s    : unsigned(63 downto 0);
  signal covered_trigger_s        : std_logic;
  signal frame_trigger_offset_s   : std_logic_vector(9 downto 0);
  signal continuation_request_s   : std_logic;
  signal spacing_reject_s         : std_logic;
  signal queue_reject_s           : std_logic;
  signal ring_reject_s            : std_logic;
  signal busy_reject_s            : std_logic;
  signal full_reject_s            : std_logic;
  signal record_count_s           : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal busydrop_count_s         : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal spacingdrop_count_s      : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal queuedrop_count_s        : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal ringdrop_count_s         : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal fulldrop_count_s         : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal trig_count_s             : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal pack_count_s             : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
begin
  -- Coalesced fixed-record experiment with chained continuation:
  -- emitted records stay 512 samples / 120 words wide for downstream compatibility.
  -- already-covered triggers do not allocate a new record.
  -- when a new record would overlap the previous coverage window, its sample0 is clipped
  -- forward and the true trigger position is carried explicitly in the metadata header.
  -- if the descriptor path is still active on the last sample of the current frame,
  -- a continuation frame is queued immediately after it with no overlap.
  event_pulse_s <= trigger_i.trigger_pulse or force_trigger_i;
  trigger_timestamp_s  <= unsigned(trigger_i.trigger_timestamp);
  current_timestamp_s  <= unsigned(timestamp_i);
  natural_sample0_ts_s <= subtract_clamped(trigger_timestamp_s, PRETRIGGER_SAMPLES_C);
  clipped_sample0_ts_s <= coverage_end_ts_s + 1 when (
    coverage_valid_s = '1' and
    natural_sample0_ts_s <= coverage_end_ts_s
  ) else
    natural_sample0_ts_s;
  frame_end_ts_s <= clipped_sample0_ts_s + to_unsigned(FRAME_SAMPLE_COUNT_C - 1, 64);
  continuation_end_ts_s <= coverage_end_ts_s + to_unsigned(FRAME_SAMPLE_COUNT_C, 64);
  covered_trigger_s <= '1' when (
    enable_i = '1' and
    coverage_valid_s = '1' and
    trigger_timestamp_s <= coverage_end_ts_s
  ) else
    '0';
  frame_trigger_offset_s <= std_logic_vector(resize(trigger_timestamp_s - clipped_sample0_ts_s, frame_trigger_offset_s'length)) when
    trigger_timestamp_s >= clipped_sample0_ts_s else
    (others => '0');
  continuation_request_s <= '1' when (
    enable_i = '1' and
    coverage_valid_s = '1' and
    frame_extend_i = '1' and
    current_timestamp_s = coverage_end_ts_s
  ) else
    '0';

  oldest_pending_valid_s <= active_frame_valid_s when active_frame_valid_s = '1' else
                            '1' when frame_queue_count_s > 0 else
                            '0';
  oldest_pending_ptr_s   <= active_frame_s.start_ptr when active_frame_valid_s = '1' else
                            frame_queue_s(frame_queue_head_s).start_ptr when frame_queue_count_s > 0 else
                            (others => '0');

  queue_head_ready_s <= '1' when (
    frame_queue_count_s > 0 and
    ring_distance(write_ptr_s, frame_queue_s(frame_queue_head_s).start_ptr) >= FRAME_SAMPLE_COUNT_C - 1
  ) else
    '0';

  queue_space_ok_s <= '1' when frame_queue_count_s < FRAME_QUEUE_DEPTH_C else '0';

  ring_safe_ok_s <= '1' when (
    oldest_pending_valid_s = '0' or
    ring_distance(write_ptr_s, oldest_pending_ptr_s) <= RING_DEPTH_C - FRAME_SAMPLE_COUNT_C
  ) else
    '0';

  can_accept_frame_s <= '1' when (
    enable_i = '1' and
    covered_trigger_s = '0' and
    queue_space_ok_s = '1' and
    ring_safe_ok_s = '1' and
    prog_full_s = '0'
  ) else
    '0';

  spacing_reject_s <= '0';
  queue_reject_s   <= '1' when (enable_i = '1' and covered_trigger_s = '0' and queue_space_ok_s = '0') else '0';
  ring_reject_s    <= '1' when (
    enable_i = '1' and
    covered_trigger_s = '0' and
    queue_space_ok_s = '1' and
    ring_safe_ok_s = '0'
  ) else
    '0';
  full_reject_s <= '1' when (
    enable_i = '1' and
    covered_trigger_s = '0' and
    queue_space_ok_s = '1' and
    ring_safe_ok_s = '1' and
    prog_full_s = '1'
  ) else
    '0';
  busy_reject_s <= '1' when (
    enable_i = '1' and
    covered_trigger_s = '0' and
    can_accept_frame_s = '0' and
    full_reject_s = '0'
  ) else
    '0';

  frame_match_o          <= can_accept_frame_s;
  frame_trigger_offset_o <= frame_trigger_offset_s when can_accept_frame_s = '1' else (others => '0');

  ring_rd_addr_s <= wrap_add(active_frame_s.start_ptr, block_index_s * BLOCK_SAMPLE_COUNT_C + load_issue_index_s)
    when serializer_state_s = ser_load and load_issue_index_s < BLOCK_SAMPLE_COUNT_C else
    active_frame_s.start_ptr;

  sample_ring_inst : entity work.sample_ring_buffer
    generic map (
      DATA_WIDTH_G => 14,
      DEPTH_G      => RING_DEPTH_C,
      ADDR_WIDTH_G => RING_ADDR_WIDTH_C
    )
    port map (
      clock_i   => clock_i,
      wr_en_i   => not reset_i,
      wr_addr_i => write_ptr_s,
      din_i     => din_i,
      rd_addr_i => ring_rd_addr_s,
      dout_o    => ring_dout_s
    );

  output_fifo_inst : entity work.sync_fifo_fwft
    generic map (
      DATA_WIDTH_G        => 72,
      DEPTH_G             => 4096,
      COUNT_WIDTH_G       => 13,
      PROG_EMPTY_THRESH_G => 119,
      PROG_FULL_THRESH_G  => 3840
    )
    port map (
      clock_i         => clock_i,
      reset_i         => reset_i,
      sleep_i         => fifo_sleep_s,
      wr_en_i         => fifo_wr_en_s,
      din_i           => fifo_din_s,
      rd_en_i         => rd_en_i,
      dout_o          => dout_o,
      prog_empty_o    => prog_empty_s,
      prog_full_o     => prog_full_s,
      wr_data_count_o => open
    );

  fifo_sleep_s <= '1' when serializer_state_s = ser_idle else '0';

  fifo_wr_en_s <= '1' when (serializer_state_s = ser_header or serializer_state_s = ser_emit) else '0';

  fifo_din_s <= X"BE" & active_frame_s.sample0_ts when (serializer_state_s = ser_header and header_index_s = 0) else
                X"00" & ch_id_i(7 downto 0) & version_i(3 downto 0) &
                active_frame_s.trigger_offset & active_frame_s.baseline &
                active_frame_s.threshold_lsb & active_frame_s.trigger_sample when (serializer_state_s = ser_header and header_index_s = 1) else
                X"00" & active_trailer_s(1) & active_trailer_s(0) when (serializer_state_s = ser_header and header_index_s = 2) else
                X"00" & active_trailer_s(3) & active_trailer_s(2) when (serializer_state_s = ser_header and header_index_s = 3) else
                X"00" & active_trailer_s(5) & active_trailer_s(4) when (serializer_state_s = ser_header and header_index_s = 4) else
                X"00" & active_trailer_s(7) & active_trailer_s(6) when (serializer_state_s = ser_header and header_index_s = 5) else
                X"00" & active_trailer_s(9) & active_trailer_s(8) when (serializer_state_s = ser_header and header_index_s = 6) else
                X"00" & active_trailer_s(11) & active_trailer_s(10) when (serializer_state_s = ser_header and header_index_s = 7) else
                X"ED" & pack_block_word(block_samples_s, emit_index_s) when (
                  serializer_state_s = ser_emit and
                  block_index_s = FINAL_BLOCK_INDEX_C and
                  emit_index_s = WORDS_PER_BLOCK_C - 1
                ) else
                X"00" & pack_block_word(block_samples_s, emit_index_s) when serializer_state_s = ser_emit else
                (others => '0');

  trailer_capture_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        trailer_reg_s <= PEAK_DESCRIPTOR_TRAILER_NULL;
      elsif trailer_capture_i = '1' then
        trailer_reg_s <= trailer_i;
      end if;
    end if;
  end process trailer_capture_proc;

  count_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if (reset_i = '1' or reset_st_counters_i = '1' or enable_i = '0') then
        trig_count_s       <= (others => '0');
        trig_count_state_s <= rst_trggr;
      else
        case trig_count_state_s is
          when rst_trggr =>
            trig_count_state_s <= wait4trig_trggr;
          when wait4trig_trggr =>
            if trigger_i.trigger_pulse = '1' then
              trig_count_s       <= trig_count_s + 1;
              trig_count_state_s <= rising_triggered;
            end if;
          when rising_triggered =>
            if trigger_i.trigger_pulse = '0' then
              trig_count_state_s <= wait4trig_trggr;
            end if;
          when others =>
            trig_count_state_s <= rst_trggr;
        end case;
      end if;
    end if;
  end process count_proc;

  main_proc : process(clock_i)
    variable queue_v        : frame_meta_array_t;
    variable head_v         : integer range 0 to FRAME_QUEUE_DEPTH_C - 1;
    variable tail_v         : integer range 0 to FRAME_QUEUE_DEPTH_C - 1;
    variable count_v        : integer range 0 to FRAME_QUEUE_DEPTH_C;
    variable active_v       : frame_meta_t;
    variable active_valid_v : std_logic;
    variable start_age_v    : natural;
    variable sample0_ts_v   : unsigned(63 downto 0);
    variable start_ptr_v    : ring_addr_t;
  begin
    if rising_edge(clock_i) then
      if (reset_i = '1' or reset_st_counters_i = '1') then
        serializer_state_s   <= ser_idle;
        write_ptr_s          <= (others => '0');
        frame_queue_s        <= (others => FRAME_META_NULL_C);
        frame_queue_head_s   <= 0;
        frame_queue_tail_s   <= 0;
        frame_queue_count_s  <= 0;
        active_frame_s       <= FRAME_META_NULL_C;
        active_frame_valid_s <= '0';
        active_trailer_s     <= PEAK_DESCRIPTOR_TRAILER_NULL;
        block_samples_s      <= (others => (others => '0'));
        header_index_s       <= 0;
        block_index_s        <= 0;
        load_issue_index_s   <= 0;
        emit_index_s         <= 0;
        record_count_s       <= (others => '0');
        busydrop_count_s     <= (others => '0');
        spacingdrop_count_s  <= (others => '0');
        queuedrop_count_s    <= (others => '0');
        ringdrop_count_s     <= (others => '0');
        fulldrop_count_s     <= (others => '0');
        pack_count_s         <= (others => '0');
        coverage_valid_s     <= '0';
        coverage_end_ts_s    <= (others => '0');
      else
        queue_v        := frame_queue_s;
        head_v         := frame_queue_head_s;
        tail_v         := frame_queue_tail_s;
        count_v        := frame_queue_count_s;
        active_v       := active_frame_s;
        active_valid_v := active_frame_valid_s;

        write_ptr_s <= wrap_add(write_ptr_s, 1);

        if enable_i = '0' then
          record_count_s       <= (others => '0');
          busydrop_count_s     <= (others => '0');
          spacingdrop_count_s  <= (others => '0');
          queuedrop_count_s    <= (others => '0');
          ringdrop_count_s     <= (others => '0');
          fulldrop_count_s     <= (others => '0');
          pack_count_s         <= (others => '0');
        else
          if event_pulse_s = '1' then
            if covered_trigger_s = '1' then
              null;
            elsif can_accept_frame_s = '1' then
              sample0_ts_v := clipped_sample0_ts_s;
              start_age_v  := ring_distance(
                unsigned(timestamp_i(RING_ADDR_WIDTH_C - 1 downto 0)),
                sample0_ts_v(RING_ADDR_WIDTH_C - 1 downto 0)
              );
              start_ptr_v  := wrap_sub(write_ptr_s, start_age_v);

              queue_v(tail_v).start_ptr      := start_ptr_v;
              queue_v(tail_v).sample0_ts     := std_logic_vector(sample0_ts_v);
              queue_v(tail_v).trigger_offset := frame_trigger_offset_s;
              queue_v(tail_v).baseline       := trigger_i.baseline;
              queue_v(tail_v).trigger_sample := trigger_i.trigger_sample;
              queue_v(tail_v).threshold_lsb  := threshold_xc_i(13 downto 0);
              queue_v(tail_v).continuation   := '0';

              tail_v  := next_queue_idx(tail_v);
              count_v := count_v + 1;

              pack_count_s      <= pack_count_s + 1;
              coverage_valid_s  <= '1';
              coverage_end_ts_s <= frame_end_ts_s;
            elsif full_reject_s = '1' then
              fulldrop_count_s <= fulldrop_count_s + 1;
            elsif spacing_reject_s = '1' then
              busydrop_count_s <= busydrop_count_s + 1;
              spacingdrop_count_s <= spacingdrop_count_s + 1;
            elsif queue_reject_s = '1' then
              busydrop_count_s <= busydrop_count_s + 1;
              queuedrop_count_s <= queuedrop_count_s + 1;
            elsif ring_reject_s = '1' then
              busydrop_count_s <= busydrop_count_s + 1;
              ringdrop_count_s <= ringdrop_count_s + 1;
            elsif busy_reject_s = '1' then
              busydrop_count_s <= busydrop_count_s + 1;
            end if;
          end if;

          if continuation_request_s = '1' then
            if count_v < FRAME_QUEUE_DEPTH_C and ring_safe_ok_s = '1' and prog_full_s = '0' then
              queue_v(tail_v).start_ptr      := wrap_add(write_ptr_s, 1);
              queue_v(tail_v).sample0_ts     := std_logic_vector(coverage_end_ts_s + 1);
              queue_v(tail_v).trigger_offset := (others => '0');
              queue_v(tail_v).baseline       := trigger_i.baseline;
              queue_v(tail_v).trigger_sample := din_i;
              queue_v(tail_v).threshold_lsb  := threshold_xc_i(13 downto 0);
              queue_v(tail_v).continuation   := '1';

              tail_v  := next_queue_idx(tail_v);
              count_v := count_v + 1;

              pack_count_s      <= pack_count_s + 1;
              coverage_valid_s  <= '1';
              coverage_end_ts_s <= continuation_end_ts_s;
            end if;
          end if;

          case serializer_state_s is
            when ser_idle =>
              if active_valid_v = '0' and queue_head_ready_s = '1' then
                active_v           := queue_v(head_v);
                active_valid_v     := '1';
                if queue_v(head_v).continuation = '1' then
                  active_trailer_s <= PEAK_DESCRIPTOR_TRAILER_NULL;
                else
                  active_trailer_s <= trailer_reg_s;
                end if;
                header_index_s     <= 0;
                block_index_s      <= 0;
                load_issue_index_s <= 0;
                emit_index_s       <= 0;
                serializer_state_s <= ser_header;
                record_count_s     <= record_count_s + 1;

                head_v  := next_queue_idx(head_v);
                count_v := count_v - 1;
              end if;

            when ser_header =>
              if header_index_s = HEADER_WORD_COUNT_C - 1 then
                header_index_s     <= 0;
                block_index_s      <= 0;
                load_issue_index_s <= 0;
                serializer_state_s <= ser_load;
              else
                header_index_s <= header_index_s + 1;
              end if;

            when ser_load =>
              if load_issue_index_s = 0 then
                load_issue_index_s <= 1;
              elsif load_issue_index_s < BLOCK_SAMPLE_COUNT_C then
                block_samples_s(load_issue_index_s - 1) <= ring_dout_s;
                load_issue_index_s                      <= load_issue_index_s + 1;
              else
                block_samples_s(BLOCK_SAMPLE_COUNT_C - 1) <= ring_dout_s;
                emit_index_s                              <= 0;
                serializer_state_s                        <= ser_emit;
              end if;

            when ser_emit =>
              if emit_index_s = WORDS_PER_BLOCK_C - 1 then
                if block_index_s = FINAL_BLOCK_INDEX_C then
                  active_v           := FRAME_META_NULL_C;
                  active_valid_v     := '0';
                  serializer_state_s <= ser_idle;
                else
                  block_index_s      <= block_index_s + 1;
                  load_issue_index_s <= 0;
                  serializer_state_s <= ser_load;
                end if;
              else
                emit_index_s <= emit_index_s + 1;
              end if;
          end case;
        end if;

        frame_queue_s        <= queue_v;
        frame_queue_head_s   <= head_v;
        frame_queue_tail_s   <= tail_v;
        frame_queue_count_s  <= count_v;
        active_frame_s       <= active_v;
        active_frame_valid_s <= active_valid_v;
      end if;
    end if;
  end process main_proc;

  record_count_o   <= std_logic_vector(resize(record_count_s, record_count_o'length));
  full_count_o     <= std_logic_vector(resize(fulldrop_count_s, full_count_o'length));
  busy_count_o     <= std_logic_vector(resize(busydrop_count_s, busy_count_o'length));
  spacing_reject_count_o <= std_logic_vector(resize(spacingdrop_count_s, spacing_reject_count_o'length));
  queue_reject_count_o   <= std_logic_vector(resize(queuedrop_count_s, queue_reject_count_o'length));
  ring_reject_count_o    <= std_logic_vector(resize(ringdrop_count_s, ring_reject_count_o'length));
  output_reject_count_o  <= std_logic_vector(resize(fulldrop_count_s, output_reject_count_o'length));
  trigger_count_o  <= std_logic_vector(resize(trig_count_s, trigger_count_o'length));
  packet_count_o   <= std_logic_vector(resize(pack_count_s, packet_count_o'length));
  delayed_sample_o <= din_i;
  ready_o          <= not prog_empty_s;
end architecture rtl;
