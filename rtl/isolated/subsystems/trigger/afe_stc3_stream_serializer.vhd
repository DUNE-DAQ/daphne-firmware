library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library xpm;
use xpm.vcomponents.all;
use work.daphne_subsystem_pkg.all;
use work.grouped_frame_pkg.all;

-- One fixed-slice packer and one fragment descriptor calculator per four
-- channels. ADC-domain reserved URAM slots are filled through an addressed
-- write FIFO. Only the final header write publishes a complete record.
entity afe_stc3_stream_serializer is
  port (
    clock_i, reset_i : in std_logic;
    builder_clock_i, builder_reset_i : in std_logic;
    desc_i : in grouped_descriptor_array_t(0 to 3);
    desc_valid_i : in std_logic_array_t(0 to 3);
    desc_busy_o : out std_logic_array_t(0 to 3);
    ring_rd_addr_o : out ring_address_array_t(0 to 3);
    ring_data_i : in sample14_array_t(0 to 3);
    packet_wr_o, packet_commit_o : out std_logic_array_t(0 to 3);
    packet_addr_o : out unsigned(11 downto 0);
    packet_data_o : out std_logic_vector(71 downto 0);
    packet_overflow_o : out std_logic
  );
end entity;
architecture rtl of afe_stc3_stream_serializer is
  type state_t is (idle, prime, payload, header);
  signal state_s : state_t := idle;
  signal active_s : grouped_descriptor_t := (others=>'0');
  signal channel_s, next_channel_s : unsigned(1 downto 0) := (others=>'0');
  signal sample_index_s, issue_index_s : unsigned(8 downto 0) := (others=>'0');
  signal header_index_s : unsigned(2 downto 0) := (others=>'0');
  signal payload_word_s : unsigned(6 downto 0) := (others=>'0');
  signal shift_s : std_logic_vector(63 downto 0) := (others=>'0');
  signal window_s : std_logic_vector(77 downto 0);
  signal sample_s : std_logic_vector(13 downto 0);
  signal sample_valid_s, descriptor_start_s, overflow_s : std_logic;
  signal baseline_s : std_logic_vector(13 downto 0);
  signal descriptor_word_s, payload_data_s : std_logic_vector(63 downto 0);
  signal payload_wr_s : std_logic;
  signal wr_en_s, full_s, empty_s, wr_busy_s, rd_busy_s, rd_en_s : std_logic;
  signal write_count_s : std_logic_vector(9 downto 0);
  signal write_s, read_s : std_logic_vector(87 downto 0);
  signal dest_desc_s, held_desc_s : grouped_descriptor_array_t(0 to 3);
  signal request_s, ack_s, received_s, send_s : std_logic_vector(0 to 3) := (others=>'0');
  signal armed_s : std_logic_vector(0 to 3) := (others=>'0');
  signal commit_s : std_logic_array_t(0 to 3);
  type source_state_t is (src_idle, src_ack, src_clear);
  type source_states_t is array(0 to 3) of source_state_t;
  signal source_state_s : source_states_t := (others=>src_clear);
  signal committed_s : std_logic_vector(0 to 3) := (others=>'1');
begin
  channels : for ch in 0 to 3 generate
  begin
    desc_busy_o(ch) <= '0' when source_state_s(ch)=src_idle else '1';
    mailbox : xpm_cdc_handshake
      generic map(DEST_EXT_HSK=>1, DEST_SYNC_FF=>2, INIT_SYNC_FF=>1,
        SIM_ASSERT_CHK=>1, SRC_SYNC_FF=>2, WIDTH=>154)
      port map(src_clk=>clock_i, src_in=>held_desc_s(ch), src_send=>send_s(ch),
        src_rcv=>received_s(ch), dest_clk=>builder_clock_i,
        dest_out=>dest_desc_s(ch), dest_req=>request_s(ch), dest_ack=>ack_s(ch));
    -- Both descriptor bits and source ownership remain stable for the full
    -- request/ack exchange. A returned commit is also required before reuse.
    process(clock_i)
    begin
      if rising_edge(clock_i) then
        if reset_i='1' then
          send_s(ch)<='0'; source_state_s(ch)<=src_clear; committed_s(ch)<='1';
        else
          if commit_s(ch)='1' then committed_s(ch)<='1'; end if;
          case source_state_s(ch) is
            when src_idle =>
              if desc_valid_i(ch)='1' then
                held_desc_s(ch)<=desc_i(ch); send_s(ch)<='1';
                committed_s(ch)<='0'; source_state_s(ch)<=src_ack;
              end if;
            when src_ack =>
              if received_s(ch)='1' then send_s(ch)<='0'; source_state_s(ch)<=src_clear; end if;
            when src_clear =>
              if received_s(ch)='0' and committed_s(ch)='1' then source_state_s(ch)<=src_idle; end if;
          end case;
        end if;
      end if;
    end process;
    ring_rd_addr_o(ch) <= unsigned(active_s(139 downto 129)) + resize(issue_index_s,11);
    packet_wr_o(ch) <= rd_en_s when unsigned(read_s(85 downto 84))=ch else '0';
    commit_s(ch) <= rd_en_s and read_s(86) when unsigned(read_s(85 downto 84))=ch else '0';
    packet_commit_o(ch) <= commit_s(ch);
  end generate;
  packet_addr_o <= unsigned(read_s(83 downto 72));
  packet_data_o <= read_s(71 downto 0);
  packet_overflow_o <= read_s(87);
  rd_en_s <= not empty_s and not rd_busy_s and not reset_i;

  write_fifo : xpm_fifo_async
    generic map(CDC_SYNC_STAGES=>2, DOUT_RESET_VALUE=>"0", ECC_MODE=>"no_ecc",
      FIFO_MEMORY_TYPE=>"block", FIFO_READ_LATENCY=>0, FIFO_WRITE_DEPTH=>512,
      FULL_RESET_VALUE=>0, PROG_EMPTY_THRESH=>10, PROG_FULL_THRESH=>385,
      RD_DATA_COUNT_WIDTH=>10, READ_DATA_WIDTH=>88, READ_MODE=>"fwft",
      RELATED_CLOCKS=>0, SIM_ASSERT_CHK=>1, USE_ADV_FEATURES=>"0004",
      WAKEUP_TIME=>0, WRITE_DATA_WIDTH=>88, WR_DATA_COUNT_WIDTH=>10)
    port map(rst=>builder_reset_i, wr_clk=>builder_clock_i, wr_en=>wr_en_s,
      din=>write_s, full=>full_s, wr_ack=>open, overflow=>open,
      prog_full=>open, wr_data_count=>write_count_s, almost_full=>open,
      wr_rst_busy=>wr_busy_s, rd_clk=>clock_i, rd_en=>rd_en_s, dout=>read_s,
      empty=>empty_s, underflow=>open, prog_empty=>open, rd_data_count=>open,
      almost_empty=>open, data_valid=>open, rd_rst_busy=>rd_busy_s,
      sleep=>'0', injectsbiterr=>'0', injectdbiterr=>'0', sbiterr=>open, dbiterr=>open);

  sample_s <= ring_data_i(to_integer(channel_s));
  sample_valid_s <= '1' when state_s=payload else '0';
  descriptor_start_s <= '1' when state_s=payload and sample_index_s=0 else '0';
  baseline_s <= std_logic_vector(to_unsigned(0,14)-unsigned(active_s(64 downto 51)))
    when active_s(8)='1' else active_s(64 downto 51);
  descriptors : entity work.fragment_peak_descriptors_banked
    port map(clock_i=>builder_clock_i, reset_i=>builder_reset_i,
      start_i=>descriptor_start_s, baseline_i=>baseline_s, positive_pulse_i=>active_s(8),
      threshold_i=>active_s(22 downto 9), sample_valid_i=>sample_valid_s,
      sample_i=>sample_s, sample_index_i=>sample_index_s,
      read_index_i=>header_index_s-2, read_word_o=>descriptor_word_s,
      done_o=>open, overflow_o=>overflow_s);
  window_s <= sample_s & shift_s;
  process(all)
  begin
    payload_wr_s<=sample_valid_s; payload_data_s<=(others=>'0');
    case to_integer(sample_index_s(4 downto 0)) is
      when 4 => payload_data_s<=window_s(71 downto 8);
      when 9 => payload_data_s<=window_s(65 downto 2);
      when 13 => payload_data_s<=window_s(73 downto 10);
      when 18 => payload_data_s<=window_s(67 downto 4);
      when 22 => payload_data_s<=window_s(75 downto 12);
      when 27 => payload_data_s<=window_s(69 downto 6);
      when 31 => payload_data_s<=window_s(77 downto 14);
      when others => payload_wr_s<='0';
    end case;
  end process;
  process(all)
  begin
    write_s<=(others=>'0'); wr_en_s<='0';
    write_s(85 downto 84)<=std_logic_vector(channel_s);
    write_s(83 downto 79)<=active_s(4 downto 0);
    if payload_wr_s='1' then
      wr_en_s<=not builder_reset_i;
      write_s(78 downto 72)<=std_logic_vector(payload_word_s+8);
      write_s(63 downto 0)<=payload_data_s;
      if sample_index_s=511 then write_s(71 downto 64)<=X"ED"; end if;
    elsif state_s=header then
      wr_en_s<=not builder_reset_i;
      write_s(78 downto 72)<=std_logic_vector(resize(header_index_s,7));
      case to_integer(header_index_s) is
        when 0 => write_s(71 downto 0)<=X"BE" & active_s(128 downto 65);
        when 1 => write_s(71 downto 0)<=X"00" & active_s(153 downto 146) &
          active_s(145 downto 142) & active_s(5) & '1' & overflow_s & '0' &
          active_s(7 downto 6) & active_s(64 downto 51) & "00" &
          active_s(36 downto 23) & "00" & active_s(50 downto 37);
        when others => write_s(63 downto 0)<=descriptor_word_s;
      end case;
      if header_index_s=7 then write_s(86)<='1'; write_s(87)<=overflow_s; end if;
    end if;
  end process;

  process(builder_clock_i)
    variable candidate : unsigned(1 downto 0);
  begin
    if rising_edge(builder_clock_i) then
      if builder_reset_i='1' then
        state_s<=idle; active_s<=(others=>'0'); channel_s<=(others=>'0'); next_channel_s<=(others=>'0');
        issue_index_s<=(others=>'0'); sample_index_s<=(others=>'0');
        header_index_s<=(others=>'0'); payload_word_s<=(others=>'0');
        shift_s<=(others=>'0'); ack_s<=request_s; armed_s<=(others=>'0');
      else
        for ch in 0 to 3 loop
          if request_s(ch)='0' then ack_s(ch)<='0'; armed_s(ch)<='1'; end if;
        end loop;
        assert not(wr_en_s='1' and (full_s='1' or wr_busy_s='1'))
          report "grouped serializer exceeded reserved write FIFO space" severity failure;
        case state_s is
          when idle =>
            -- Reserve 128 words for 120 writes plus write-count pipeline latency.
            -- Remote read-pointer latency makes this count conservative.
            if wr_busy_s='0' and full_s='0' and unsigned(write_count_s)<=384 then
              for offset in 0 to 3 loop
                candidate:=next_channel_s+to_unsigned(offset,2);
                if request_s(to_integer(candidate))='1' and ack_s(to_integer(candidate))='0'
                  and armed_s(to_integer(candidate))='1' then
                  active_s<=dest_desc_s(to_integer(candidate)); channel_s<=candidate;
                  next_channel_s<=candidate+1; issue_index_s<=(others=>'0');
                  sample_index_s<=(others=>'0'); payload_word_s<=(others=>'0');
                  shift_s<=(others=>'0'); state_s<=prime;
                  exit;
                end if;
              end loop;
            end if;
          when prime => issue_index_s<=to_unsigned(1,9); state_s<=payload;
          when payload =>
            shift_s<=window_s(77 downto 14);
            if payload_wr_s='1' then payload_word_s<=payload_word_s+1; end if;
            issue_index_s<=issue_index_s+1;
            if sample_index_s=511 then header_index_s<=(others=>'0'); state_s<=header;
            else sample_index_s<=sample_index_s+1; end if;
          when header =>
            if header_index_s=7 then ack_s(to_integer(channel_s))<='1'; state_s<=idle;
            else header_index_s<=header_index_s+1; end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
