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
end entity stc3_record_builder;

-- Experimental fixed-size continuation builder. The ring never stops sampling.
-- Packet slots are reserved on admission, filled payload-first, and published
-- only after all eight header words have been written. The wire order is intact.
architecture rtl of stc3_record_builder is
  constant FRAME_SAMPLE_COUNT_C : natural := 512;
  constant PRETRIGGER_SAMPLES_C : natural := 64;
  constant FRAME_WORD_COUNT_C : natural := 120;
  constant RING_DEPTH_C : positive := 2048;
  constant FRAME_QUEUE_DEPTH_C : positive := 4;
  constant PACKET_SLOT_COUNT_C : positive := 32;
  constant SERIALIZER_CYCLES_C : positive := 512;
  constant RETENTION_LIMIT_C : positive := RING_DEPTH_C - 64;
  -- Live ring/queue references span at most 2048 samples. The extra two
  -- address bits give an 8192-sample modulo and a 4096-sample signed half-range.
  -- Expired spacing references are invalidated and deadlines are clamped below.
  subtype sample_seq_t is unsigned(12 downto 0);
  subtype slot_t is unsigned(4 downto 0);
  type frame_meta_t is record
    start_seq : sample_seq_t;
    sample0_ts : std_logic_vector(63 downto 0);
    baseline : std_logic_vector(13 downto 0);
    trigger_sample : std_logic_vector(13 downto 0);
    threshold_lsb : std_logic_vector(13 downto 0);
    activity_threshold : std_logic_vector(13 downto 0);
    positive_pulse : std_logic;
    calibration_tag : std_logic_vector(1 downto 0);
    continuation : std_logic;
    slot : slot_t;
  end record;
  constant META_NULL_C : frame_meta_t := (
    start_seq=>(others=>'0'), sample0_ts=>(others=>'0'), baseline=>(others=>'0'),
    trigger_sample=>(others=>'0'), threshold_lsb=>(others=>'0'),
    activity_threshold=>(others=>'0'), positive_pulse=>'0', calibration_tag=>CALIBRATION_TAG_NORMAL_C,
    continuation=>'0', slot=>(others=>'0'));
  -- A packed, single-write distributed RAM avoids per-field register feedback
  -- and reset muxes across the descriptor queue. Empty entries are never used.
  subtype packed_meta_t is std_logic_vector(141 downto 0);
  type frame_queue_t is array(0 to FRAME_QUEUE_DEPTH_C-1) of packed_meta_t;
  function pack_meta(m : frame_meta_t) return packed_meta_t is
  begin
    return std_logic_vector(m.start_seq) & m.sample0_ts & m.baseline & m.trigger_sample &
      m.threshold_lsb & m.activity_threshold & m.positive_pulse & m.calibration_tag &
      m.continuation & std_logic_vector(m.slot);
  end;
  function unpack_meta(v : packed_meta_t) return frame_meta_t is
    variable m : frame_meta_t;
  begin
    m.start_seq:=unsigned(v(141 downto 129)); m.sample0_ts:=v(128 downto 65);
    m.baseline:=v(64 downto 51); m.trigger_sample:=v(50 downto 37);
    m.threshold_lsb:=v(36 downto 23); m.activity_threshold:=v(22 downto 9);
    m.positive_pulse:=v(8); m.calibration_tag:=v(7 downto 6); m.continuation:=v(5);
    m.slot:=unsigned(v(4 downto 0));
    return m;
  end;
  function raw_baseline(value : std_logic_vector(13 downto 0); positive : std_logic) return std_logic_vector is
  begin
    if positive='1' then return std_logic_vector(to_unsigned(0,14)-unsigned(value)); end if;
    return value;
  end;
  function next_q(i : natural) return natural is
  begin return (i+1) mod FRAME_QUEUE_DEPTH_C; end;
  function seq_age(now_seq, start_seq : sample_seq_t) return natural is
    variable d : sample_seq_t;
  begin
    if start_seq = now_seq+1 then return 0; end if;
    d := now_seq-start_seq;
    if d > to_unsigned(RING_DEPTH_C, d'length) then return RING_DEPTH_C+1; end if;
    return to_integer(d);
  end;
  function slot_addr(slot : slot_t; word_idx : natural) return unsigned is
  begin return slot & to_unsigned(word_idx,7); end;
  function inside_window(delta : sample_seq_t;
                         continuation : std_logic) return boolean is
  begin
    -- The union of trigger-in-frame [0,511] and pretrigger-start-in-frame
    -- [64,575] is [0,575]. Call only after the full event-age guard.
    if continuation='1' then return delta<to_unsigned(FRAME_SAMPLE_COUNT_C+PRETRIGGER_SAMPLES_C,sample_seq_t'length); end if;
    return delta<to_unsigned(FRAME_SAMPLE_COUNT_C,sample_seq_t'length);
  end;
  signal seq_s : sample_seq_t := (others=>'0');
  signal history_s : natural range 0 to RING_DEPTH_C := 0;
  signal queue_s : frame_queue_t := (others=>(others=>'0'));
  attribute ram_style : string;
  attribute ram_style of queue_s : signal is "distributed";
  signal head_s, tail_s : natural range 0 to FRAME_QUEUE_DEPTH_C-1 := 0;
  signal queue_count_s : natural range 0 to FRAME_QUEUE_DEPTH_C := 0;
  signal queue_head_s, queue_next_s : frame_meta_t;
  signal active_s : frame_meta_t := META_NULL_C;
  signal active_valid_s : std_logic := '0';
  -- A read request and its returned sample are separate pipeline stages.
  -- A next fragment can issue sample0 while the previous sample511 is consumed.
  signal fetch_running_s, sample_valid_s, launch_s : std_logic := '0';
  signal fetch_index_s, sample_index_s : unsigned(8 downto 0) := (others=>'0');
  signal header_pending_s : std_logic := '0';
  signal header_meta_s : frame_meta_t := META_NULL_C;
  -- Publication is ordered, so slot liveness is represented by pointers and
  -- counts. Only exceptional stale-frame holes need a per-slot bit.
  signal dropped_s : std_logic_vector(PACKET_SLOT_COUNT_C-1 downto 0) := (others=>'0');
  signal publish_drop_s, consume_drop_s : std_logic;
  signal allocate_slot_s, read_slot_s : slot_t := (others=>'0');
  signal reserved_count_s, published_count_s : natural range 0 to PACKET_SLOT_COUNT_C := 0;
  signal read_word_s : natural range 0 to FRAME_WORD_COUNT_C-1 := 0;
  signal header_s : natural range 0 to 7 := 0;
  signal payload_word_s : natural range 0 to 111 := 0;
  signal pack_shift_s : std_logic_vector(63 downto 0) := (others=>'0');
  signal pack_window_s : std_logic_vector(77 downto 0);
  signal payload_wr_s : std_logic;
  signal payload_data_s : std_logic_vector(63 downto 0);
  signal ring_addr_s : unsigned(10 downto 0);
  signal ring_data_s : std_logic_vector(13 downto 0);
  signal store_wr_s : std_logic;
  signal store_waddr_s, store_raddr_s : unsigned(11 downto 0);
  signal store_din_s : std_logic_vector(71 downto 0);
  signal descriptor_start_s, descriptor_overflow_s : std_logic;
  signal descriptor_word_s : std_logic_vector(63 downto 0);
  signal descriptor_baseline_s, activity_baseline_s : std_logic_vector(13 downto 0);
  signal chain_active_s, current_accepted_s, previous_accepted_s : std_logic := '0';
  signal current_s, previous_s : frame_meta_t := META_NULL_C;
  signal activity_s : std_logic := '0';
  signal quiet_s : natural range 0 to 511 := 0;
  signal chain_quiet_limit_s : natural range 1 to 511 := 32;
  signal required_end_s : sample_seq_t := (others=>'0');
  signal last_start_s : sample_seq_t := (others=>'0');
  signal last_start_valid_s : std_logic := '0';
  signal event_pulse_s, trigger_previous_s : std_logic := '0';
  signal event_timestamp_s : std_logic_vector(63 downto 0);
  -- One full-width age check protects the bounded local comparisons against
  -- stale/future tuples whose low sequence bits would otherwise alias.
  signal event_age_s : unsigned(63 downto 0);
  signal timestamp_previous_s : unsigned(63 downto 0) := (others=>'0');
  signal timestamp_armed_s : std_logic := '0';
  signal timestamp_jump_s : std_logic;
  signal event_seq_s, current_delta_s, previous_delta_s : sample_seq_t;
  signal event_sample_s : std_logic_vector(13 downto 0);
  signal event_tag_s : std_logic_vector(1 downto 0);
  signal record_count_s, full_count_s, busy_count_s, spacing_count_s, queue_drop_s, ring_drop_s,
         trigger_count_s, packet_count_s, continuation_count_s, continuation_drop_s,
         covered_count_s, descriptor_overflow_count_s : unsigned(31 downto 0) := (others=>'0');
begin
  -- Clock/reset/timestamp are common to all channels, allowing synthesis to
  -- share this epoch guard. Natural64-bit wrap is a normal increment.
  timestamp_jump_s <= '1' when timestamp_armed_s='1' and
    unsigned(timestamp_i)/=timestamp_previous_s+1 else '0';
  event_age_s <= unsigned(timestamp_i)-unsigned(event_timestamp_s);
  event_seq_s <= seq_s-resize(event_age_s,sample_seq_t'length);
  current_delta_s <= event_seq_s-current_s.start_seq;
  previous_delta_s <= event_seq_s-previous_s.start_seq;
  queue_head_s <= unpack_meta(queue_s(head_s));
  queue_next_s <= unpack_meta(queue_s(next_q(head_s)));
  descriptor_baseline_s <= raw_baseline(active_s.baseline,active_s.positive_pulse);
  activity_baseline_s <= raw_baseline(current_s.baseline,current_s.positive_pulse);
  publish_drop_s <= '1' when active_valid_s='0' and header_pending_s='0' and queue_count_s>0 and
    seq_age(seq_s,queue_head_s.start_seq)>RETENTION_LIMIT_C else '0';
  consume_drop_s <= '1' when published_count_s>0 and dropped_s(to_integer(read_slot_s))='1' else '0';
  drop_bitmap_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i='1' then dropped_s<=(others=>'0');
      else
        for i in 0 to PACKET_SLOT_COUNT_C-1 loop
          if consume_drop_s='1' and read_slot_s=to_unsigned(i,read_slot_s'length) then dropped_s(i)<='0'; end if;
          if publish_drop_s='1' and queue_head_s.slot=to_unsigned(i,queue_head_s.slot'length) then dropped_s(i)<='1'; end if;
        end loop;
      end if;
    end if;
  end process;
  event_pulse_s <= trigger_i.trigger_pulse or force_trigger_i;
  event_timestamp_s <= timestamp_i when force_trigger_i='1' else trigger_i.trigger_timestamp;
  event_sample_s <= din_i when force_trigger_i='1' else trigger_i.trigger_sample;
  event_tag_s <= force_calibration_tag_i when force_trigger_i='1' else trigger_i.calibration_tag;
  -- Kept for legacy diagnostic calculator compatibility; packet descriptors use
  -- explicit fragment-local start/sample-valid handshakes below.
  frame_match_o <= '1' when enable_i='1' and queue_count_s<FRAME_QUEUE_DEPTH_C and
                   reserved_count_s<PACKET_SLOT_COUNT_C else '0';
  delayed_sample_o <= din_i;
  ready_o <= '1' when published_count_s>0 and dropped_s(to_integer(read_slot_s))='0' else '0';

  launch_s <= '1' when fetch_running_s='0' and queue_count_s>0 and
    seq_age(seq_s,queue_head_s.start_seq)>=511 and
    seq_age(seq_s,queue_head_s.start_seq)<=RETENTION_LIMIT_C else '0';
  ring_addr_s <= queue_head_s.start_seq(10 downto 0) when launch_s='1'
                 else active_s.start_seq(10 downto 0)+resize(fetch_index_s,11);
  ring_inst : entity work.sample_ring_buffer_single
    generic map(DATA_WIDTH_G=>14, DEPTH_G=>RING_DEPTH_C, ADDR_WIDTH_G=>11)
    port map(clock_i=>clock_i, wr_en_i=>not reset_i, wr_addr_i=>seq_s(10 downto 0), din_i=>din_i,
             rd_addr_i=>ring_addr_s, dout_o=>ring_data_s);
  store_inst : entity work.packet_frame_store
    port map(clock_i=>clock_i, wr_en_i=>store_wr_s, wr_addr_i=>store_waddr_s,
             din_i=>store_din_s, rd_addr_i=>store_raddr_s, dout_o=>dout_o);
  store_rd_addr_proc : process(all)
  begin
    store_raddr_s <= slot_addr(read_slot_s,read_word_s);
    if consume_drop_s='1' then
      store_raddr_s <= slot_addr(read_slot_s+1,0);
    elsif rd_en_i='1' and published_count_s>0 and dropped_s(to_integer(read_slot_s))='0' then
      if read_word_s=FRAME_WORD_COUNT_C-1 then store_raddr_s<=slot_addr(read_slot_s+1,0);
      else store_raddr_s<=slot_addr(read_slot_s,read_word_s+1); end if;
    end if;
  end process;
  -- Constant shifts and seven fixed slices serialize 32 samples into seven
  -- words. There is no variable shift network or 32-sample staging array.
  pack_window_s <= ring_data_s & pack_shift_s;
  pack_proc : process(all)
  begin
    payload_wr_s <= sample_valid_s;
    payload_data_s <= (others=>'0');
    case to_integer(sample_index_s(4 downto 0)) is
      when 4  => payload_data_s <= pack_window_s(71 downto 8);
      when 9  => payload_data_s <= pack_window_s(65 downto 2);
      when 13 => payload_data_s <= pack_window_s(73 downto 10);
      when 18 => payload_data_s <= pack_window_s(67 downto 4);
      when 22 => payload_data_s <= pack_window_s(75 downto 12);
      when 27 => payload_data_s <= pack_window_s(69 downto 6);
      when 31 => payload_data_s <= pack_window_s(77 downto 14);
      when others => payload_wr_s <= '0';
    end case;
  end process;
  store_wr_s <= (payload_wr_s or header_pending_s) and not reset_i;
  store_waddr_s <= slot_addr(active_s.slot,8+payload_word_s) when payload_wr_s='1'
                   else slot_addr(header_meta_s.slot,header_s);
  store_data_proc : process(all)
  begin
    store_din_s <= (others=>'0');
    if payload_wr_s='1' then
      store_din_s(63 downto 0)<=payload_data_s;
      if sample_index_s=511 then store_din_s(71 downto 64)<=X"ED"; end if;
    elsif header_pending_s='1' then
      case header_s is
        when 0 => store_din_s<=X"BE" & header_meta_s.sample0_ts;
        when 1 => store_din_s<=X"00" & ch_id_i & version_i & header_meta_s.continuation & '1' &
                    descriptor_overflow_s & '0' & header_meta_s.calibration_tag & header_meta_s.baseline &
                    "00" & header_meta_s.threshold_lsb & "00" & header_meta_s.trigger_sample;
        when others => store_din_s<=X"00" & descriptor_word_s;
      end case;
    end if;
  end process;
  descriptor_start_s <= '1' when sample_valid_s='1' and sample_index_s=0 else '0';
  descriptor_inst : entity work.fragment_peak_descriptors_banked
    port map(clock_i=>clock_i, reset_i=>reset_i, start_i=>descriptor_start_s,
      baseline_i=>descriptor_baseline_s, positive_pulse_i=>active_s.positive_pulse,
      threshold_i=>active_s.activity_threshold,
      sample_valid_i=>sample_valid_s, sample_i=>ring_data_s,
      sample_index_i=>sample_index_s,
      read_index_i=>to_unsigned(header_s,3)-2, read_word_o=>descriptor_word_s,
      done_o=>open, overflow_o=>descriptor_overflow_s);

  main_proc : process(clock_i)
    variable pending_head : frame_meta_t;
    variable head, tail, count : natural range 0 to FRAME_QUEUE_DEPTH_C;
    variable reserved, published : natural range 0 to PACKET_SLOT_COUNT_C;
    variable active_valid, header_pending : std_logic;
    variable req : frame_meta_t;
    variable req_valid, req_cont, req_first, accepted, covered : boolean;
    variable event_end_seq, candidate_start_seq : sample_seq_t;
    variable age : natural range 0 to RING_DEPTH_C+1;
    variable workload : natural range 0 to 5*SERIALIZER_CYCLES_C;
    variable wait_cycles : natural range 0 to 511;
    variable quiet_next, quiet_limit : natural range 0 to 511;
    variable min_spacing : natural range 1 to 512;
    variable residual : integer range -16383 to 16383;
    variable activity_next : std_logic;
  begin
    if rising_edge(clock_i) then
      if reset_i='1' then
        seq_s<=(others=>'0'); history_s<=0; head_s<=0; tail_s<=0; queue_count_s<=0;
        timestamp_previous_s<=(others=>'0'); timestamp_armed_s<='0';
        active_s<=META_NULL_C; active_valid_s<='0'; fetch_running_s<='0'; sample_valid_s<='0';
        fetch_index_s<=(others=>'0'); sample_index_s<=(others=>'0');
        header_pending_s<='0'; header_meta_s<=META_NULL_C;
        allocate_slot_s<=(others=>'0'); read_slot_s<=(others=>'0');
        reserved_count_s<=0; published_count_s<=0; read_word_s<=0;
        header_s<=0; payload_word_s<=0;
        chain_active_s<='0'; current_accepted_s<='0'; previous_accepted_s<='0';
        current_s<=META_NULL_C; previous_s<=META_NULL_C; activity_s<='0'; quiet_s<=0; chain_quiet_limit_s<=32;
        required_end_s<=(others=>'0'); last_start_s<=(others=>'0'); last_start_valid_s<='0'; trigger_previous_s<='0';
        record_count_s<=(others=>'0'); full_count_s<=(others=>'0'); busy_count_s<=(others=>'0');
        spacing_count_s<=(others=>'0'); queue_drop_s<=(others=>'0'); ring_drop_s<=(others=>'0');
        trigger_count_s<=(others=>'0'); packet_count_s<=(others=>'0'); continuation_count_s<=(others=>'0');
        continuation_drop_s<=(others=>'0'); covered_count_s<=(others=>'0'); descriptor_overflow_count_s<=(others=>'0');
      else
        pending_head:=queue_head_s; head:=head_s; tail:=tail_s; count:=queue_count_s;
        reserved:=reserved_count_s; published:=published_count_s;
        active_valid:=active_valid_s; header_pending:=header_pending_s;
        seq_s<=seq_s+1;
        timestamp_previous_s<=unsigned(timestamp_i); timestamp_armed_s<='1';
        -- Expire the spacing reference before the local modulo sample counter
        -- can wrap and make an ancient fragment appear recent again.
        if last_start_valid_s='1' and seq_age(seq_s,last_start_s)>RING_DEPTH_C then
          last_start_valid_s<='0';
        end if;
        if current_accepted_s='1' and seq_age(seq_s,current_s.start_seq)>RING_DEPTH_C then
          current_accepted_s<='0';
        end if;
        if previous_accepted_s='1' and seq_age(seq_s,previous_s.start_seq)>RING_DEPTH_C then
          previous_accepted_s<='0';
        end if;
        if history_s<RING_DEPTH_C then history_s<=history_s+1; end if;
        if timestamp_jump_s='1' then
          -- Start a new admission epoch; reserved packet ownership and the
          -- uninterrupted raw-sample ring/serializer keep draining unchanged.
          history_s<=0; current_accepted_s<='0'; previous_accepted_s<='0'; last_start_valid_s<='0';
        end if;
        trigger_previous_s<=trigger_i.trigger_pulse;
        if trigger_i.trigger_pulse='1' and trigger_previous_s='0' and enable_i='1' then
          trigger_count_s<=trigger_count_s+1;
        end if;
        -- Releasing or skipping a slot is the sole operation returning a credit.
        if consume_drop_s='1' then
          read_slot_s<=read_slot_s+1; read_word_s<=0; reserved:=reserved-1; published:=published-1;
        elsif rd_en_i='1' and published_count_s>0 and dropped_s(to_integer(read_slot_s))='0' then
          if read_word_s=FRAME_WORD_COUNT_C-1 then
            read_slot_s<=read_slot_s+1; read_word_s<=0;
            reserved:=reserved-1; published:=published-1;
          else read_word_s<=read_word_s+1; end if;
        end if;
        -- Header publication can overlap the next fragment's BRAM stream.
        -- Payload words win the single URAM write port; eight headers finish
        -- within nine clocks after sample511 during a contiguous stream.
        if header_pending_s='1' and payload_wr_s='0' then
          if header_s=7 then
            published:=published+1; header_pending:='0'; record_count_s<=record_count_s+1;
            if descriptor_overflow_s='1' then descriptor_overflow_count_s<=descriptor_overflow_count_s+1; end if;
          else header_s<=header_s+1; end if;
        end if;
        -- The completed descriptor RAM bank stays readable until the next
        -- sample511, so headers need no separate wide trailer snapshot.
        if sample_valid_s='1' then
          pack_shift_s<=pack_window_s(77 downto 14);
          if payload_wr_s='1' then
            if sample_index_s=511 then payload_word_s<=0;
            else payload_word_s<=payload_word_s+1; end if;
          end if;
          if sample_index_s=511 then
            assert header_pending_s='0' report "header writer overran one fragment" severity failure;
            header_meta_s<=active_s; header_s<=0; header_pending:='1'; active_valid:='0';
          end if;
        end if;
        -- Admitted work continues to drain while acquisition is disabled.
        -- Launch sample0 at the edge consuming the previous sample511 to
        -- achieve an exact 512-clock initiation interval without an idle gap.
        sample_valid_s<=fetch_running_s or launch_s;
        if launch_s='1' then
          active_s<=pending_head; active_valid:='1'; fetch_running_s<='1';
          fetch_index_s<=to_unsigned(1,9); sample_index_s<=(others=>'0');
          head:=next_q(head); count:=count-1; pending_head:=queue_next_s;
        elsif fetch_running_s='1' then
          sample_index_s<=fetch_index_s;
          if fetch_index_s=511 then fetch_running_s<='0';
          else fetch_index_s<=fetch_index_s+1; end if;
        elsif publish_drop_s='1' then
          published:=published+1;
          ring_drop_s<=ring_drop_s+1; busy_count_s<=busy_count_s+1;
          if pending_head.continuation='1' then continuation_drop_s<=continuation_drop_s+1; end if;
          head:=next_q(head); count:=count-1; pending_head:=queue_next_s;
        end if;

        req:=META_NULL_C; req_valid:=false; req_cont:=false; req_first:=false;
        quiet_next:=quiet_s; activity_next:=activity_s;
        -- Evaluate the inclusive final sample before deciding the next fragment.
        if chain_active_s='1' and enable_i='1' and continuation_enable_i='1' and timestamp_jump_s='0' then
          if current_s.positive_pulse='1' then residual:=to_integer(unsigned(din_i))-to_integer(unsigned(activity_baseline_s));
          else residual:=to_integer(unsigned(activity_baseline_s))-to_integer(unsigned(din_i)); end if;
          if activity_s='0' and residual>=to_integer(unsigned(current_s.activity_threshold)) then activity_next:='1';
          elsif activity_s='1' and residual<=to_integer(unsigned(current_s.activity_threshold))/2 then activity_next:='0'; end if;
          if activity_next='1' then quiet_next:=0;
          elsif quiet_next<chain_quiet_limit_s then quiet_next:=quiet_next+1; end if;
          activity_s<=activity_next; quiet_s<=quiet_next;
          if seq_s-current_s.start_seq>=511 then
            -- A satisfied deadline may otherwise age through the signed
            -- half-range during a long tail. Advancing it to the frame end
            -- preserves whether more posttrigger samples are still required.
            if signed(required_end_s-(current_s.start_seq+511))<=0 then
              required_end_s<=current_s.start_seq+511;
            end if;
            if quiet_next<chain_quiet_limit_s or signed(required_end_s-(current_s.start_seq+511))>0 then
              req:=current_s; req.start_seq:=current_s.start_seq+512;
              req.sample0_ts:=std_logic_vector(unsigned(current_s.sample0_ts)+512);
              req.continuation:='1'; req.trigger_sample:=din_i;
              req_valid:=true; req_cont:=true;
              previous_s<=current_s; previous_accepted_s<=current_accepted_s;
              current_s<=req; current_accepted_s<='0';
            else chain_active_s<='0'; end if;
          end if;
        elsif enable_i='0' or continuation_enable_i='0' or timestamp_jump_s='1' then
          chain_active_s<='0'; activity_s<='0'; quiet_s<=0;
        end if;

        if event_pulse_s='1' and enable_i='1' then
          -- Supported tuples arrive at most447 clocks after the trigger;
          -- jump-edge/older/future tuples are whole losses before local matching.
          if timestamp_jump_s='1' or event_age_s>447 then
            ring_drop_s<=ring_drop_s+1; busy_count_s<=busy_count_s+1;
          else
            covered := (current_accepted_s='1' and seq_age(seq_s,current_s.start_seq)<=RING_DEPTH_C and
                        inside_window(current_delta_s,continuation_enable_i)) or
                       (previous_accepted_s='1' and seq_age(seq_s,previous_s.start_seq)<=RING_DEPTH_C and
                        inside_window(previous_delta_s,continuation_enable_i));
            if covered then
              covered_count_s<=covered_count_s+1;
              -- A coalesced trigger still owns its complete trigger..trigger+447
              -- posttrigger interval. Delayed trigger delivery may reopen the
              -- last quiet-closed chain from retained samples, without shifting
              -- its 512-sample grid or adding another pretrigger region.
              if continuation_enable_i='1' then
                event_end_seq:=event_seq_s+447;
                if signed(event_end_seq-required_end_s)>0 then required_end_s<=event_end_seq; end if;
                if signed(event_end_seq-(current_s.start_seq+511))>0 and
                   seq_s-current_s.start_seq>=511 and not req_valid then
                  req:=current_s; req.start_seq:=current_s.start_seq+512;
                  req.sample0_ts:=std_logic_vector(unsigned(current_s.sample0_ts)+512);
                  req.continuation:='1'; req.trigger_sample:=event_sample_s;
                  req_valid:=true; req_cont:=true;
                  previous_s<=current_s; previous_accepted_s<=current_accepted_s;
                  current_s<=req; current_accepted_s<='0'; chain_active_s<='1';
                end if;
              end if;
            elsif chain_active_s='1' or req_valid then
              -- A trigger in a denied fragment does not shift the chain grid.
              busy_count_s<=busy_count_s+1;
            else
              age:=to_integer(event_age_s(8 downto 0))+PRETRIGGER_SAMPLES_C;
              min_spacing:=512;
              if continuation_enable_i='0' then min_spacing:=512-to_integer(unsigned(signal_delay_i))*16; end if;
              candidate_start_seq:=seq_s-to_unsigned(age,sample_seq_t'length);
              if age>history_s then
                ring_drop_s<=ring_drop_s+1; busy_count_s<=busy_count_s+1;
              elsif last_start_valid_s='1' and seq_age(seq_s,last_start_s)<=RING_DEPTH_C and
                    signed(candidate_start_seq-last_start_s)<to_signed(min_spacing,sample_seq_t'length) then
                spacing_count_s<=spacing_count_s+1; busy_count_s<=busy_count_s+1;
              else
                req:=META_NULL_C; req.start_seq:=seq_s-to_unsigned(age,sample_seq_t'length);
                req.sample0_ts:=std_logic_vector(unsigned(event_timestamp_s)-64);
                req.baseline:=trigger_i.baseline;
                req.trigger_sample:=event_sample_s; req.threshold_lsb:=threshold_xc_i(13 downto 0);
                req.activity_threshold:=activity_threshold_i;
                if unsigned(activity_threshold_i)=0 then req.activity_threshold:=std_logic_vector(to_unsigned(1,14)); end if;
                req.positive_pulse:=positive_pulse_i; req.calibration_tag:=event_tag_s;
                req_valid:=true; req_first:=true;
              end if;
            end if;
          end if;
        end if;
        if req_valid then
          age:=seq_age(seq_s,req.start_seq);
          -- A power-of-two service bound needs only a shift. Header writes
          -- overlap the sample stream; the retention margin covers an idle
          -- stale-head publication waiting for the previous header to finish.
          workload:=count*SERIALIZER_CYCLES_C;
          if active_valid='1' then workload:=workload+SERIALIZER_CYCLES_C; end if;
          wait_cycles:=0;
          if active_valid='0' and count>0 and seq_age(seq_s,pending_head.start_seq)<511 then
            wait_cycles:=511-seq_age(seq_s,pending_head.start_seq);
          end if;
          accepted:=false;
          if reserved=PACKET_SLOT_COUNT_C then full_count_s<=full_count_s+1;
          elsif count=FRAME_QUEUE_DEPTH_C then queue_drop_s<=queue_drop_s+1; busy_count_s<=busy_count_s+1;
          elsif age+workload+wait_cycles>RETENTION_LIMIT_C then ring_drop_s<=ring_drop_s+1; busy_count_s<=busy_count_s+1;
          else
            req.slot:=allocate_slot_s;
            allocate_slot_s<=allocate_slot_s+1; reserved:=reserved+1;
            queue_s(tail_s)<=pack_meta(req); tail:=next_q(tail); count:=count+1; accepted:=true;
            packet_count_s<=packet_count_s+1; last_start_s<=req.start_seq; last_start_valid_s<='1';
            if req_cont then continuation_count_s<=continuation_count_s+1; end if;
          end if;
          if req_cont then
            if accepted then current_s<=req; current_accepted_s<='1';
            else continuation_drop_s<=continuation_drop_s+1; end if;
          elsif req_first and accepted then
            previous_s<=current_s; previous_accepted_s<=current_accepted_s;
            current_s<=req; current_accepted_s<='1';
            chain_active_s<=continuation_enable_i; activity_s<='0'; quiet_s<=0;
            required_end_s<=req.start_seq+511;
            quiet_limit:=to_integer(unsigned(quiet_samples_i));
            if quiet_limit=0 then quiet_limit:=1; end if;
            chain_quiet_limit_s<=quiet_limit;
          end if;
        end if;
        -- Counter reset is deliberately independent of acquisition state: it
        -- cannot leave a partial packet in the transport stream.
        if reset_st_counters_i='1' then
          record_count_s<=(others=>'0'); full_count_s<=(others=>'0'); busy_count_s<=(others=>'0');
          spacing_count_s<=(others=>'0'); queue_drop_s<=(others=>'0'); ring_drop_s<=(others=>'0');
          trigger_count_s<=(others=>'0'); packet_count_s<=(others=>'0'); continuation_count_s<=(others=>'0');
          continuation_drop_s<=(others=>'0'); covered_count_s<=(others=>'0'); descriptor_overflow_count_s<=(others=>'0');
        end if;
        -- synthesis translate_off
        workload:=0;
        if active_valid='1' then workload:=workload+1; end if;
        if header_pending='1' then workload:=workload+1; end if;
        assert reserved=published+count+workload report "packet reservation conservation failed" severity failure;
        -- synthesis translate_on
        head_s<=head; tail_s<=tail; queue_count_s<=count;
        reserved_count_s<=reserved; published_count_s<=published; active_valid_s<=active_valid;
        header_pending_s<=header_pending;
      end if;
    end if;
  end process;
  record_count_o<=std_logic_vector(resize(record_count_s,64));
  full_count_o<=std_logic_vector(resize(full_count_s,64));
  busy_count_o<=std_logic_vector(resize(busy_count_s,64));
  spacing_reject_count_o<=std_logic_vector(resize(spacing_count_s,64));
  queue_reject_count_o<=std_logic_vector(resize(queue_drop_s,64));
  ring_reject_count_o<=std_logic_vector(resize(ring_drop_s,64));
  output_reject_count_o<=std_logic_vector(resize(full_count_s,64));
  trigger_count_o<=std_logic_vector(resize(trigger_count_s,64));
  packet_count_o<=std_logic_vector(resize(packet_count_s,64));
  continuation_count_o<=std_logic_vector(resize(continuation_count_s,64));
  continuation_drop_count_o<=std_logic_vector(resize(continuation_drop_s,64));
  covered_trigger_count_o<=std_logic_vector(resize(covered_count_s,64));
  descriptor_overflow_count_o<=std_logic_vector(resize(descriptor_overflow_count_s,64));
end architecture;
