library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity stc3_continuation_tb is
  generic (ODD_START_G : natural := 0);
end;
architecture test of stc3_continuation_tb is
  constant TRIG_TS_C : natural := 236+ODD_START_G;
  constant FIRST_C : natural := TRIG_TS_C-64;
  constant QUIET_AT_C : natural := 15000;
  constant END_C : natural := 18000;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ts : std_logic_vector(63 downto 0) := (others=>'0');
  signal adc : std_logic_vector(13 downto 0) := (others=>'0');
  signal trigger : trigger_xcorr_result_t := TRIGGER_XCORR_RESULT_NULL;
  signal ready, rd : std_logic_array_t(0 to 39) := (others=>'0');
  signal data : slv72_array_t(0 to 39) := (others=>(others=>'0'));
  signal outdata : array_2x64_type;
  signal valid,last : std_logic_vector(1 downto 0);
  signal records,fulls,busys,packets,conts,contdrops,covered : std_logic_vector(63 downto 0);
  signal observed : natural := 0;
  function raw_sample(n:natural) return natural is
  begin
    if n<TRIG_TS_C or n>=QUIET_AT_C then return 8000;
    else return 1000+(n mod 997); end if;
  end;
begin
  clk <= not clk after 8 ns;
  dut : entity work.stc3_record_builder port map(
    ch_id_i=>x"00",version_i=>x"3",threshold_xc_i=>x"0012345",signal_delay_i=>"00000",
    clock_i=>clk,reset_i=>rst,reset_st_counters_i=>'0',enable_i=>'1',force_trigger_i=>'0',
    force_calibration_tag_i=>"00",timestamp_i=>ts,din_i=>adc,trigger_i=>trigger,
    continuation_enable_i=>'1',positive_pulse_i=>'0',activity_threshold_i=>std_logic_vector(to_unsigned(64,14)),
    quiet_samples_i=>std_logic_vector(to_unsigned(32,9)),trailer_capture_i=>'0',
    trailer_i=>PEAK_DESCRIPTOR_TRAILER_NULL,frame_match_o=>open,
    record_count_o=>records,full_count_o=>fulls,busy_count_o=>busys,
    spacing_reject_count_o=>open,queue_reject_count_o=>open,ring_reject_count_o=>open,output_reject_count_o=>open,
    trigger_count_o=>open,packet_count_o=>packets,delayed_sample_o=>open,ready_o=>ready(0),rd_en_i=>rd(0),dout_o=>data(0),
    continuation_count_o=>conts,continuation_drop_count_o=>contdrops,covered_trigger_count_o=>covered,
    descriptor_overflow_count_o=>open);
  mux : entity work.two_lane_readout_mux port map(clock_i=>clk,reset_i=>rst,ready_i=>ready,dout_i=>data,
    rd_en_o=>rd,dout_o=>outdata,valid_o=>valid,last_o=>last);
  source : process
  begin
    wait until falling_edge(clk); wait until falling_edge(clk); rst<='0';
    trigger.enabled<='1'; trigger.baseline<=std_logic_vector(to_unsigned(8000,14));
    trigger.calibration_tag<=CALIBRATION_TAG_TIMING_C;
    for n in 0 to END_C loop
      ts<=std_logic_vector(to_unsigned(n,64)); adc<=std_logic_vector(to_unsigned(raw_sample(n),14));
      trigger.trigger_pulse<='0';
      if n=TRIG_TS_C+64 or n=TRIG_TS_C+64+3000 then
        trigger.trigger_pulse<='1'; trigger.trigger_timestamp<=std_logic_vector(to_unsigned(n-64,64));
        trigger.trigger_sample<=std_logic_vector(to_unsigned(raw_sample(n-64),14));
      end if;
      wait until falling_edge(clk);
    end loop;
    assert unsigned(fulls)=0 and unsigned(busys)=0 and unsigned(contdrops)=0 report "unexpected capture loss under admissible load" severity failure;
    assert observed>25 and to_integer(unsigned(records))=observed and to_integer(unsigned(packets))=observed
      report "incomplete or unexpected packet accounting" severity failure;
    assert to_integer(unsigned(conts))=observed-1 and unsigned(covered)=1 severity failure;
    assert FIRST_C+observed*512>=QUIET_AT_C+32 and FIRST_C+(observed-1)*512<QUIET_AT_C+32
      report "quiet termination did not round up to the necessary final fragment" severity failure;
    report "stc3_continuation_tb PASS odd=" & integer'image(ODD_START_G) & " packets=" & integer'image(observed) severity note;
    stop; wait;
  end process;
  sink : process(clk)
    variable word_index : natural range 0 to 119 := 0;
    variable packet_start : natural := 0;
    variable previous_start : natural := 0;
    variable payload : std_logic_vector(7167 downto 0);
    variable n : natural;
  begin
    if rising_edge(clk) and rst='0' then
      if valid(0)='1' then
        if word_index=0 then
          packet_start:=to_integer(unsigned(outdata(0)));
          if observed=0 then assert packet_start=FIRST_C report "wrong initial sample timestamp" severity failure;
          else assert packet_start=previous_start+512 report "gap or overlap in admitted chain" severity failure; end if;
          previous_start:=packet_start;
        elsif word_index=1 then
          assert outdata(0)(63 downto 56)=x"00" and outdata(0)(55 downto 52)=x"3" severity failure;
          assert outdata(0)(47 downto 46)=CALIBRATION_TAG_TIMING_C report "calibration tag changed" severity failure;
          assert outdata(0)(50)='1' report "fragment descriptor semantics flag missing" severity failure;
          if observed=0 then assert outdata(0)(51)='0' severity failure;
          else assert outdata(0)(51)='1' severity failure; end if;
        elsif word_index>=8 then
          payload((word_index-8)*64+63 downto (word_index-8)*64):=outdata(0);
        end if;
        if word_index=119 then
          assert last(0)='1' report "missing last at word120" severity failure;
          for s in 0 to 511 loop
            n:=to_integer(unsigned(payload(14*s+13 downto 14*s)));
            assert n=raw_sample(packet_start+s)
              report "sample mismatch frame=" & integer'image(observed) & " index=" & integer'image(s) &
              " got=" & integer'image(n) & " expected=" & integer'image(raw_sample(packet_start+s)) severity failure;
          end loop;
          observed<=observed+1; word_index:=0;
        else
          assert last(0)='0' report "short packet" severity failure;
          word_index:=word_index+1;
        end if;
      elsif word_index/=0 then
        assert false report "transport stalled inside a committed packet" severity failure;
      end if;
    end if;
  end process;
end;
