library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

-- Replay the pinned reference RTL with the identical DAT and CSV contracts
-- as stc3_trace_replay_tb. This bench must be analyzed against git-show source,
-- not the modified working-tree builder. Trailer inputs are intentionally quiet;
-- this baseline comparison validates waveform capture and packet scheduling.
entity stc3_reference_trace_replay_tb is
  generic (TRACE_G : string; OUTPUT_G : string; CHANNELS_G : positive := 2; OVERLAP_G : natural := 0);
end;
architecture test of stc3_reference_trace_replay_tb is
  type samples_t is array(natural range <>) of std_logic_vector(13 downto 0);
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ts : std_logic_vector(63 downto 0) := (others=>'0');
  signal adc : samples_t(0 to CHANNELS_G-1) := (others=>(others=>'0'));
  signal triggers : trigger_xcorr_result_array_t(0 to CHANNELS_G-1) := (others=>TRIGGER_XCORR_RESULT_NULL);
  signal ready, rd : std_logic_array_t(0 to 39) := (others=>'0');
  signal data : slv72_array_t(0 to 39) := (others=>(others=>'0'));
  signal outdata : array_2x64_type;
  signal valid,last : std_logic_vector(1 downto 0);
  signal records,packets,spacing,queues,rings,fulls,busys : slv64_array_t(0 to CHANNELS_G-1);
  function physical(c : natural) return natural is
  begin return (c/(CHANNELS_G/2))*20+c mod (CHANNELS_G/2); end;
begin
  assert CHANNELS_G mod 2=0 and CHANNELS_G<=40 and OVERLAP_G<=31 severity failure;
  clk <= not clk after 8 ns;
  channels : for c in 0 to CHANNELS_G-1 generate
    dut : entity work.stc3_record_builder port map(
      ch_id_i=>std_logic_vector(to_unsigned(physical(c),8)),version_i=>x"3",threshold_xc_i=>x"00007D0",signal_delay_i=>std_logic_vector(to_unsigned(OVERLAP_G,5)),
      clock_i=>clk,reset_i=>rst,reset_st_counters_i=>'0',enable_i=>'1',force_trigger_i=>'0',
      force_calibration_tag_i=>"00",timestamp_i=>ts,din_i=>adc(c),trigger_i=>triggers(c),
      trailer_capture_i=>'0',trailer_i=>PEAK_DESCRIPTOR_TRAILER_NULL,
      frame_match_o=>open,record_count_o=>records(c),full_count_o=>fulls(c),busy_count_o=>busys(c),
      spacing_reject_count_o=>spacing(c),queue_reject_count_o=>queues(c),ring_reject_count_o=>rings(c),output_reject_count_o=>open,
      trigger_count_o=>open,packet_count_o=>packets(c),delayed_sample_o=>open,ready_o=>ready(physical(c)),
      rd_en_i=>rd(physical(c)),dout_o=>data(physical(c)));
  end generate;
  mux : entity work.two_lane_readout_mux port map(clock_i=>clk,reset_i=>rst,ready_i=>ready,dout_i=>data,
    rd_en_o=>rd,dout_o=>outdata,valid_o=>valid,last_o=>last);
  replay : process
    file source : text open read_mode is TRACE_G;
    file sink : text open write_mode is OUTPUT_G;
    variable line_in,line_out : line;
    variable cycle,channel,sample,trig,trig_ts,baseline : integer;
    variable n : natural := 0;
    variable baseline_last : integer_vector(0 to CHANNELS_G-1) := (others=>8192);
    variable word_idx : integer_vector(0 to 1) := (others=>0);
    procedure capture is
    begin
      wait until rising_edge(clk); wait for 1 ns;
      for lane in 0 to 1 loop
        if valid(lane)='1' then
          write(line_out,n); write(line_out,string'(",")); write(line_out,lane);
          write(line_out,string'(",")); write(line_out,word_idx(lane)); write(line_out,string'(","));
          hwrite(line_out,outdata(lane)); write(line_out,string'(","));
          if last(lane)='1' then write(line_out,1); else write(line_out,0); end if;
          writeline(sink,line_out);
          if word_idx(lane)=119 then
            assert last(lane)='1' report "missing frame end" severity failure; word_idx(lane):=0;
          else
            assert last(lane)='0' report "short frame" severity failure; word_idx(lane):=word_idx(lane)+1;
          end if;
        else assert word_idx(lane)=0 report "gap within frame" severity failure;
        end if;
      end loop;
      wait until falling_edge(clk);
      n:=n+1;
    end;
  begin
    wait until falling_edge(clk); wait until falling_edge(clk); rst<='0';
    write(line_out,string'("cycle,lane,word,data,last")); writeline(sink,line_out);
    while not endfile(source) loop
      for c in 0 to CHANNELS_G-1 loop
        assert not endfile(source) report "partial input cycle" severity failure;
        readline(source,line_in); read(line_in,cycle); read(line_in,channel); read(line_in,sample);
        read(line_in,trig); read(line_in,trig_ts); read(line_in,baseline);
        assert cycle=n and channel=c report "trace order mismatch" severity failure;
        adc(c)<=std_logic_vector(to_unsigned(sample,14)); baseline_last(c):=baseline;
        triggers(c).enabled<='1'; triggers(c).baseline<=std_logic_vector(to_unsigned((16384-baseline) mod 16384,14));
        triggers(c).trigger_timestamp<=std_logic_vector(to_unsigned(trig_ts,64));
        triggers(c).trigger_sample<=std_logic_vector(to_unsigned(sample,14));
        if trig=1 then triggers(c).trigger_pulse<='1'; else triggers(c).trigger_pulse<='0'; end if;
      end loop;
      ts<=std_logic_vector(to_unsigned(n,64)); capture;
    end loop;
    -- Explicit quiet samples close any active chain and drain all reservations.
    for tail in 0 to 16383 loop
      for c in 0 to CHANNELS_G-1 loop
        triggers(c).trigger_pulse<='0'; adc(c)<=std_logic_vector(to_unsigned(baseline_last(c),14));
      end loop;
      ts<=std_logic_vector(to_unsigned(n,64)); capture;
    end loop;
    for c in 0 to CHANNELS_G-1 loop
      assert ready(physical(c))='0' report "undrained reference output packet" severity failure;
      assert records(c)=packets(c) report "undrained serializer reservations" severity failure;
      report "channel=" & integer'image(c) & " packets=" & integer'image(to_integer(unsigned(packets(c)))) &
        " spacing=" & integer'image(to_integer(unsigned(spacing(c)))) &
        " queue=" & integer'image(to_integer(unsigned(queues(c)))) &
        " ring=" & integer'image(to_integer(unsigned(rings(c)))) &
        " full=" & integer'image(to_integer(unsigned(fulls(c)))) &
        " busy=" & integer'image(to_integer(unsigned(busys(c)))) severity note;
    end loop;
    report "stc3_reference_trace_replay_tb PASS" severity note; stop; wait;
  end process;
end;
