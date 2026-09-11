library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity multilane_readout_mux_tb is end;
architecture test of multilane_readout_mux_tb is
  constant LANES_C : positive := 8;
  constant CHANNELS_PER_LANE_C : positive := 5;
  constant PACKETS_PER_CHANNEL_C : positive := 3;
  type channel_words_t is array(0 to 39) of natural range 0 to 119;
  type channel_packets_t is array(0 to 39) of natural range 0 to PACKETS_PER_CHANNEL_C;
  type lane_counts_t is array(0 to LANES_C-1) of natural;
  signal clock_s : std_logic := '0';
  signal reset_s : std_logic := '1';
  signal cycle_s : natural := 0;
  signal word_s : channel_words_t := (others=>0);
  signal packet_s : channel_packets_t := (others=>0);
  signal ready_s, read_s : std_logic_array_t(0 to 39);
  signal input_s : slv72_array_t(0 to 39);
  signal output_s : array_8x64_type;
  signal valid_s, last_s, permit_s, previous_permit_s : std_logic_vector(7 downto 0) := (others=>'0');
  signal continued_without_credit_s : natural := 0;
  function packet_word(channel, packet, word_index : natural) return std_logic_vector is
  begin
    return x"CAFE" & std_logic_vector(to_unsigned(channel,8)) &
      std_logic_vector(to_unsigned(packet,8)) & std_logic_vector(to_unsigned(word_index,32));
  end;
begin
  clock_s <= not clock_s after 8 ns;
  dut : entity work.two_lane_readout_mux
    generic map(CHANNEL_COUNT_G=>40, LANE_COUNT_G=>LANES_C, CHANNELS_PER_LANE_G=>CHANNELS_PER_LANE_C)
    port map(clock_i=>clock_s, reset_i=>reset_s, ready_i=>ready_s, dout_i=>input_s,
      rd_en_o=>read_s, dout_o=>output_s, valid_o=>valid_s, last_o=>last_s, packet_ready_i=>permit_s);

  channels : for channel in 0 to 39 generate
    ready_s(channel) <= '1' when packet_s(channel)<PACKETS_PER_CHANNEL_C else '0';
    input_s(channel)(63 downto 0) <= packet_word(channel,packet_s(channel),word_s(channel));
    input_s(channel)(71 downto 64) <= x"ED" when word_s(channel)=119 else
      x"BE" when word_s(channel)=0 else x"00";
  end generate;
  lanes : for lane in 0 to LANES_C-1 generate
    -- Start links independently and withdraw readiness during in-flight
    -- packets. Lane7 also has a longer outage after the other links recover.
    permit_s(lane) <= '1' when cycle_s>=20+lane*11 and
      not(cycle_s>=80 and cycle_s<190) and
      not(lane=7 and cycle_s>=800 and cycle_s<1000) else '0';
  end generate;

  source : process(clock_s)
  begin
    if rising_edge(clock_s) then
      previous_permit_s<=permit_s;
      if reset_s='1' then
        word_s<=(others=>0); packet_s<=(others=>0); cycle_s<=0;
        continued_without_credit_s<=0;
      else
        cycle_s<=cycle_s+1;
        for channel in 0 to 39 loop
          if read_s(channel)='1' then
            assert ready_s(channel)='1' report "read exhausted channel packet storage" severity failure;
            if word_s(channel)=0 then
              assert previous_permit_s(channel/CHANNELS_PER_LANE_C)='1'
                report "started a packet without downstream reservation" severity failure;
            elsif permit_s(channel/CHANNELS_PER_LANE_C)='0' then
              continued_without_credit_s<=continued_without_credit_s+1;
            end if;
            if word_s(channel)=119 then word_s(channel)<=0; packet_s(channel)<=packet_s(channel)+1;
            else word_s(channel)<=word_s(channel)+1; end if;
          end if;
        end loop;
      end if;
    end if;
  end process;

  sink : process(clock_s)
    variable words, packets : lane_counts_t := (others=>0);
    variable all_eight_active : natural := 0;
    variable channel : natural;
    variable finished : boolean;
  begin
    if rising_edge(clock_s) then
      if reset_s='1' then words:=(others=>0); packets:=(others=>0); all_eight_active:=0;
      else
        if valid_s=x"FF" then all_eight_active:=all_eight_active+1; end if;
        finished:=true;
        for lane in 0 to LANES_C-1 loop
          if valid_s(lane)='1' then
            channel:=lane*CHANNELS_PER_LANE_C+(packets(lane) mod CHANNELS_PER_LANE_C);
            assert output_s(lane)=packet_word(channel,packets(lane)/CHANNELS_PER_LANE_C,words(lane))
              report "lane/channel mapping, round-robin order or packet word corruption" severity failure;
            if words(lane)=119 then
              assert last_s(lane)='1' report "missing last at fixed word120" severity failure;
              words(lane):=0; packets(lane):=packets(lane)+1;
            else
              assert last_s(lane)='0' report "truncated packet" severity failure;
              words(lane):=words(lane)+1;
            end if;
          else
            assert words(lane)=0 report "stalled inside an admitted packet" severity failure;
            assert last_s(lane)='0' report "last without valid" severity failure;
          end if;
          if packets(lane)/=CHANNELS_PER_LANE_C*PACKETS_PER_CHANNEL_C then finished:=false; end if;
        end loop;
        if finished then
          assert all_eight_active>0 and continued_without_credit_s>0
            report "concurrent-lane or in-packet readiness withdrawal case was not exercised" severity failure;
          for ch in 0 to 39 loop assert packet_s(ch)=PACKETS_PER_CHANNEL_C severity failure; end loop;
          report "multilane_readout_mux_tb PASS:120 packets,14400 words,eight concurrent lanes,round-robin and packet credits" severity note;
          stop;
        end if;
      end if;
    end if;
  end process;
  stimulus : process
  begin
    wait until falling_edge(clock_s); wait until falling_edge(clock_s); reset_s<='0';
    wait for 60 us;
    assert false report "eight-lane readout did not drain all packets" severity failure;
    wait;
  end process;
end;
