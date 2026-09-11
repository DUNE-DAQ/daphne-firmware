library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity trig_xc_alignment_tb is end;
architecture tb of trig_xc_alignment_tb is
  constant BASE_C : unsigned(63 downto 0) := X"FFFFFFFFFFFFFFC0";
  signal clock_s : std_logic := '0';
  signal reset_s, strobe_s, trig_s : std_logic := '0';
  signal din_s, sample_s : std_logic_vector(13 downto 0) := (others=>'0');
  signal ts_s, event_ts_s : std_logic_vector(63 downto 0) := (others=>'0');
  function adc(cycle : natural) return unsigned is
  begin return to_unsigned((cycle*37+9) mod 16384,14); end;
  function event_at(cycle : integer) return boolean is
  begin
    return cycle=5 or cycle=40 or cycle=43 or cycle=60 or cycle=70 or
           cycle=100 or cycle=101 or cycle=102 or cycle=155 or cycle=170 or cycle=174 or
           (cycle>=250 and cycle<=260 and cycle mod 2=0) or cycle=300;
  end;
  function reset_at(cycle : integer) return boolean is
  begin return cycle<=2 or (cycle>=170 and cycle<=172); end;
begin
  clock_s<=not clock_s after 8 ns;
  dut : entity work.trig_xc
    port map(clock=>clock_s,reset=>reset_s,din=>din_s,enable=>'1',afe_comp_enable=>'0',invert_enable=>'0',
      adhoc=>X"A5",filter_output_selector=>"00",ti_trigger=>X"A5",ti_trigger_stbr=>strobe_s,
      threshold_xc=>(others=>'0'),ts=>ts_s,baseline=>open,dout1=>open,dout2=>open,
      trig_sample_dat=>sample_s,trig_sample_ts=>event_ts_s,trig=>trig_s);
  stimulus : process
    variable flush_age : natural range 0 to 64 := 0;
    variable original_cycle : integer;
    variable expected : boolean;
    variable seen : natural := 0;
  begin
    for cycle in 0 to 380 loop
      din_s<=std_logic_vector(adc(cycle)); ts_s<=std_logic_vector(BASE_C+cycle);
      strobe_s<='0'; if event_at(cycle) then strobe_s<='1'; end if;
      reset_s<='0';
      if reset_at(cycle) then reset_s<='1'; flush_age:=0;
      elsif flush_age<64 then flush_age:=flush_age+1; end if;
      wait until rising_edge(clock_s); wait for 1 ns;
      original_cycle:=cycle-63;
      expected:=flush_age=64 and event_at(original_cycle) and not reset_at(cycle);
      if expected then
        assert trig_s='1' report "aligned trigger missing at cycle"&integer'image(cycle) severity failure;
        assert sample_s=std_logic_vector(adc(original_cycle-1))
          report "closely spaced trigger reused another event's sample" severity failure;
        assert unsigned(event_ts_s)=BASE_C+to_unsigned(original_cycle-1,64)
          report "closely spaced trigger reused another event's timestamp" severity failure;
        seen:=seen+1;
      else
        assert trig_s='0' report "unexpected or stale trigger after reset at cycle"&integer'image(cycle) severity failure;
      end if;
    end loop;
    assert seen=16 report "alignment fixture did not exercise all expected events" severity failure;
    report "trig_xc_alignment_tb PASS: isolated, close, adjacent, reset, timestamp wrap" severity note;
    stop; wait;
  end process;
end architecture;
