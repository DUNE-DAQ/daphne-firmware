library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity gapless_readout_formal is
  port (clock_i, reset_i, credit_i : in std_logic;
        ready_i, end_i : in std_logic_vector(3 downto 0);
        data_i : in std_logic_vector(31 downto 0));
end;

architecture formal of gapless_readout_formal is
  signal ready_s, read_s : std_logic_array_t(0 to 3);
  signal input_s : slv72_array_t(0 to 3);
  signal output_s : array_64_type(0 downto 0);
  signal valid_s, last_s : std_logic_vector(0 downto 0);
begin
  channels : for ch in 0 to 3 generate
    ready_s(ch) <= ready_i(ch);
    input_s(ch) <= x"ED" & x"00000000000000" & data_i(8*ch+7 downto 8*ch)
      when end_i(ch)='1' else x"00" & x"00000000000000" & data_i(8*ch+7 downto 8*ch);
  end generate;
  dut : entity work.two_lane_readout_mux
    generic map(CHANNEL_COUNT_G=>4, LANE_COUNT_G=>1, CHANNELS_PER_LANE_G=>4, GAPLESS_G=>true)
    port map(clock_i=>clock_i, reset_i=>reset_i, ready_i=>ready_s, dout_i=>input_s,
      rd_en_o=>read_s, dout_o=>output_s, valid_o=>valid_s, last_o=>last_s,
      packet_ready_i(0)=>credit_i);

  contract : process(clock_i)
    variable initialized : boolean := false;
    variable expected_valid, expected_last : std_logic := '0';
    variable expected_data : std_logic_vector(63 downto 0) := (others=>'0');
    variable previous_credit : std_logic := '0';
    variable previous_ready : std_logic_vector(3 downto 0) := (others=>'0');
    variable packet_active, must_continue : boolean := false;
    variable active_channel, expected_channel, selected, count : natural range 0 to 4 := 0;
  begin
    if rising_edge(clock_i) then
      if initialized then
        assert valid_s(0)=expected_valid report "valid must follow consumed word" severity failure;
        assert last_s(0)=expected_last report "last must align with consumed end marker" severity failure;
        assert output_s(0)=expected_data report "readout changed selected data" severity failure;
      end if;
      initialized := true;
      count := 0; selected := 0;
      for ch in 0 to 3 loop
        if read_s(ch)='1' then count:=count+1; selected:=ch; end if;
      end loop;
      assert count<=1 report "multiple channels consumed on one lane" severity failure;
      expected_valid:='0'; expected_last:='0'; expected_data:=(others=>'0');
      if reset_i='1' then
        packet_active:=false; must_continue:=false;
      else
        if must_continue then
          assert count=1 and selected=expected_channel
            report "bubble or reorder at an admitted packet boundary" severity failure;
        end if;
        must_continue:=false;
        if packet_active then
          assert count=1 and selected=active_channel
            report "packet stalled or channels interleaved" severity failure;
        end if;
        if count=1 then
          if not packet_active then
            assert previous_credit='1' and previous_ready(selected)='1'
              report "packet started without admission" severity failure;
          end if;
          expected_valid:='1'; expected_last:=end_i(selected);
          expected_data:=input_s(selected)(63 downto 0);
          active_channel:=selected; packet_active:=end_i(selected)='0';
          expected_channel:=(selected+1) mod 4;
          must_continue:=end_i(selected)='1' and ready_i(expected_channel)='1' and credit_i='1';
        end if;
      end if;
      previous_credit:=credit_i; previous_ready:=ready_i;
    end if;
  end process;
end;
