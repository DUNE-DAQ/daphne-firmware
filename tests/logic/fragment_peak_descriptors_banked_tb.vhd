library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_subsystem_pkg.all;

entity fragment_peak_descriptors_banked_tb is end;
architecture test of fragment_peak_descriptors_banked_tb is
  signal clk : std_logic := '0';
  signal rst, start, positive, valid : std_logic := '0';
  signal done, overflow, reference_done, reference_overflow : std_logic;
  signal baseline, threshold, sample : std_logic_vector(13 downto 0) := (others=>'0');
  signal sample_index : unsigned(8 downto 0) := (others=>'0');
  signal read_index : unsigned(2 downto 0) := (others=>'0');
  signal read_word : std_logic_vector(63 downto 0);
  signal reference_trailer : peak_descriptor_trailer_t;
begin
  clk <= not clk after 8 ns;
  dut : entity work.fragment_peak_descriptors_banked port map(
    clock_i=>clk, reset_i=>rst, start_i=>start, baseline_i=>baseline,
    positive_pulse_i=>positive, threshold_i=>threshold, sample_valid_i=>valid,
    sample_i=>sample, sample_index_i=>sample_index, read_index_i=>read_index,
    read_word_o=>read_word, done_o=>done, overflow_o=>overflow);
  reference : entity work.fragment_peak_descriptors_serial port map(
    clock_i=>clk, reset_i=>rst, start_i=>start, baseline_i=>baseline,
    positive_pulse_i=>positive, threshold_i=>threshold, sample_valid_i=>valid,
    sample_i=>sample, sample_index_i=>sample_index, trailer_o=>reference_trailer,
    done_o=>reference_done, overflow_o=>reference_overflow);

  process
    variable completed : peak_descriptor_trailer_t := (others=>(others=>'1'));
    variable completed_overflow : std_logic := '0';
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end;
    procedure check_completed is
    begin
      assert overflow=completed_overflow report "completed overflow changed before the next done" severity failure;
      for word in 0 to 5 loop
        read_index <= to_unsigned(word,3);
        wait for 1 ns;
        assert read_word=completed(2*word+1)&completed(2*word)
          report "indexed completed word mismatch at index " & integer'image(word) severity failure;
      end loop;
      for word in 6 to 7 loop
        read_index <= to_unsigned(word,3);
        wait for 1 ns;
        assert read_word=x"FFFFFFFF7FFFFFFF" report "unused read index sentinel wrong" severity failure;
      end loop;
    end;
    procedure frame(mode : natural; polarity : std_logic; stalls : boolean := false) is
      variable raw, base, level : integer;
      function amplitude(p : natural) return natural is
      begin
        case mode is
          when 0 =>
            if p=3 then return 11;
            elsif p=4 or p=5 then return 30;
            elsif p=6 then return 20;
            elsif p>=510 then return 50;
            else return 0; end if;
          when 1 =>
            if p<12 and p mod 2=0 then return 40; else return 0; end if;
          when 2 =>
            if p=3 or p=5 or p=7 or p=9 then return 40;
            elsif p=509 then return 20;
            elsif p>=510 then return 30;
            else return 0; end if;
          when 3 =>
            if p<10 and p mod 2=0 then return 40;
            elsif p=511 then return 300;
            else return 0; end if;
          when 4 => return 10; -- Equality to threshold is inactive.
          when 5 => return 100;
          when 6 => return 16383;
          when 7 => if p=511 then return 16383; else return 0; end if;
          when others => return 0;
        end case;
      end;
    begin
      base := 8000; level := 10;
      if mode=6 or mode=7 then
        level := 0;
        if polarity='1' then base := 0; else base := 16383; end if;
      end if;
      baseline <= std_logic_vector(to_unsigned(base,14));
      threshold <= std_logic_vector(to_unsigned(level,14));
      positive <= polarity;
      for p in 0 to 511 loop
        if p=0 then start<='1'; else start<='0'; end if;
        if polarity='1' then raw := base+amplitude(p); else raw := base-amplitude(p); end if;
        sample <= std_logic_vector(to_unsigned(raw,14));
        sample_index <= to_unsigned(p,9); valid <= '1'; tick;
        assert done=reference_done report "done differs from serial helper" severity failure;
        if p=511 then
          assert done='1' report "last sample did not publish a bank" severity failure;
          completed := reference_trailer; completed_overflow := reference_overflow;
        else
          assert done='0' report "early bank publication" severity failure;
        end if;
        -- Sweep all words while accepting one sample every clock. The previous
        -- completed bank must stay unchanged, even as new excursions close.
        check_completed;
        if stalls and p mod 17=0 and p<511 then
          start <= '0'; valid <= '0'; tick;
          assert done='0' severity failure;
          check_completed;
        end if;
      end loop;
      valid <= '0'; start <= '0';
    end;
  begin
    for k in 0 to 4 loop completed(2*k) := x"7FFFFFFF"; end loop;
    rst <= '1'; tick; rst <= '0'; check_completed;
    -- Every frame call follows sample511 immediately with start plus sample0.
    -- Opposite polarities, filled/empty banks and overflow alternate repeatedly.
    frame(0,'1',true);
    assert unsigned(completed(0)(30 downto 8))=91 severity failure;
    assert unsigned(completed(1)(31 downto 23))=4 and unsigned(completed(1)(22 downto 14))=1 severity failure;
    assert unsigned(completed(2)(30 downto 8))=100 and unsigned(completed(10)(21 downto 12))=510 severity failure;
    frame(1,'0');
    assert completed_overflow='1' report "sixth excursion must overflow" severity failure;
    frame(2,'1');
    assert completed_overflow='0' and unsigned(completed(8)(30 downto 8))=80 severity failure;
    assert unsigned(completed(9)(31 downto 23))=3 and unsigned(completed(9)(22 downto 14))=1 severity failure;
    assert unsigned(completed(11)(21 downto 12))=509 report "fifth offset missing" severity failure;
    frame(3,'0');
    assert completed_overflow='1' and unsigned(completed(8)(30 downto 8))=40 severity failure;
    assert unsigned(completed(11)(21 downto 12))=8 report "final-sample overflow corrupted slot4" severity failure;
    frame(4,'1');
    for k in 0 to 4 loop
      assert completed(2*k)=x"7FFFFFFF" and completed(2*k+1)=x"FFFFFFFF" severity failure;
    end loop;
    assert completed(10)=x"FFFFFFFF" and completed(11)=x"FFFFFFFF" and completed_overflow='0' severity failure;
    frame(5,'0');
    assert unsigned(completed(0)(30 downto 8))=51200 and unsigned(completed(1)(31 downto 23))=511 severity failure;
    frame(6,'1');
    assert unsigned(completed(0)(30 downto 8))=8388096 and unsigned(completed(1)(13 downto 0))=16383 severity failure;
    frame(7,'0');
    assert unsigned(completed(0)(30 downto 8))=16383 and unsigned(completed(10)(31 downto 22))=511 severity failure;
    frame(8,'1');
    assert completed(0)=x"7FFFFFFF" and completed_overflow='0' severity failure;
    -- Restart an unfinished frame without exposing its partial descriptors.
    start <= '1'; valid <= '1'; sample_index <= (others=>'0'); sample <= std_logic_vector(to_unsigned(8100,14));
    tick; check_completed;
    start <= '0'; sample_index <= to_unsigned(1,9); sample <= std_logic_vector(to_unsigned(8000,14));
    tick; check_completed;
    frame(2,'0');
    -- Reset masks both banks without resetting the payload RAM.
    rst <= '1'; tick; rst <= '0';
    completed := (others=>(others=>'1')); completed_overflow := '0';
    for k in 0 to 4 loop completed(2*k) := x"7FFFFFFF"; end loop;
    check_completed;
    valid <= '1'; sample_index <= to_unsigned(511,9); tick;
    assert done='0' report "stray sample after reset published a bank" severity failure;
    check_completed;
    report "fragment_peak_descriptors_banked_tb PASS" severity note;
    stop;
    wait;
  end process;
end;
