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
    din_i                    : in  std_logic_vector(13 downto 0);
    trigger_i                : in  trigger_xcorr_result_t;
    trailer_capture_i        : in  std_logic;
    trailer_i                : in  peak_descriptor_trailer_t;
    frame_match_o            : out std_logic;
    record_count_o           : out std_logic_vector(63 downto 0);
    full_count_o             : out std_logic_vector(63 downto 0);
    busy_count_o             : out std_logic_vector(63 downto 0);
    trigger_count_o          : out std_logic_vector(63 downto 0);
    packet_count_o           : out std_logic_vector(63 downto 0);
    delayed_sample_o         : out std_logic_vector(13 downto 0);
    ready_o                  : out std_logic;
    rd_en_i                  : in  std_logic;
    dout_o                   : out std_logic_vector(71 downto 0)
  );
end entity stc3_record_builder;

architecture rtl of stc3_record_builder is
  type array_10x14_type is array(9 downto 0) of std_logic_vector(13 downto 0);
  type state_type is (
    rst, wait4trig, w0, w1, w2, w3, h0, h1, h2, h3, h4, h5, h6, h7, h8,
    d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15,
    d16, d17, d18, d19, d20, d21, d22, d23, d24, d25, d26, d27, d28, d29, d30, d31
  );
  type trigger_counter_state_type is (rst_trggr, wait4trig_trggr, rising_triggered);

  signal din_delay            : array_10x14_type;
  signal r0_s, r1_s, r2_s     : std_logic_vector(13 downto 0);
  signal r3_s, r4_s, r5_s     : std_logic_vector(13 downto 0);
  signal block_count_s        : integer range 0 to 31 := 0;
  signal state_s              : state_type := rst;
  signal trig_count_state_s   : trigger_counter_state_type := rst_trggr;
  signal sample0_ts_s         : std_logic_vector(63 downto 0);
  signal fifo_din_s           : std_logic_vector(71 downto 0) := (others => '0');
  signal fifo_wr_en_s         : std_logic := '0';
  signal fifo_sleep_s         : std_logic := '0';
  signal marker_s             : std_logic_vector(7 downto 0) := X"00";
  signal prog_empty_s         : std_logic;
  signal prog_full_s          : std_logic;
  signal fifo_word_count_s    : std_logic_vector(12 downto 0);
  signal record_count_s       : std_logic_vector(63 downto 0) := (others => '0');
  signal busydrop_count_s     : std_logic_vector(63 downto 0) := (others => '0');
  signal fulldrop_count_s     : std_logic_vector(63 downto 0) := (others => '0');
  signal busydrop_seen_s      : std_logic := '0';
  signal fsm_busy_s           : std_logic;
  signal trig_count_s         : unsigned(63 downto 0) := (others => '0');
  signal pack_count_s         : unsigned(63 downto 0) := (others => '0');
  signal trailer_reg_s        : peak_descriptor_trailer_t := PEAK_DESCRIPTOR_TRAILER_NULL;
  signal event_pulse_s        : std_logic;
begin
  event_pulse_s <= trigger_i.trigger_pulse or force_trigger_i;

  din_delay(0) <= din_i;

  -- The legacy STC3 datapath currently delays the packed sample stream by a
  -- fixed 288-cycle latency. Keep that behavior here so the isolated builder
  -- remains compatible while removing direct vendor primitive dependencies.
  fixed_delay_inst : entity work.fixed_delay_line
    generic map (
      WIDTH_G => 14,
      DELAY_G => 288
    )
    port map (
      clock_i => clock_i,
      din_i   => din_i,
      dout_o  => din_delay(9)
    );

  pack_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      r0_s <= din_delay(9);
      r1_s <= r0_s;
      r2_s <= r1_s;
      r3_s <= r2_s;
      r4_s <= r3_s;
      r5_s <= r4_s;
    end if;
  end process pack_proc;

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

  fsm_busy_s <= '0' when (state_s = rst or state_s = wait4trig) else '1';

  fulldrop_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if enable_i = '0' then
        fulldrop_count_s <= (others => '0');
      elsif (event_pulse_s = '1' and prog_full_s = '1' and state_s = wait4trig) then
        fulldrop_count_s <= std_logic_vector(unsigned(fulldrop_count_s) + 1);
      end if;
    end if;
  end process fulldrop_proc;

  busydrop_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if enable_i = '0' then
        busydrop_count_s <= (others => '0');
      elsif (event_pulse_s = '1' and fsm_busy_s = '1' and busydrop_seen_s = '0') then
        busydrop_count_s <= std_logic_vector(unsigned(busydrop_count_s) + 1);
        busydrop_seen_s  <= '1';
      end if;

      if (busydrop_seen_s = '1' and fsm_busy_s = '0') then
        busydrop_seen_s <= '0';
      end if;
    end if;
  end process busydrop_proc;

  builder_fsm_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if (reset_i = '1' or reset_st_counters_i = '1') then
        state_s      <= rst;
        pack_count_s <= (others => '0');
      else
        case state_s is
          when rst =>
            state_s <= wait4trig;
          when wait4trig =>
            if (event_pulse_s = '1' and enable_i = '1' and prog_full_s = '0') then
              block_count_s <= 0;
              pack_count_s  <= pack_count_s + 1;
              state_s       <= w0;
            end if;
          when w0 => state_s <= w1;
          when w1 => state_s <= w2;
          when w2 => state_s <= w3;
          when w3 => state_s <= h0;
          when h0 => state_s <= h1;
          when h1 => state_s <= h2;
          when h2 => state_s <= h3;
          when h3 => state_s <= h4;
          when h4 => state_s <= h5;
          when h5 => state_s <= h6;
          when h6 => state_s <= h7;
          when h7 => state_s <= h8;
          when h8 => state_s <= d0;
          when d0 => state_s <= d1;
          when d1 => state_s <= d2;
          when d2 => state_s <= d3;
          when d3 => state_s <= d4;
          when d4 => state_s <= d5;
          when d5 => state_s <= d6;
          when d6 => state_s <= d7;
          when d7 => state_s <= d8;
          when d8 => state_s <= d9;
          when d9 => state_s <= d10;
          when d10 => state_s <= d11;
          when d11 => state_s <= d12;
          when d12 => state_s <= d13;
          when d13 => state_s <= d14;
          when d14 => state_s <= d15;
          when d15 => state_s <= d16;
          when d16 => state_s <= d17;
          when d17 => state_s <= d18;
          when d18 => state_s <= d19;
          when d19 => state_s <= d20;
          when d20 => state_s <= d21;
          when d21 => state_s <= d22;
          when d22 => state_s <= d23;
          when d23 => state_s <= d24;
          when d24 => state_s <= d25;
          when d25 => state_s <= d26;
          when d26 => state_s <= d27;
          when d27 => state_s <= d28;
          when d28 => state_s <= d29;
          when d29 => state_s <= d30;
          when d30 => state_s <= d31;
          when d31 =>
            if block_count_s = 31 then
              state_s <= wait4trig;
            else
              block_count_s <= block_count_s + 1;
              state_s       <= d0;
            end if;
          when others =>
            state_s <= rst;
        end case;
      end if;
    end if;
  end process builder_fsm_proc;

  record_count_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if enable_i = '0' then
        record_count_s <= (others => '0');
      elsif state_s = h0 then
        record_count_s <= std_logic_vector(unsigned(record_count_s) + 1);
      end if;
    end if;
  end process record_count_proc;

  sample0_ts_s <= std_logic_vector(unsigned(trigger_i.trigger_timestamp) - 64);

  marker_s <= X"BE" when (state_s = h1) else
              X"ED" when (state_s = d27 and block_count_s = 31) else
              X"00";

  fifo_din_s <= marker_s & sample0_ts_s when (state_s = h1) else
                marker_s & ch_id_i(7 downto 0) & version_i(3 downto 0) & "000000" &
                trigger_i.baseline(13 downto 0) & "00" & threshold_xc_i(13 downto 0) &
                "00" & trigger_i.trigger_sample(13 downto 0) when (state_s = h2) else
                marker_s & trailer_reg_s(1) & trailer_reg_s(0) when (state_s = h3) else
                marker_s & trailer_reg_s(3) & trailer_reg_s(2) when (state_s = h4) else
                marker_s & trailer_reg_s(5) & trailer_reg_s(4) when (state_s = h5) else
                marker_s & trailer_reg_s(7) & trailer_reg_s(6) when (state_s = h6) else
                marker_s & trailer_reg_s(9) & trailer_reg_s(8) when (state_s = h7) else
                marker_s & trailer_reg_s(11) & trailer_reg_s(10) when (state_s = h8) else
                marker_s & r0_s(7 downto 0) & r1_s & r2_s & r3_s & r4_s when (state_s = d0) else
                marker_s & r0_s(1 downto 0) & r1_s & r2_s & r3_s & r4_s & r5_s(13 downto 8) when (state_s = d5) else
                marker_s & r0_s(9 downto 0) & r1_s & r2_s & r3_s & r4_s(13 downto 2) when (state_s = d9) else
                marker_s & r0_s(3 downto 0) & r1_s & r2_s & r3_s & r4_s & r5_s(13 downto 10) when (state_s = d14) else
                marker_s & r0_s(11 downto 0) & r1_s & r2_s & r3_s & r4_s(13 downto 4) when (state_s = d18) else
                marker_s & r0_s(5 downto 0) & r1_s & r2_s & r3_s & r4_s & r5_s(13 downto 12) when (state_s = d23) else
                marker_s & r0_s & r1_s & r2_s & r3_s & r4_s(13 downto 6) when (state_s = d27) else
                X"000000000000000000";

  fifo_wr_en_s <= '1' when (state_s = h1 or state_s = h2 or state_s = h3 or state_s = h4 or
                             state_s = h5 or state_s = h6 or state_s = h7 or state_s = h8 or
                             state_s = d0 or state_s = d5 or state_s = d9 or state_s = d14 or
                             state_s = d18 or state_s = d23 or state_s = d27) else
                 '0';

  fifo_sleep_s <= '1' when (state_s = rst or state_s = wait4trig) else
                  '0';

  output_fifo_inst : entity work.sync_fifo_fwft
    generic map (
      DATA_WIDTH_G        => 72,
      DEPTH_G             => 4096,
      COUNT_WIDTH_G       => 13,
      PROG_EMPTY_THRESH_G => 220,
      PROG_FULL_THRESH_G  => 200
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
      wr_data_count_o => fifo_word_count_s
    );

  frame_match_o    <= '1' when state_s = wait4trig else '0';
  record_count_o   <= record_count_s;
  full_count_o     <= fulldrop_count_s;
  busy_count_o     <= busydrop_count_s;
  trigger_count_o  <= std_logic_vector(trig_count_s);
  packet_count_o   <= std_logic_vector(pack_count_s);
  delayed_sample_o <= din_delay(9);
  ready_o          <= not prog_empty_s;
end architecture rtl;
