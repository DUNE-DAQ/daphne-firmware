library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_subsystem_pkg.all;

entity fragment_peak_descriptors_tb is end;
architecture test of fragment_peak_descriptors_tb is
  signal clk : std_logic := '0';
  signal rst, start, positive, valid, done, overflow : std_logic := '0';
  signal baseline : std_logic_vector(13 downto 0) := std_logic_vector(to_unsigned(8000,14));
  signal threshold : std_logic_vector(13 downto 0) := std_logic_vector(to_unsigned(10,14));
  signal d0,d1 : std_logic_vector(13 downto 0) := (others=>'0');
  signal idx : unsigned(7 downto 0) := (others=>'0');
  signal t : peak_descriptor_trailer_t;
begin
  clk <= not clk after 8 ns;
  dut : entity work.fragment_peak_descriptors port map(
    clock_i=>clk,reset_i=>rst,start_i=>start,baseline_i=>baseline,
    positive_pulse_i=>positive,threshold_i=>threshold,pair_valid_i=>valid,
    sample0_i=>d0,sample1_i=>d1,pair_index_i=>idx,trailer_o=>t,
    done_o=>done,overflow_o=>overflow);
  process
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end;
    procedure frame(mode : natural; polarity : std_logic) is
      variable a0,a1 : integer;
      function amp(sample_index : natural) return natural is
      begin
        case mode is
          when 0 =>
            -- A run starting on an odd sample, a plateau with tied maximum,
            -- and a second run clipped by the fragment's final sample.
            if sample_index=3 then return 11;
            elsif sample_index=4 or sample_index=5 then return 30;
            elsif sample_index=6 then return 20;
            elsif sample_index>=510 then return 50;
            else return 0; end if;
          when 1 => return 0;
          when 2 => return 100;
          when 3 =>
            if sample_index<12 and sample_index mod 2=0 then return 40;
            else return 0; end if;
          when others => return 10; -- exactly threshold is quiet
        end case;
      end;
    begin
      positive<=polarity; start<='1'; valid<='0'; tick; start<='0';
      for p in 0 to 255 loop
        a0:=amp(2*p); a1:=amp(2*p+1);
        if polarity='0' then a0:=-a0; a1:=-a1; end if;
        d0<=std_logic_vector(to_unsigned(8000+a0,14));
        d1<=std_logic_vector(to_unsigned(8000+a1,14));
        idx<=to_unsigned(p,8); valid<='1'; tick;
        if p<255 then assert done='0' report "early descriptor completion" severity failure; end if;
        -- Exercise stalls without advancing the fragment sample index.
        if p mod 17=0 and p<255 then valid<='0'; tick; end if;
      end loop;
      assert done='1' report "last pair did not commit descriptors" severity failure;
      valid<='0';
    end;
  begin
    rst<='1'; tick; rst<='0'; tick;
    for pol in 0 to 1 loop
      if pol=0 then frame(0,'0'); else frame(0,'1'); end if;
      assert t(0)(31)='1' and unsigned(t(0)(30 downto 8))=91 severity failure;
      assert unsigned(t(1)(31 downto 23))=4 report "run duration wrong" severity failure;
      assert unsigned(t(1)(22 downto 14))=1 report "first maximum offset wrong" severity failure;
      assert unsigned(t(1)(13 downto 0))=30 severity failure;
      assert unsigned(t(10)(31 downto 22))=3 severity failure;
      assert unsigned(t(2)(30 downto 8))=100 severity failure;
      assert unsigned(t(3)(31 downto 23))=2 severity failure;
      assert unsigned(t(10)(21 downto 12))=510 severity failure;
      assert t(4)=x"7FFFFFFF" and t(5)=x"FFFFFFFF" severity failure;
      assert overflow='0' severity failure;
      tick; assert done='0' severity failure;
    end loop;
    frame(1,'0');
    for slot in 0 to 4 loop
      assert t(2*slot)=x"7FFFFFFF" and t(2*slot+1)=x"FFFFFFFF"
        report "previous fragment leaked into empty fragment" severity failure;
    end loop;
    tick;
    frame(2,'0');
    assert unsigned(t(0)(30 downto 8))=51200 report "full fragment integral wrong" severity failure;
    assert unsigned(t(1)(31 downto 23))=511 report "duration must saturate, not wrap" severity failure;
    assert unsigned(t(10)(31 downto 22))=0 severity failure;
    tick;
    frame(3,'0');
    assert overflow='1' report "sixth excursion must flag descriptor overflow" severity failure;
    for slot in 0 to 4 loop
      assert unsigned(t(2*slot)(30 downto 8))=40 severity failure;
    end loop;
    tick;
    frame(4,'1');
    assert t(0)=x"7FFFFFFF" and overflow='0' severity failure;
    -- Reset in an unfinished fragment and ignore stray valid pairs afterward.
    start<='1'; tick; start<='0'; valid<='1'; idx<=to_unsigned(0,8); tick;
    rst<='1'; tick; rst<='0'; idx<=to_unsigned(255,8); tick;
    assert done='0' and t(0)=x"7FFFFFFF" severity failure;
    report "fragment_peak_descriptors_tb PASS" severity note;
    stop;
    wait;
  end process;
end;
