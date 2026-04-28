library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity stc3_frame_source is
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
    desc_valid_o             : out std_logic;
    desc_o                   : out stc3_frame_descriptor_t;
    desc_trailer_o           : out peak_descriptor_trailer_t;
    desc_taken_i             : in  std_logic;
    ring_rd_addr_i           : in  std_logic_vector(10 downto 0);
    ring_dout_o              : out std_logic_vector(13 downto 0)
  );
end entity stc3_frame_source;

architecture rtl of stc3_frame_source is
  constant LIVE_COUNTER_WIDTH_C  : positive := 16;
  constant PRETRIGGER_SAMPLES_C  : natural := 64;
  constant FRAME_SAMPLE_COUNT_C  : natural := 512;
  constant RING_DEPTH_C          : positive := 2048;
  constant RING_ADDR_WIDTH_C     : positive := 11;
  constant FRAME_QUEUE_DEPTH_C   : positive := 4;
  constant OVERLAP_GRANULARITY_C : natural := 16;

  subtype ring_addr_t is unsigned(RING_ADDR_WIDTH_C - 1 downto 0);
  type trigger_counter_state_type is (rst_trggr, wait4trig_trggr, rising_triggered);
  type frame_desc_array_t is array (0 to FRAME_QUEUE_DEPTH_C - 1) of stc3_frame_descriptor_t;

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

  function overlap_samples_cfg(signal_delay : std_logic_vector(4 downto 0)) return natural is
    variable overlap_v : natural;
  begin
    overlap_v := to_integer(unsigned(signal_delay)) * OVERLAP_GRANULARITY_C;
    if overlap_v > FRAME_SAMPLE_COUNT_C - 1 then
      overlap_v := FRAME_SAMPLE_COUNT_C - 1;
    end if;
    return overlap_v;
  end function;

  signal trig_count_state_s     : trigger_counter_state_type := rst_trggr;
  signal write_ptr_s            : ring_addr_t := (others => '0');
  signal ring_dout_s            : std_logic_vector(13 downto 0);
  signal frame_queue_s          : frame_desc_array_t := (others => STC3_FRAME_DESCRIPTOR_NULL);
  signal frame_queue_head_s     : integer range 0 to FRAME_QUEUE_DEPTH_C - 1 := 0;
  signal frame_queue_tail_s     : integer range 0 to FRAME_QUEUE_DEPTH_C - 1 := 0;
  signal frame_queue_count_s    : integer range 0 to FRAME_QUEUE_DEPTH_C := 0;
  signal trailer_reg_s          : peak_descriptor_trailer_t := PEAK_DESCRIPTOR_TRAILER_NULL;
  signal event_pulse_s          : std_logic;
  signal overlap_samples_s      : natural range 0 to FRAME_SAMPLE_COUNT_C - 1 := 0;
  signal min_trigger_spacing_s  : natural range 1 to FRAME_SAMPLE_COUNT_C := FRAME_SAMPLE_COUNT_C;
  signal oldest_pending_valid_s : std_logic;
  signal oldest_pending_ptr_s   : ring_addr_t := (others => '0');
  signal queue_head_ready_s     : std_logic;
  signal spacing_ok_s           : std_logic;
  signal ring_safe_ok_s         : std_logic;
  signal queue_space_ok_s       : std_logic;
  signal can_accept_frame_s     : std_logic;
  signal spacing_reject_s       : std_logic;
  signal queue_reject_s         : std_logic;
  signal ring_reject_s          : std_logic;
  signal busy_reject_s          : std_logic;
  signal samples_since_accept_s : natural range 0 to FRAME_SAMPLE_COUNT_C := FRAME_SAMPLE_COUNT_C;
  signal record_count_s         : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal busydrop_count_s       : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal spacingdrop_count_s    : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal queuedrop_count_s      : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal ringdrop_count_s       : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal trig_count_s           : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
  signal pack_count_s           : unsigned(LIVE_COUNTER_WIDTH_C - 1 downto 0) := (others => '0');
begin
  event_pulse_s <= trigger_i.trigger_pulse or force_trigger_i;

  overlap_samples_s     <= overlap_samples_cfg(signal_delay_i);
  min_trigger_spacing_s <= FRAME_SAMPLE_COUNT_C - overlap_samples_s;

  oldest_pending_valid_s <= '1' when frame_queue_count_s > 0 else '0';
  oldest_pending_ptr_s   <= unsigned(frame_queue_s(frame_queue_head_s).start_ptr) when frame_queue_count_s > 0 else (others => '0');

  queue_head_ready_s <= '1' when (
    frame_queue_count_s > 0 and
    ring_distance(write_ptr_s, unsigned(frame_queue_s(frame_queue_head_s).start_ptr)) >= FRAME_SAMPLE_COUNT_C - 1
  ) else
    '0';

  spacing_ok_s <= '1' when samples_since_accept_s >= min_trigger_spacing_s else '0';
  queue_space_ok_s <= '1' when frame_queue_count_s < FRAME_QUEUE_DEPTH_C else '0';

  ring_safe_ok_s <= '1' when (
    oldest_pending_valid_s = '0' or
    ring_distance(write_ptr_s, oldest_pending_ptr_s) <= RING_DEPTH_C - FRAME_SAMPLE_COUNT_C
  ) else
    '0';

  can_accept_frame_s <= '1' when (
    enable_i = '1' and
    spacing_ok_s = '1' and
    queue_space_ok_s = '1' and
    ring_safe_ok_s = '1'
  ) else
    '0';

  spacing_reject_s <= '1' when (enable_i = '1' and spacing_ok_s = '0') else '0';
  queue_reject_s   <= '1' when (enable_i = '1' and spacing_ok_s = '1' and queue_space_ok_s = '0') else '0';
  ring_reject_s    <= '1' when (enable_i = '1' and spacing_ok_s = '1' and queue_space_ok_s = '1' and ring_safe_ok_s = '0') else '0';
  busy_reject_s    <= '1' when (enable_i = '1' and can_accept_frame_s = '0') else '0';

  frame_match_o <= can_accept_frame_s;
  desc_valid_o  <= queue_head_ready_s;
  desc_o        <= frame_queue_s(frame_queue_head_s) when queue_head_ready_s = '1' else STC3_FRAME_DESCRIPTOR_NULL;
  desc_trailer_o <= trailer_reg_s;

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
      rd_addr_i => unsigned(ring_rd_addr_i),
      dout_o    => ring_dout_s
    );

  ring_dout_o <= ring_dout_s;

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
    variable queue_v      : frame_desc_array_t;
    variable head_v       : integer range 0 to FRAME_QUEUE_DEPTH_C - 1;
    variable tail_v       : integer range 0 to FRAME_QUEUE_DEPTH_C - 1;
    variable count_v      : integer range 0 to FRAME_QUEUE_DEPTH_C;
    variable trigger_age_v : natural;
    variable sample0_ts_v : unsigned(63 downto 0);
    variable start_ptr_v  : ring_addr_t;
  begin
    if rising_edge(clock_i) then
      if (reset_i = '1' or reset_st_counters_i = '1') then
        write_ptr_s            <= (others => '0');
        frame_queue_s          <= (others => STC3_FRAME_DESCRIPTOR_NULL);
        frame_queue_head_s     <= 0;
        frame_queue_tail_s     <= 0;
        frame_queue_count_s    <= 0;
        record_count_s         <= (others => '0');
        busydrop_count_s       <= (others => '0');
        spacingdrop_count_s    <= (others => '0');
        queuedrop_count_s      <= (others => '0');
        ringdrop_count_s       <= (others => '0');
        pack_count_s           <= (others => '0');
        samples_since_accept_s <= FRAME_SAMPLE_COUNT_C;
      else
        queue_v := frame_queue_s;
        head_v  := frame_queue_head_s;
        tail_v  := frame_queue_tail_s;
        count_v := frame_queue_count_s;

        write_ptr_s <= wrap_add(write_ptr_s, 1);

        if enable_i = '0' then
          record_count_s         <= (others => '0');
          busydrop_count_s       <= (others => '0');
          spacingdrop_count_s    <= (others => '0');
          queuedrop_count_s      <= (others => '0');
          ringdrop_count_s       <= (others => '0');
          pack_count_s           <= (others => '0');
          samples_since_accept_s <= FRAME_SAMPLE_COUNT_C;
        else
          if samples_since_accept_s < FRAME_SAMPLE_COUNT_C then
            samples_since_accept_s <= samples_since_accept_s + 1;
          end if;

          if desc_taken_i = '1' and queue_head_ready_s = '1' and count_v > 0 then
            head_v := next_queue_idx(head_v);
            count_v := count_v - 1;
            record_count_s <= record_count_s + 1;
          end if;

          if event_pulse_s = '1' then
            if can_accept_frame_s = '1' then
              trigger_age_v := ring_distance(
                unsigned(timestamp_i(RING_ADDR_WIDTH_C - 1 downto 0)),
                unsigned(trigger_i.trigger_timestamp(RING_ADDR_WIDTH_C - 1 downto 0))
              );
              sample0_ts_v := unsigned(trigger_i.trigger_timestamp) - to_unsigned(PRETRIGGER_SAMPLES_C, trigger_i.trigger_timestamp'length);
              start_ptr_v  := wrap_sub(write_ptr_s, trigger_age_v + PRETRIGGER_SAMPLES_C);

              queue_v(tail_v) := (
                valid          => '1',
                ch_id          => ch_id_i,
                version        => version_i,
                start_ptr      => std_logic_vector(start_ptr_v),
                sample0_ts     => std_logic_vector(sample0_ts_v),
                baseline       => trigger_i.baseline,
                trigger_sample => trigger_i.trigger_sample,
                threshold_lsb  => threshold_xc_i(13 downto 0)
              );

              tail_v := next_queue_idx(tail_v);
              count_v := count_v + 1;

              pack_count_s           <= pack_count_s + 1;
              samples_since_accept_s <= 0;
            elsif spacing_reject_s = '1' then
              busydrop_count_s    <= busydrop_count_s + 1;
              spacingdrop_count_s <= spacingdrop_count_s + 1;
            elsif queue_reject_s = '1' then
              busydrop_count_s   <= busydrop_count_s + 1;
              queuedrop_count_s  <= queuedrop_count_s + 1;
            elsif ring_reject_s = '1' then
              busydrop_count_s  <= busydrop_count_s + 1;
              ringdrop_count_s  <= ringdrop_count_s + 1;
            elsif busy_reject_s = '1' then
              busydrop_count_s <= busydrop_count_s + 1;
            end if;
          end if;
        end if;

        frame_queue_s       <= queue_v;
        frame_queue_head_s  <= head_v;
        frame_queue_tail_s  <= tail_v;
        frame_queue_count_s <= count_v;
      end if;
    end if;
  end process main_proc;

  record_count_o         <= std_logic_vector(resize(record_count_s, record_count_o'length));
  full_count_o           <= (others => '0');
  busy_count_o           <= std_logic_vector(resize(busydrop_count_s, busy_count_o'length));
  spacing_reject_count_o <= std_logic_vector(resize(spacingdrop_count_s, spacing_reject_count_o'length));
  queue_reject_count_o   <= std_logic_vector(resize(queuedrop_count_s, queue_reject_count_o'length));
  ring_reject_count_o    <= std_logic_vector(resize(ringdrop_count_s, ring_reject_count_o'length));
  output_reject_count_o  <= (others => '0');
  trigger_count_o        <= std_logic_vector(resize(trig_count_s, trigger_count_o'length));
  packet_count_o         <= std_logic_vector(resize(pack_count_s, packet_count_o'length));
  delayed_sample_o       <= din_i;
end architecture rtl;
