library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_subsystem_pkg.all;
use work.grouped_frame_pkg.all;

entity afe_stc3_stream_serializer_tb is end;
architecture test of afe_stc3_stream_serializer_tb is
  signal clk, fast : std_logic := '0';
  signal rst : std_logic := '1';
  signal desc : grouped_descriptor_array_t(0 to 3) := (others=>(others=>'0'));
  signal valid : std_logic_array_t(0 to 3) := (others=>'0');
  signal busy, packet_wr, packet_commit : std_logic_array_t(0 to 3);
  signal ring_addr : ring_address_array_t(0 to 3);
  signal ring_data : sample14_array_t(0 to 3);
  signal packet_addr : unsigned(11 downto 0);
  signal packet_data : std_logic_vector(71 downto 0);
  signal packet_overflow : std_logic;
begin
  clk<=not clk after 8 ns;
  fast<=not fast after 1600 ps;
  dut : entity work.afe_stc3_stream_serializer
    port map(clock_i=>clk, reset_i=>rst, builder_clock_i=>fast, builder_reset_i=>rst,
      desc_i=>desc, desc_valid_i=>valid, desc_busy_o=>busy,
      ring_rd_addr_o=>ring_addr, ring_data_i=>ring_data,
      packet_wr_o=>packet_wr, packet_commit_o=>packet_commit,
      packet_addr_o=>packet_addr, packet_data_o=>packet_data, packet_overflow_o=>packet_overflow);
  channels : for ch in 0 to 3 generate
    ring_data(ch)<=std_logic_vector(to_unsigned(8000-100*(ch+1),14));
  end generate;
  process
    type counts_t is array(0 to 3) of natural;
    variable writes : counts_t := (others=>0);
    variable commits : natural := 0;
    variable word : natural;
    variable expected : std_logic_vector(71 downto 0);
    variable payload : std_logic_vector(7167 downto 0);
  begin
    for ch in 0 to 3 loop
      desc(ch)(153 downto 146)<=std_logic_vector(to_unsigned(ch,8));
      desc(ch)(145 downto 142)<=x"3";
      desc(ch)(128 downto 65)<=std_logic_vector(to_unsigned(1000+ch,64));
      desc(ch)(64 downto 51)<=std_logic_vector(to_unsigned(8000,14));
      desc(ch)(22 downto 9)<=std_logic_vector(to_unsigned(64,14));
      desc(ch)(4 downto 0)<=std_logic_vector(to_unsigned(ch,5));
    end loop;
    wait for 160 ns; wait until falling_edge(clk); rst<='0';
    for n in 1 to 8 loop wait until falling_edge(clk); end loop;
    valid<=(others=>'1');
    wait until falling_edge(clk); valid<=(others=>'0');
    while commits<4 loop
      wait until rising_edge(clk);
      for ch in 0 to 3 loop
        if packet_wr(ch)='1' then
          assert to_integer(packet_addr(11 downto 7))=ch report "reserved packet slot changed" severity failure;
          if writes(ch)<112 then word:=writes(ch)+8; else word:=writes(ch)-112; end if;
          assert to_integer(packet_addr(6 downto 0))=word report "payload/header write order changed" severity failure;
          expected:=(others=>'0');
          if word>=8 then
            for sample in 0 to 511 loop
              payload(14*sample+13 downto 14*sample):=std_logic_vector(to_unsigned(8000-100*(ch+1),14));
            end loop;
            expected(63 downto 0):=payload(64*(word-8)+63 downto 64*(word-8));
            if word=119 then expected(71 downto 64):=x"ED"; end if;
          elsif word=0 then
            expected:=x"BE" & std_logic_vector(to_unsigned(1000+ch,64));
          elsif word=1 then
            expected(63 downto 56):=std_logic_vector(to_unsigned(ch,8));
            expected(55 downto 52):=x"3";
            expected(50):='1';
            expected(45 downto 32):=std_logic_vector(to_unsigned(8000,14));
          elsif word=2 then
            expected(63 downto 0):=std_logic_vector(to_unsigned(511,9)) & "000000000" &
              std_logic_vector(to_unsigned(100*(ch+1),14)) & '1' &
              std_logic_vector(to_unsigned(51200*(ch+1),23)) & x"F1";
          elsif word=7 then expected(63 downto 0):=x"FFFFFFFF003FFFFF";
          else expected(63 downto 0):=x"FFFFFFFF7FFFFFFF";
          end if;
          assert packet_data=expected report "serialized data/descriptor differs at channel " & integer'image(ch) & " word " & integer'image(word) severity failure;
          assert packet_overflow='0' report "unexpected descriptor overflow" severity failure;
          writes(ch):=writes(ch)+1;
          if word=7 then
            assert writes(ch)=120 and packet_commit(ch)='1' report "record was not committed after all 120 writes" severity failure;
            commits:=commits+1;
          else assert packet_commit(ch)='0' report "partial record was committed" severity failure;
          end if;
        else assert packet_commit(ch)='0' report "commit without a packet write" severity failure;
        end if;
      end loop;
    end loop;
    report "afe_stc3_stream_serializer_tb PASS: four channels, 480 addressed writes and four complete commits" severity note;
    stop;
    wait;
  end process;
end;
