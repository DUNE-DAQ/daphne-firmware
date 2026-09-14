library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_subsystem_pkg.all;

entity stc3_continuation_overload_tb is end;
architecture tb of stc3_continuation_overload_tb is
  constant BASE_TS_C : unsigned(63 downto 0) := to_unsigned(1000000,64);
  constant FIRST_SAMPLE_C : natural := 236;
  constant ACTIVITY_END_C : natural := 31000;
  constant DRAIN_START_C : natural := 23000;
  signal clock_s : std_logic := '0';
  signal reset_s, force_s, drain_s : std_logic := '0';
  signal ts_s : std_logic_vector(63 downto 0) := (others=>'0');
  signal adc_s : std_logic_vector(13 downto 0) := (others=>'0');
  signal trigger_s : trigger_xcorr_result_t := TRIGGER_XCORR_RESULT_NULL;
  signal ready_s, rd_s : std_logic;
  signal data_s : std_logic_vector(71 downto 0);
  signal records_s, packets_s, cont_s, cont_drop_s, covered_s, ring_drop_s, queue_drop_s, busy_s, full_s : std_logic_vector(63 downto 0);
  signal observed_s, skipped_s : natural := 0;
  function adc(cycle : natural) return natural is
  begin
    if cycle>=ACTIVITY_END_C then return 16000; end if;
    -- Prime period does not repeat at ring/packet boundaries: reading samples
    -- after2048-sample overwrite cannot accidentally match the reference.
    return 1000+(cycle mod 8191);
  end;
begin
  clock_s<=not clock_s after 8 ns;
  rd_s<=ready_s and drain_s;
  dut : entity work.stc3_record_builder
    port map(ch_id_i=>X"03", version_i=>X"5", threshold_xc_i=>(others=>'0'), signal_delay_i=>(others=>'0'),
      clock_i=>clock_s, reset_i=>reset_s, reset_st_counters_i=>'0', enable_i=>'1',
      force_trigger_i=>force_s, force_calibration_tag_i=>CALIBRATION_TAG_SOFTWARE_C,
      timestamp_i=>ts_s, din_i=>adc_s, trigger_i=>trigger_s,
      continuation_enable_i=>'1', positive_pulse_i=>'0',
      activity_threshold_i=>std_logic_vector(to_unsigned(64,14)), quiet_samples_i=>std_logic_vector(to_unsigned(32,9)),
      trailer_capture_i=>'0', trailer_i=>PEAK_DESCRIPTOR_TRAILER_NULL,
      frame_match_o=>open, record_count_o=>records_s, full_count_o=>full_s, busy_count_o=>busy_s,
      spacing_reject_count_o=>open, queue_reject_count_o=>queue_drop_s, ring_reject_count_o=>ring_drop_s,
      output_reject_count_o=>open, trigger_count_o=>open, packet_count_o=>packets_s,
      continuation_count_o=>cont_s, continuation_drop_count_o=>cont_drop_s,
      covered_trigger_count_o=>covered_s, descriptor_overflow_count_o=>open,
      delayed_sample_o=>open, ready_o=>ready_s, rd_en_i=>rd_s, dout_o=>data_s);

  scoreboard : process(clock_s)
    variable word_idx, packet_idx, fragment_start, previous_start, skipped, jump : natural := 0;
    variable waveform : std_logic_vector(7167 downto 0) := (others=>'0');
  begin
    if rising_edge(clock_s) then
      if reset_s='1' then
        word_idx:=0; packet_idx:=0; skipped:=0; previous_start:=0; observed_s<=0; skipped_s<=0;
      elsif rd_s='1' then
        if word_idx=0 then
          assert data_s(71 downto 64)=X"BE" report "overload recovery missing packet start" severity failure;
          fragment_start:=to_integer(unsigned(data_s(63 downto 0))-BASE_TS_C);
          assert fragment_start>=FIRST_SAMPLE_C and (fragment_start-FIRST_SAMPLE_C) mod 512=0
            report "recovery shifted the512-sample grid" severity failure;
          if packet_idx=0 then
            assert fragment_start=FIRST_SAMPLE_C report "oldest reserved packet was overwritten" severity failure;
          else
            assert fragment_start>previous_start report "duplicate or out-of-order packet after overload" severity failure;
            jump:=fragment_start-previous_start;
            assert jump mod 512=0 report "overload dropped a partial fragment" severity failure;
            skipped:=skipped+jump/512-1;
          end if;
        elsif word_idx=1 then
          assert data_s(63 downto 56)=X"03" and data_s(55 downto 52)=X"5"
            report "overload corrupted channel/version fields" severity failure;
          assert data_s(50)='1' and data_s(49)='0' and data_s(47 downto 46)=CALIBRATION_TAG_SOFTWARE_C
            report "overload corrupted descriptor/calibration flags" severity failure;
          if packet_idx=0 then assert data_s(51)='0' severity failure;
          else assert data_s(51)='1' report "recovery lost the continuation flag" severity failure; end if;
        elsif word_idx>=8 then
          waveform((word_idx-8)*64+63 downto (word_idx-8)*64):=data_s(63 downto 0);
        end if;
        if word_idx=119 then
          assert data_s(71 downto 64)=X"ED" report "packet exceeds120 words after overload" severity failure;
          for i in 0 to 511 loop
            assert to_integer(unsigned(waveform(i*14+13 downto i*14)))=adc(fragment_start+i)
              report "overload waveform corruption start="&integer'image(fragment_start)&" sample="&integer'image(i) severity failure;
          end loop;
          word_idx:=0; packet_idx:=packet_idx+1; previous_start:=fragment_start;
          observed_s<=packet_idx; skipped_s<=skipped;
        else
          assert data_s(71 downto 64)/=X"ED" report "short packet after overload" severity failure;
          word_idx:=word_idx+1;
        end if;
      end if;
    end if;
  end process;
  stimulus : process
  begin
    reset_s<='1';
    wait until rising_edge(clock_s); wait until rising_edge(clock_s); wait for 1 ns;
    reset_s<='0';
    trigger_s.baseline<=std_logic_vector(to_unsigned(16000,14));
    for t in 0 to 36000 loop
      ts_s<=std_logic_vector(BASE_TS_C+t); adc_s<=std_logic_vector(to_unsigned(adc(t),14));
      force_s<='0'; if t=300 then force_s<='1'; end if;
      if t=DRAIN_START_C then drain_s<='1'; end if;
      wait until rising_edge(clock_s); wait for 1 ns;
      if t=DRAIN_START_C-1 then
        assert observed_s=0 and unsigned(packets_s)=32 and unsigned(records_s)=32
          report "packet store did not hold exactly32 complete reserved frames" severity failure;
        assert unsigned(cont_drop_s)>0 and ready_s='1'
          report "withheld readout did not exercise packet-credit exhaustion" severity failure;
      end if;
    end loop;
    assert observed_s=48 and skipped_s=13 report "unexpected overload/recovery schedule" severity failure;
    assert unsigned(records_s)=observed_s and unsigned(packets_s)=observed_s and unsigned(cont_s)=observed_s-1
      report "admission, completion, and drain counts do not conserve packets" severity failure;
    assert unsigned(cont_drop_s)=skipped_s and unsigned(full_s)=skipped_s
      report "whole-fragment drop counter disagrees with skipped timestamp windows" severity failure;
    assert unsigned(busy_s)=0 and unsigned(queue_drop_s)=0 and unsigned(ring_drop_s)=0
      report "unexpected queue/ring failure under output-credit exhaustion" severity failure;
    assert ready_s='0' report "unconsumed or partial packet remained after recovery" severity failure;
    report "stc3_continuation_overload_tb PASS:48 packets,13 whole-fragment drops, recovery" severity note;
    stop; wait;
  end process;
end architecture;
