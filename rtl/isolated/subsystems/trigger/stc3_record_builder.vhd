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
  constant SERIALIZER_CYCLES_C : positive := 393;
  constant RETENTION_LIMIT_C : positive := RING_DEPTH_C - 64;
  subtype sample_seq_t is unsigned(31 downto 0);
  subtype slot_t is unsigned(4 downto 0);
  type sample_block_t is array(0 to 31) of std_logic_vector(13 downto 0);
  type serializer_state_t is (ser_idle, ser_load, ser_emit, ser_header);
  type slot_state_t is (slot_free, slot_reserved, slot_complete, slot_dropped);
  type slot_state_array_t is array(0 to PACKET_SLOT_COUNT_C-1) of slot_state_t;
  type frame_meta_t is record
    start_seq : sample_seq_t;
    sample0_ts : std_logic_vector(63 downto 0);
    baseline : std_logic_vector(13 downto 0);
    raw_baseline : std_logic_vector(13 downto 0);
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
    raw_baseline=>(others=>'0'), trigger_sample=>(others=>'0'), threshold_lsb=>(others=>'0'),
    activity_threshold=>(others=>'0'), positive_pulse=>'0', calibration_tag=>CALIBRATION_TAG_NORMAL_C,
    continuation=>'0', slot=>(others=>'0'));
  type frame_queue_t is array(0 to FRAME_QUEUE_DEPTH_C-1) of frame_meta_t;
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
  function inside_window(ts : std_logic_vector(63 downto 0); m : frame_meta_t) return boolean is
  begin return unsigned(ts)-unsigned(m.sample0_ts) < to_unsigned(FRAME_SAMPLE_COUNT_C,64); end;
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

  signal seq_s : sample_seq_t := (others=>'0');
  signal history_s : natural range 0 to RING_DEPTH_C := 0;
  signal queue_s : frame_queue_t := (others=>META_NULL_C);
  signal head_s, tail_s : natural range 0 to FRAME_QUEUE_DEPTH_C-1 := 0;
  signal queue_count_s : natural range 0 to FRAME_QUEUE_DEPTH_C := 0;
  signal queue_head_s : frame_meta_t;
  signal active_s : frame_meta_t := META_NULL_C;
  signal active_valid_s : std_logic := '0';
  signal state_s : serializer_state_t := ser_idle;
  signal slots_s : slot_state_array_t := (others=>slot_free);
  signal allocate_slot_s, read_slot_s : slot_t := (others=>'0');
  signal reserved_count_s, complete_count_s : natural range 0 to PACKET_SLOT_COUNT_C := 0;
  signal read_word_s : natural range 0 to FRAME_WORD_COUNT_C-1 := 0;
  signal block_s : natural range 0 to 15 := 0;
  signal load_s : natural range 0 to 16 := 0;
  signal emit_s : natural range 0 to 6 := 0;
  signal header_s : natural range 0 to 7 := 0;
  signal samples_s : sample_block_t := (others=>(others=>'0'));
  signal ring_addr_s : unsigned(10 downto 0);
  signal ring_data0_s, ring_data1_s : std_logic_vector(13 downto 0);
  signal store_wr_s : std_logic;
  signal store_waddr_s, store_raddr_s : unsigned(11 downto 0);
  signal store_din_s : std_logic_vector(71 downto 0);
  signal descriptor_start_s, descriptor_pair_valid_s, descriptor_done_s, descriptor_overflow_s : std_logic;
  signal descriptor_pair_idx_s : unsigned(7 downto 0);
  signal descriptor_trailer_s, active_trailer_s : peak_descriptor_trailer_t := PEAK_DESCRIPTOR_TRAILER_NULL;
  signal active_descriptor_overflow_s : std_logic := '0';
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
  signal event_sample_s : std_logic_vector(13 downto 0);
  signal event_tag_s : std_logic_vector(1 downto 0);
  signal record_count_s, full_count_s, busy_count_s, spacing_count_s, queue_drop_s, ring_drop_s,
         trigger_count_s, packet_count_s, continuation_count_s, continuation_drop_s,
         covered_count_s, descriptor_overflow_count_s : unsigned(31 downto 0) := (others=>'0');
begin
  queue_head_s <= queue_s(head_s);
  event_pulse_s <= trigger_i.trigger_pulse or force_trigger_i;
  event_timestamp_s <= timestamp_i when force_trigger_i='1' else trigger_i.trigger_timestamp;
  event_sample_s <= din_i when force_trigger_i='1' else trigger_i.trigger_sample;
  event_tag_s <= force_calibration_tag_i when force_trigger_i='1' else trigger_i.calibration_tag;
  -- Kept for legacy diagnostic calculator compatibility; packet descriptors use
  -- explicit fragment-local start/pair-valid handshakes below.
  frame_match_o <= '1' when enable_i='1' and queue_count_s<FRAME_QUEUE_DEPTH_C and
                   reserved_count_s<PACKET_SLOT_COUNT_C else '0';
  delayed_sample_o <= din_i;
  ready_o <= '1' when complete_count_s>0 and slots_s(to_integer(read_slot_s))=slot_complete else '0';

  ring_addr_s <= active_s.start_seq(10 downto 0)+to_unsigned(block_s*32+load_s*2,11)
                 when state_s=ser_load and load_s<16 else active_s.start_seq(10 downto 0);
  ring_inst : entity work.sample_ring_buffer
    generic map(DATA_WIDTH_G=>14, DEPTH_G=>RING_DEPTH_C, ADDR_WIDTH_G=>11)
    port map(clock_i=>clock_i, wr_en_i=>not reset_i, wr_addr_i=>seq_s(10 downto 0), din_i=>din_i,
             rd_addr_i=>ring_addr_s, dout_o=>ring_data0_s, dout_next_o=>ring_data1_s);
  store_inst : entity work.packet_frame_store
    port map(clock_i=>clock_i, wr_en_i=>store_wr_s, wr_addr_i=>store_waddr_s,
             din_i=>store_din_s, rd_addr_i=>store_raddr_s, dout_o=>dout_o);
  store_rd_addr_proc : process(all)
  begin
    store_raddr_s <= slot_addr(read_slot_s,read_word_s);
    if slots_s(to_integer(read_slot_s))=slot_dropped then
      store_raddr_s <= slot_addr(read_slot_s+1,0);
    elsif rd_en_i='1' and slots_s(to_integer(read_slot_s))=slot_complete then
      if read_word_s=FRAME_WORD_COUNT_C-1 then store_raddr_s<=slot_addr(read_slot_s+1,0);
      else store_raddr_s<=slot_addr(read_slot_s,read_word_s+1); end if;
    end if;
  end process;
  store_wr_s <= '1' when reset_i='0' and (state_s=ser_emit or state_s=ser_header) else '0';
  store_waddr_s <= slot_addr(active_s.slot,8+block_s*7+emit_s) when state_s=ser_emit
                   else slot_addr(active_s.slot,header_s);
  store_data_proc : process(all)
  begin
    store_din_s <= (others=>'0');
    if state_s=ser_emit then
      store_din_s(63 downto 0)<=pack_block_word(samples_s,emit_s);
      if block_s=15 and emit_s=6 then store_din_s(71 downto 64)<=X"ED"; end if;
    elsif state_s=ser_header then
      case header_s is
        when 0 => store_din_s<=X"BE" & active_s.sample0_ts;
        when 1 => store_din_s<=X"00" & ch_id_i & version_i & active_s.continuation & '1' &
                    active_descriptor_overflow_s & '0' & active_s.calibration_tag & active_s.baseline &
                    "00" & active_s.threshold_lsb & "00" & active_s.trigger_sample;
        when others => store_din_s<=X"00" & active_trailer_s((header_s-2)*2+1) & active_trailer_s((header_s-2)*2);
      end case;
    end if;
  end process;
  descriptor_start_s <= '1' when state_s=ser_idle and queue_count_s>0 and
      seq_age(seq_s,queue_s(head_s).start_seq)>=511 and
      seq_age(seq_s,queue_s(head_s).start_seq)<=RETENTION_LIMIT_C else '0';
  descriptor_pair_valid_s <= '1' when state_s=ser_load and load_s>0 else '0';
  descriptor_pair_idx_s <= to_unsigned(block_s*16+load_s-1,8) when load_s>0 else (others=>'0');
  descriptor_inst : entity work.fragment_peak_descriptors
    port map(clock_i=>clock_i, reset_i=>reset_i, start_i=>descriptor_start_s,
      baseline_i=>queue_head_s.raw_baseline,
      positive_pulse_i=>queue_head_s.positive_pulse,
      threshold_i=>queue_head_s.activity_threshold,
      pair_valid_i=>descriptor_pair_valid_s, sample0_i=>ring_data0_s, sample1_i=>ring_data1_s,
      pair_index_i=>descriptor_pair_idx_s, trailer_o=>descriptor_trailer_s, done_o=>descriptor_done_s,
      overflow_o=>descriptor_overflow_s);

  main_proc : process(clock_i)
    variable q : frame_queue_t;
    variable head, tail, count : natural range 0 to FRAME_QUEUE_DEPTH_C;
    variable slots : slot_state_array_t;
    variable reserved, complete : natural range 0 to PACKET_SLOT_COUNT_C;
    variable active_valid : std_logic;
    variable req : frame_meta_t;
    variable req_valid, req_cont, req_first, accepted, covered : boolean;
    variable trigger_age64 : unsigned(63 downto 0);
    variable event_end_seq, candidate_start_seq : sample_seq_t;
    variable age, workload, wait_cycles, quiet_next, quiet_limit, min_spacing : natural;
    variable residual : integer range -16383 to 16383;
    variable activity_next : std_logic;
  begin
    if rising_edge(clock_i) then
      if reset_i='1' then
        seq_s<=(others=>'0'); history_s<=0; queue_s<=(others=>META_NULL_C); head_s<=0; tail_s<=0; queue_count_s<=0;
        active_s<=META_NULL_C; active_valid_s<='0'; state_s<=ser_idle;
        slots_s<=(others=>slot_free); allocate_slot_s<=(others=>'0'); read_slot_s<=(others=>'0');
        reserved_count_s<=0; complete_count_s<=0; read_word_s<=0;
        block_s<=0; load_s<=0; emit_s<=0; header_s<=0; samples_s<=(others=>(others=>'0'));
        active_trailer_s<=PEAK_DESCRIPTOR_TRAILER_NULL; active_descriptor_overflow_s<='0';
        chain_active_s<='0'; current_accepted_s<='0'; previous_accepted_s<='0';
        current_s<=META_NULL_C; previous_s<=META_NULL_C; activity_s<='0'; quiet_s<=0; chain_quiet_limit_s<=32;
        required_end_s<=(others=>'0'); last_start_s<=(others=>'0'); last_start_valid_s<='0'; trigger_previous_s<='0';
        record_count_s<=(others=>'0'); full_count_s<=(others=>'0'); busy_count_s<=(others=>'0');
        spacing_count_s<=(others=>'0'); queue_drop_s<=(others=>'0'); ring_drop_s<=(others=>'0');
        trigger_count_s<=(others=>'0'); packet_count_s<=(others=>'0'); continuation_count_s<=(others=>'0');
        continuation_drop_s<=(others=>'0'); covered_count_s<=(others=>'0'); descriptor_overflow_count_s<=(others=>'0');
      else
        q:=queue_s; head:=head_s; tail:=tail_s; count:=queue_count_s;
        slots:=slots_s; reserved:=reserved_count_s; complete:=complete_count_s;
        active_valid:=active_valid_s;
        seq_s<=seq_s+1;
        -- Expire the spacing reference before the32-bit local sample counter
        -- can wrap and make an ancient fragment appear recent again.
        if last_start_valid_s='1' and seq_age(seq_s,last_start_s)>RING_DEPTH_C then
          last_start_valid_s<='0';
        end if;
        if history_s<RING_DEPTH_C then history_s<=history_s+1; end if;
        trigger_previous_s<=trigger_i.trigger_pulse;
        if trigger_i.trigger_pulse='1' and trigger_previous_s='0' and enable_i='1' then
          trigger_count_s<=trigger_count_s+1;
        end if;
        -- Releasing or skipping a slot is the sole operation returning a credit.
        if slots(to_integer(read_slot_s))=slot_dropped then
          slots(to_integer(read_slot_s)):=slot_free; read_slot_s<=read_slot_s+1; read_word_s<=0; reserved:=reserved-1;
        elsif rd_en_i='1' and slots(to_integer(read_slot_s))=slot_complete then
          if read_word_s=FRAME_WORD_COUNT_C-1 then
            slots(to_integer(read_slot_s)):=slot_free; read_slot_s<=read_slot_s+1; read_word_s<=0;
            reserved:=reserved-1; complete:=complete-1;
          else read_word_s<=read_word_s+1; end if;
        end if;
        -- Serialization drains admitted work even when acquisition is disabled.
        case state_s is
          when ser_idle =>
            if count>0 then
              age:=seq_age(seq_s,q(head).start_seq);
              if age>RETENTION_LIMIT_C then
                slots(to_integer(q(head).slot)):=slot_dropped;
                ring_drop_s<=ring_drop_s+1; busy_count_s<=busy_count_s+1;
                if q(head).continuation='1' then continuation_drop_s<=continuation_drop_s+1; end if;
                head:=next_q(head); count:=count-1;
              elsif age>=511 then
                active_s<=q(head); active_valid:='1'; block_s<=0; load_s<=0; emit_s<=0;
                state_s<=ser_load; head:=next_q(head); count:=count-1;
              end if;
            end if;
          when ser_load =>
            if load_s=0 then load_s<=1;
            else
              samples_s((load_s-1)*2)<=ring_data0_s; samples_s((load_s-1)*2+1)<=ring_data1_s;
              if load_s=16 then emit_s<=0; state_s<=ser_emit;
              else load_s<=load_s+1; end if;
            end if;
          when ser_emit =>
            if emit_s=6 then
              if block_s=15 then
                active_trailer_s<=descriptor_trailer_s; active_descriptor_overflow_s<=descriptor_overflow_s;
                header_s<=0; state_s<=ser_header;
              else block_s<=block_s+1; load_s<=0; state_s<=ser_load; end if;
            else emit_s<=emit_s+1; end if;
          when ser_header =>
            if header_s=7 then
              slots(to_integer(active_s.slot)):=slot_complete; complete:=complete+1;
              active_valid:='0'; state_s<=ser_idle; record_count_s<=record_count_s+1;
              if active_descriptor_overflow_s='1' then descriptor_overflow_count_s<=descriptor_overflow_count_s+1; end if;
            else header_s<=header_s+1; end if;
        end case;

        req:=META_NULL_C; req_valid:=false; req_cont:=false; req_first:=false;
        quiet_next:=quiet_s; activity_next:=activity_s;
        -- Evaluate the inclusive final sample before deciding the next fragment.
        if chain_active_s='1' and enable_i='1' and continuation_enable_i='1' then
          if current_s.positive_pulse='1' then residual:=to_integer(unsigned(din_i))-to_integer(unsigned(current_s.raw_baseline));
          else residual:=to_integer(unsigned(current_s.raw_baseline))-to_integer(unsigned(din_i)); end if;
          if activity_s='0' and residual>=to_integer(unsigned(current_s.activity_threshold)) then activity_next:='1';
          elsif activity_s='1' and residual<=to_integer(unsigned(current_s.activity_threshold))/2 then activity_next:='0'; end if;
          if activity_next='1' then quiet_next:=0;
          elsif quiet_next<chain_quiet_limit_s then quiet_next:=quiet_next+1; end if;
          activity_s<=activity_next; quiet_s<=quiet_next;
          if seq_s-current_s.start_seq>=511 then
            if quiet_next<chain_quiet_limit_s or signed(required_end_s-(current_s.start_seq+511))>0 then
              req:=current_s; req.start_seq:=current_s.start_seq+512;
              req.sample0_ts:=std_logic_vector(unsigned(current_s.sample0_ts)+512);
              req.continuation:='1'; req.trigger_sample:=din_i;
              req_valid:=true; req_cont:=true;
              previous_s<=current_s; previous_accepted_s<=current_accepted_s;
              current_s<=req; current_accepted_s<='0';
            else chain_active_s<='0'; end if;
          end if;
        elsif enable_i='0' or continuation_enable_i='0' then
          chain_active_s<='0'; activity_s<='0'; quiet_s<=0;
        end if;

        if event_pulse_s='1' and enable_i='1' then
          covered := (current_accepted_s='1' and inside_window(event_timestamp_s,current_s)) or
                     (previous_accepted_s='1' and inside_window(event_timestamp_s,previous_s));
          -- A new trigger can arrive just after a quiet-closed fragment while
          -- its 64-sample pretrigger region still overlaps that fragment. Keep
          -- the existing grid and extend its union rather than reject it for
          -- seed spacing. With continuation disabled retain legacy spacing.
          if continuation_enable_i='1' then
            covered := covered or
              (current_accepted_s='1' and inside_window(std_logic_vector(unsigned(event_timestamp_s)-64),current_s)) or
              (previous_accepted_s='1' and inside_window(std_logic_vector(unsigned(event_timestamp_s)-64),previous_s));
          end if;
          if covered then
            covered_count_s<=covered_count_s+1;
            -- A coalesced trigger still owns its complete trigger..trigger+447
            -- posttrigger interval. Delayed trigger delivery may reopen the
            -- last quiet-closed chain from retained samples, without shifting
            -- its 512-sample grid or adding another pretrigger region.
            trigger_age64:=unsigned(timestamp_i)-unsigned(event_timestamp_s);
            if continuation_enable_i='1' and trigger_age64<=447 then
              event_end_seq:=seq_s-resize(trigger_age64,32)+447;
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
            trigger_age64:=unsigned(timestamp_i)-unsigned(event_timestamp_s);
            if trigger_age64>to_unsigned(RING_DEPTH_C-PRETRIGGER_SAMPLES_C,64) then
              ring_drop_s<=ring_drop_s+1; busy_count_s<=busy_count_s+1;
            else
              age:=to_integer(trigger_age64)+PRETRIGGER_SAMPLES_C;
              min_spacing:=512;
              if continuation_enable_i='0' then min_spacing:=512-to_integer(unsigned(signal_delay_i))*16; end if;
              candidate_start_seq:=seq_s-to_unsigned(age,32);
              if age>history_s or age>511 then
                ring_drop_s<=ring_drop_s+1; busy_count_s<=busy_count_s+1;
              elsif last_start_valid_s='1' and seq_age(seq_s,last_start_s)<=RING_DEPTH_C and
                    signed(candidate_start_seq-last_start_s)<to_signed(min_spacing,32) then
                spacing_count_s<=spacing_count_s+1; busy_count_s<=busy_count_s+1;
              else
                req:=META_NULL_C; req.start_seq:=seq_s-to_unsigned(age,32);
                req.sample0_ts:=std_logic_vector(unsigned(event_timestamp_s)-64);
                req.baseline:=trigger_i.baseline; req.raw_baseline:=trigger_i.baseline;
                if positive_pulse_i='1' then req.raw_baseline:=std_logic_vector(to_unsigned(0,14)-unsigned(trigger_i.baseline)); end if;
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
          workload:=count*SERIALIZER_CYCLES_C;
          if active_valid='1' then workload:=workload+SERIALIZER_CYCLES_C; end if;
          wait_cycles:=0;
          if active_valid='0' and count>0 and seq_age(seq_s,q(head).start_seq)<511 then
            wait_cycles:=511-seq_age(seq_s,q(head).start_seq);
          end if;
          accepted:=false;
          if reserved=PACKET_SLOT_COUNT_C then full_count_s<=full_count_s+1;
          elsif count=FRAME_QUEUE_DEPTH_C then queue_drop_s<=queue_drop_s+1; busy_count_s<=busy_count_s+1;
          elsif age+workload+wait_cycles>RETENTION_LIMIT_C then ring_drop_s<=ring_drop_s+1; busy_count_s<=busy_count_s+1;
          else
            req.slot:=allocate_slot_s;
            assert slots(to_integer(allocate_slot_s))=slot_free report "packet reservation reused a live slot" severity failure;
            slots(to_integer(allocate_slot_s)):=slot_reserved;
            allocate_slot_s<=allocate_slot_s+1; reserved:=reserved+1;
            q(tail):=req; tail:=next_q(tail); count:=count+1; accepted:=true;
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
        queue_s<=q; head_s<=head; tail_s<=tail; queue_count_s<=count;
        slots_s<=slots; reserved_count_s<=reserved; complete_count_s<=complete; active_valid_s<=active_valid;
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
