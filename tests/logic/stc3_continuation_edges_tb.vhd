library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_subsystem_pkg.all;

entity stc3_continuation_edges_tb is end;
architecture tb of stc3_continuation_edges_tb is
  constant BASE_C : unsigned(63 downto 0) := X"FFFFFFFFFFFFFE00";
  signal clock_s : std_logic := '0';
  signal reset_s, reset_counts_s, enable_s, force_s, drain_s : std_logic := '0';
  signal ts_s : std_logic_vector(63 downto 0) := (others=>'0');
  signal adc_s : std_logic_vector(13 downto 0) := std_logic_vector(to_unsigned(4096,14));
  signal trigger_s : trigger_xcorr_result_t := TRIGGER_XCORR_RESULT_NULL;
  signal ready_s, rd_s : std_logic;
  signal data_s : std_logic_vector(71 downto 0);
  signal records_s, packets_s, cont_s, cont_drop_s, covered_s, ring_drop_s, busy_s, full_s : std_logic_vector(63 downto 0);
  signal phase_s : natural := 0;
  signal observed_s : natural := 0;
  function expected_start(phase, packet : natural) return natural is
  begin
    case phase is
      when 0 | 1 => if packet=0 then return 236; else return 748; end if;
      when 2 => return 636;
      when 3 => if packet=0 then return 89; else return 601; end if;
      when others => return 236;
    end case;
  end;
begin
  clock_s<=not clock_s after 8 ns;
  rd_s<=ready_s and drain_s;
  dut : entity work.stc3_record_builder
    port map(ch_id_i=>X"03", version_i=>X"5", threshold_xc_i=>(others=>'0'), signal_delay_i=>(others=>'0'),
      clock_i=>clock_s, reset_i=>reset_s, reset_st_counters_i=>reset_counts_s, enable_i=>enable_s,
      force_trigger_i=>force_s, force_calibration_tag_i=>CALIBRATION_TAG_SOFTWARE_C,
      timestamp_i=>ts_s, din_i=>adc_s, trigger_i=>trigger_s,
      continuation_enable_i=>'1', positive_pulse_i=>'0',
      activity_threshold_i=>std_logic_vector(to_unsigned(64,14)), quiet_samples_i=>std_logic_vector(to_unsigned(32,9)),
      trailer_capture_i=>'0', trailer_i=>PEAK_DESCRIPTOR_TRAILER_NULL,
      frame_match_o=>open, record_count_o=>records_s, full_count_o=>full_s, busy_count_o=>busy_s,
      spacing_reject_count_o=>open, queue_reject_count_o=>open, ring_reject_count_o=>ring_drop_s,
      output_reject_count_o=>open, trigger_count_o=>open, packet_count_o=>packets_s,
      continuation_count_o=>cont_s, continuation_drop_count_o=>cont_drop_s,
      covered_trigger_count_o=>covered_s, descriptor_overflow_count_o=>open,
      delayed_sample_o=>open, ready_o=>ready_s, rd_en_i=>rd_s, dout_o=>data_s);

  scoreboard : process(clock_s)
    variable word_idx, packet_idx : natural := 0;
    variable waveform : std_logic_vector(7167 downto 0) := (others=>'0');
  begin
    if rising_edge(clock_s) then
      if reset_s='1' then word_idx:=0; packet_idx:=0; observed_s<=0;
      elsif rd_s='1' then
        if word_idx=0 then
          assert data_s(71 downto 64)=X"BE" report "missing start marker" severity failure;
          assert unsigned(data_s(63 downto 0))=BASE_C+expected_start(phase_s,packet_idx)
            report "edge test timestamp/spacing mismatch phase="&integer'image(phase_s)&" packet="&integer'image(packet_idx) severity failure;
        elsif word_idx=1 then
          assert data_s(50)='1' report "missing fragment descriptor format flag" severity failure;
          if (phase_s=0 or phase_s=3) and packet_idx=1 then
            assert data_s(51)='1' report "reopened continuation flag missing" severity failure;
          else assert data_s(51)='0' report "independent packet marked continuation" severity failure; end if;
          assert data_s(47 downto 46)=CALIBRATION_TAG_SOFTWARE_C report "calibration tag lost" severity failure;
        elsif word_idx>=8 then waveform((word_idx-8)*64+63 downto (word_idx-8)*64):=data_s(63 downto 0);
        end if;
        if word_idx=119 then
          assert data_s(71 downto 64)=X"ED" report "missing end marker at word119" severity failure;
          for i in 0 to 511 loop
            assert unsigned(waveform(i*14+13 downto i*14))=4096
              report "edge test waveform corruption" severity failure;
          end loop;
          word_idx:=0; packet_idx:=packet_idx+1; observed_s<=packet_idx;
        else
          assert data_s(71 downto 64)/=X"ED" report "short packet" severity failure;
          word_idx:=word_idx+1;
        end if;
      end if;
    end if;
  end process;
  stimulus : process
    procedure restart(phase : natural) is
    begin
      reset_s<='1'; reset_counts_s<='0'; enable_s<='1'; force_s<='0'; drain_s<='1'; phase_s<=phase;
      trigger_s<=TRIGGER_XCORR_RESULT_NULL;
      wait until rising_edge(clock_s); wait until rising_edge(clock_s); wait for 1 ns;
      reset_s<='0';
    end procedure;
    procedure sample(cycle : natural; force_trigger : boolean := false; natural_trigger : boolean := false; event_cycle : natural := 0) is
    begin
      ts_s<=std_logic_vector(BASE_C+cycle);
      trigger_s.baseline<=std_logic_vector(to_unsigned(4096,14));
      trigger_s.trigger_sample<=std_logic_vector(to_unsigned(4096,14));
      trigger_s.trigger_timestamp<=std_logic_vector(BASE_C+event_cycle);
      trigger_s.calibration_tag<=CALIBRATION_TAG_SOFTWARE_C;
      trigger_s.trigger_pulse<='0'; if natural_trigger then trigger_s.trigger_pulse<='1'; end if;
      force_s<='0'; if force_trigger then force_s<='1'; end if;
      wait until rising_edge(clock_s); wait for 1 ns;
    end procedure;
  begin
    -- Raw ADC is quiet at the endpoint. A delayed trigger from the preceding
    -- fragment must reopen exactly the adjacent fragment across timestamp wrap.
    restart(0);
    for t in 0 to 2100 loop sample(t,t=300,t=780,720); end loop;
    assert observed_s=2 and unsigned(cont_s)=1 and unsigned(covered_s)=1
      report "late quiet-chain reopening failed" severity failure;
    assert unsigned(busy_s)=0 and unsigned(full_s)=0 severity failure;

    -- Two independent first triggers exactly512 clocks apart straddle64-bit
    -- timestamp wrap. Both fragments are complete and the second has CONT=0.
    restart(1);
    for t in 0 to 2100 loop sample(t,t=300 or t=812); end loop;
    assert observed_s=2 and unsigned(cont_s)=0 and unsigned(busy_s)=0
      report "exact512 independent spacing or timestamp wrap failed" severity failure;

    -- An unsupported seed whose first sample is512 clocks old is dropped
    -- whole; a subsequent timely trigger must still work.
    restart(2);
    for t in 0 to 1900 loop sample(t,t=700,t=600,152); end loop;
    assert observed_s=1 and unsigned(ring_drop_s)=1
      report "unsupported late seed was not rejected whole" severity failure;

    -- The oldest supported first sample is511 clocks old. The endpoint is
    -- processed on the following edge, conservatively extending one fragment.
    restart(3);
    for t in 0 to 1900 loop sample(t,false,t=600,153); end loop;
    assert observed_s=2 and unsigned(cont_s)=1 and unsigned(ring_drop_s)=0
      report "age511 seed left the chain stuck" severity failure;

    -- Disabling capture and resetting counters during an admitted fragment
    -- must drain that fragment intact, without resetting packet slot ownership.
    restart(4); drain_s<='0';
    for t in 0 to 1800 loop
      if t=400 then enable_s<='0'; end if;
      if t=600 then reset_counts_s<='1'; else reset_counts_s<='0'; end if;
      if t=1300 then drain_s<='1'; end if;
      sample(t,t=300);
    end loop;
    assert observed_s=1 and unsigned(records_s)=1 and unsigned(packets_s)=0
      report "disable/counter reset interrupted admitted fragment" severity failure;
    assert unsigned(full_s)=0 and unsigned(busy_s)=0 severity failure;
    report "stc3_continuation_edges_tb PASS" severity note;
    stop;
    wait;
  end process;
end architecture;
