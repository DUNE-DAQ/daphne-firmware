library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity afe_stc3_stream_serializer is
  generic (
    CHANNELS_PER_AFE_G : positive := 8
  );
  port (
    clock_i           : in  std_logic;
    reset_i           : in  std_logic;
    reset_st_counters_i : in std_logic;
    desc_valid_i      : in  std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    desc_i            : in  stc3_frame_descriptor_array_t(0 to CHANNELS_PER_AFE_G - 1);
    desc_trailer_i    : in  peak_descriptor_trailer_bank_t(0 to CHANNELS_PER_AFE_G - 1);
    desc_taken_o      : out std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    ring_rd_addr_o    : out slv11_array_t(0 to CHANNELS_PER_AFE_G - 1);
    ring_dout_i       : in  sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
    ready_o           : out std_logic;
    rd_en_i           : in  std_logic;
    dout_o            : out std_logic_vector(71 downto 0)
  );
end entity afe_stc3_stream_serializer;

architecture rtl of afe_stc3_stream_serializer is
  constant FRAME_SAMPLE_COUNT_C       : natural := 512;
  constant FRAME_BLOCK_COUNT_C        : natural := FRAME_SAMPLE_COUNT_C / 32;
  constant FINAL_BLOCK_INDEX_C        : natural := FRAME_BLOCK_COUNT_C - 1;
  constant BLOCK_SAMPLE_COUNT_C       : natural := 32;
  constant WORDS_PER_BLOCK_C          : natural := 7;
  constant HEADER_WORD_COUNT_C        : natural := 8;
  constant WORDS_PER_PACKET_C         : natural := HEADER_WORD_COUNT_C + FRAME_BLOCK_COUNT_C * WORDS_PER_BLOCK_C;
  constant OUTPUT_FIFO_DEPTH_C        : positive := 256;
  constant OUTPUT_FIFO_COUNT_WIDTH_C  : positive := 8;
  constant OUTPUT_FIFO_ACCEPT_LIMIT_C : natural := OUTPUT_FIFO_DEPTH_C - WORDS_PER_PACKET_C;

  type serializer_state_t is (ser_idle, ser_header, ser_load, ser_emit);
  type sample_block_t is array (0 to BLOCK_SAMPLE_COUNT_C - 1) of std_logic_vector(13 downto 0);

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

  signal serializer_state_s  : serializer_state_t := ser_idle;
  signal active_desc_s       : stc3_frame_descriptor_t := STC3_FRAME_DESCRIPTOR_NULL;
  signal active_trailer_s    : peak_descriptor_trailer_t := PEAK_DESCRIPTOR_TRAILER_NULL;
  signal active_channel_s    : integer range 0 to CHANNELS_PER_AFE_G - 1 := 0;
  signal next_channel_s      : integer range 0 to CHANNELS_PER_AFE_G - 1 := 0;
  signal block_samples_s     : sample_block_t := (others => (others => '0'));
  signal header_index_s      : integer range 0 to HEADER_WORD_COUNT_C - 1 := 0;
  signal block_index_s       : integer range 0 to FINAL_BLOCK_INDEX_C := 0;
  signal load_issue_index_s  : integer range 0 to BLOCK_SAMPLE_COUNT_C := 0;
  signal emit_index_s        : integer range 0 to WORDS_PER_BLOCK_C - 1 := 0;
  signal fifo_din_s          : std_logic_vector(71 downto 0) := (others => '0');
  signal fifo_dout_s         : std_logic_vector(71 downto 0);
  signal fifo_wr_en_s        : std_logic := '0';
  signal fifo_sleep_s        : std_logic := '1';
  signal fifo_wr_data_count_s : std_logic_vector(OUTPUT_FIFO_COUNT_WIDTH_C - 1 downto 0);
  signal output_space_ok_s   : std_logic;
  signal desc_taken_s        : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1) := (others => '0');
begin
  desc_taken_o <= desc_taken_s;

  ring_addr_gen : for idx in 0 to CHANNELS_PER_AFE_G - 1 generate
  begin
    ring_rd_addr_o(idx) <= std_logic_vector(unsigned(active_desc_s.start_ptr) + to_unsigned(block_index_s * BLOCK_SAMPLE_COUNT_C + load_issue_index_s, active_desc_s.start_ptr'length))
      when (idx = active_channel_s and serializer_state_s = ser_load and load_issue_index_s < BLOCK_SAMPLE_COUNT_C)
      else active_desc_s.start_ptr when idx = active_channel_s
      else (others => '0');
  end generate ring_addr_gen;

  output_fifo_inst : entity work.sync_fifo_fwft
    generic map (
      DATA_WIDTH_G        => 72,
      DEPTH_G             => OUTPUT_FIFO_DEPTH_C,
      COUNT_WIDTH_G       => OUTPUT_FIFO_COUNT_WIDTH_C,
      MEMORY_TYPE_G       => "auto",
      PROG_EMPTY_THRESH_G => 5,
      PROG_FULL_THRESH_G  => OUTPUT_FIFO_ACCEPT_LIMIT_C + 1
    )
    port map (
      clock_i         => clock_i,
      reset_i         => reset_i,
      sleep_i         => fifo_sleep_s,
      wr_en_i         => fifo_wr_en_s,
      din_i           => fifo_din_s,
      rd_en_i         => rd_en_i,
      dout_o          => fifo_dout_s,
      prog_empty_o    => open,
      prog_full_o     => open,
      wr_data_count_o => fifo_wr_data_count_s
    );

  output_space_ok_s <= '1' when to_integer(unsigned(fifo_wr_data_count_s)) <= OUTPUT_FIFO_ACCEPT_LIMIT_C else '0';
  fifo_sleep_s      <= '1' when serializer_state_s = ser_idle else '0';
  fifo_wr_en_s      <= '1' when (serializer_state_s = ser_header or serializer_state_s = ser_emit) else '0';

  fifo_din_s <= X"BE" & active_desc_s.sample0_ts when (serializer_state_s = ser_header and header_index_s = 0) else
                X"00" & active_desc_s.ch_id & active_desc_s.version & "000000" &
                active_desc_s.baseline & "00" & active_desc_s.threshold_lsb &
                "00" & active_desc_s.trigger_sample when (serializer_state_s = ser_header and header_index_s = 1) else
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

  main_proc : process(clock_i)
    variable desc_taken_v : std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    variable found_v      : boolean;
    variable found_idx_v  : integer range 0 to CHANNELS_PER_AFE_G - 1;
  begin
    if rising_edge(clock_i) then
      desc_taken_v := (others => '0');

      if (reset_i = '1' or reset_st_counters_i = '1') then
        serializer_state_s <= ser_idle;
        active_desc_s      <= STC3_FRAME_DESCRIPTOR_NULL;
        active_trailer_s   <= PEAK_DESCRIPTOR_TRAILER_NULL;
        active_channel_s   <= 0;
        next_channel_s     <= 0;
        block_samples_s    <= (others => (others => '0'));
        header_index_s     <= 0;
        block_index_s      <= 0;
        load_issue_index_s <= 0;
        emit_index_s       <= 0;
      else
        case serializer_state_s is
          when ser_idle =>
            if active_desc_s.valid = '0' and output_space_ok_s = '1' then
              found_v := false;
              found_idx_v := next_channel_s;
              for offset in 0 to CHANNELS_PER_AFE_G - 1 loop
                found_idx_v := (next_channel_s + offset) mod CHANNELS_PER_AFE_G;
                if desc_valid_i(found_idx_v) = '1' then
                  found_v := true;
                  exit;
                end if;
              end loop;

              if found_v then
                active_desc_s      <= desc_i(found_idx_v);
                active_trailer_s   <= desc_trailer_i(found_idx_v);
                active_channel_s   <= found_idx_v;
                next_channel_s     <= (found_idx_v + 1) mod CHANNELS_PER_AFE_G;
                header_index_s     <= 0;
                block_index_s      <= 0;
                load_issue_index_s <= 0;
                emit_index_s       <= 0;
                serializer_state_s <= ser_header;
                desc_taken_v(found_idx_v) := '1';
              end if;
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
              block_samples_s(load_issue_index_s - 1) <= ring_dout_i(active_channel_s);
              load_issue_index_s <= load_issue_index_s + 1;
            else
              block_samples_s(BLOCK_SAMPLE_COUNT_C - 1) <= ring_dout_i(active_channel_s);
              emit_index_s <= 0;
              serializer_state_s <= ser_emit;
            end if;

          when ser_emit =>
            if emit_index_s = WORDS_PER_BLOCK_C - 1 then
              if block_index_s = FINAL_BLOCK_INDEX_C then
                active_desc_s      <= STC3_FRAME_DESCRIPTOR_NULL;
                active_trailer_s   <= PEAK_DESCRIPTOR_TRAILER_NULL;
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

      desc_taken_s <= desc_taken_v;
    end if;
  end process main_proc;

  ready_o <= '1' when to_integer(unsigned(fifo_wr_data_count_s)) > 0 else '0';
  dout_o  <= fifo_dout_s;
end architecture rtl;
