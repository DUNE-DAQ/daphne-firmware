library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity fragment_peak_descriptors_compact_tb is end;
architecture test of fragment_peak_descriptors_compact_tb is
  signal clock_s : std_logic := '0';
  signal reset_s, start_s, valid_s, positive_s : std_logic := '0';
  signal baseline_s, sample_s : std_logic_vector(13 downto 0) := (others=>'0');
  signal sample_index_s : unsigned(8 downto 0) := (others=>'0');
  signal read_index_s : unsigned(2 downto 0) := (others=>'0');
  signal native_word_s, pipeline_word_s : std_logic_vector(63 downto 0);
  signal native_done_s, pipeline_done_s, native_overflow_s, pipeline_overflow_s : std_logic;
begin
  clock_s <= not clock_s after 5 ns;
  native_calculator : entity work.fragment_peak_descriptors_banked
    generic map(FRAME_SAMPLE_COUNT_G=>256, COMPACT_DESCRIPTOR_G=>true)
    port map(clock_i=>clock_s, reset_i=>reset_s, start_i=>start_s,
      baseline_i=>baseline_s, positive_pulse_i=>positive_s,
      threshold_i=>std_logic_vector(to_unsigned(10,14)), sample_valid_i=>valid_s,
      sample_i=>sample_s, sample_index_i=>sample_index_s, read_index_i=>read_index_s,
      read_word_o=>native_word_s, done_o=>native_done_s, overflow_o=>native_overflow_s);
  pipeline_calculator : entity work.fragment_peak_descriptors_banked
    generic map(PIPELINE_INPUT_G=>true, FRAME_SAMPLE_COUNT_G=>256, COMPACT_DESCRIPTOR_G=>true)
    port map(clock_i=>clock_s, reset_i=>reset_s, start_i=>start_s,
      baseline_i=>baseline_s, positive_pulse_i=>positive_s,
      threshold_i=>std_logic_vector(to_unsigned(10,14)), sample_valid_i=>valid_s,
      sample_i=>sample_s, sample_index_i=>sample_index_s, read_index_i=>read_index_s,
      read_word_o=>pipeline_word_s, done_o=>pipeline_done_s, overflow_o=>pipeline_overflow_s);
  stimulus : process
    type words_t is array(0 to 4) of std_logic_vector(63 downto 0);
    variable expected : words_t;
    variable run_start, run_length, run_integral, peak_height, peak_offset, run_count : natural;
    variable amplitude, raw_sample : natural;
    variable in_run : boolean;
    procedure tick is
    begin wait until rising_edge(clock_s); wait for 1 ns; end;
    function waveform(mode, index : natural) return natural is
    begin
      case mode is
        when 0 => return 16383; -- Full256 samples, largest exact22bit integral.
        when 1 => if index=255 then return 16383; end if;
        when 2 => if index=255 then return 1000; else return 20; end if;
        when 3 => if index<10 and index mod 2=0 then return 40; end if;
        when 4 => if (index<10 and index mod 2=0) or index=255 then return 50; end if;
        when 5 => return 10; -- Strict threshold equality remains inactive.
        when 6 => if index>=250 then return 20+(index mod 3)*10; end if;
        when others => return 0;
      end case;
      return 0;
    end;
    procedure close_run is
    begin
      if run_count<5 then
        expected(run_count):=(others=>'0');
        expected(run_count)(60):='1';
        expected(run_count)(59 downto 52):=std_logic_vector(to_unsigned(run_start,8));
        expected(run_count)(51 downto 44):=std_logic_vector(to_unsigned(peak_offset,8));
        expected(run_count)(43 downto 36):=std_logic_vector(to_unsigned(run_length-1,8));
        expected(run_count)(35 downto 22):=std_logic_vector(to_unsigned(peak_height,14));
        expected(run_count)(21 downto 0):=std_logic_vector(to_unsigned(run_integral,22));
      end if;
      run_count:=run_count+1; in_run:=false;
    end;
  begin
    reset_s<='1'; tick; reset_s<='0';
    for polarity in 0 to 1 loop
      for mode in 0 to 7 loop
        expected:=(others=>(others=>'0')); in_run:=false; run_count:=0;
        if polarity=0 then positive_s<='0'; baseline_s<=std_logic_vector(to_unsigned(16383,14));
        else positive_s<='1'; baseline_s<=(others=>'0'); end if;
        for index in 0 to 255 loop
          if index=0 then start_s<='1'; else start_s<='0'; end if;
          amplitude:=waveform(mode,index);
          if polarity=0 then raw_sample:=16383-amplitude; else raw_sample:=amplitude; end if;
          sample_s<=std_logic_vector(to_unsigned(raw_sample,14));
          sample_index_s<=to_unsigned(index,9); valid_s<='1';
          if amplitude>10 then
            if not in_run then
              run_start:=index; run_length:=0; run_integral:=0; peak_height:=0; peak_offset:=0;
              in_run:=true;
            end if;
            run_length:=run_length+1; run_integral:=run_integral+amplitude;
            if amplitude>peak_height then peak_height:=amplitude; peak_offset:=index-run_start; end if;
          elsif in_run then close_run; end if;
          if index=255 and in_run then close_run; end if;
          tick;
          if index=255 then assert native_done_s='1' report "compact final sample did not complete" severity failure;
          else assert native_done_s='0' report "compact early completion" severity failure; end if;
          if mode=6 and index mod 17=0 and index<255 then
            start_s<='0'; valid_s<='0'; tick;
            assert native_done_s='0' report "bubble completed compact frame" severity failure;
          end if;
        end loop;
        start_s<='0'; valid_s<='0'; tick;
        assert pipeline_done_s='0' report "pipeline completed one cycle too early" severity failure;
        tick;
        assert pipeline_done_s='1' report "pipeline compact completion latency changed" severity failure;
        if run_count>5 then
          assert native_overflow_s='1' and pipeline_overflow_s='1' report "sixth excursion overflow missing" severity failure;
        else assert native_overflow_s='0' and pipeline_overflow_s='0' severity failure; end if;
        for slot in 0 to 7 loop
          read_index_s<=to_unsigned(slot,3); wait for 1 ns;
          if slot<5 then
            assert native_word_s=expected(slot) and pipeline_word_s=expected(slot)
              report "compact codec mismatch mode=" & integer'image(mode) & " slot=" & integer'image(slot) severity failure;
          else assert native_word_s=x"0000000000000000" and pipeline_word_s=x"0000000000000000" severity failure; end if;
        end loop;
      end loop;
    end loop;
    reset_s<='1'; tick; read_index_s<=(others=>'0'); wait for 1 ns;
    assert native_word_s=x"0000000000000000" and pipeline_word_s=x"0000000000000000"
      report "reset exposed stale compact slot" severity failure;
    report "fragment_peak_descriptors_compact_tb PASS" severity note;
    stop; wait;
  end process;
end;
