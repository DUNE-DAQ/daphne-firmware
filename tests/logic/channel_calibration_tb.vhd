library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_subsystem_pkg.all;
entity channel_calibration_tb is end;
architecture test of channel_calibration_tb is
  signal clk, bclk : std_logic := '0';
  signal reset : std_logic := '1';
  signal mask, applied : std_logic_vector(7 downto 0) := (others=>'0');
  signal force_trigger, inhibit : std_logic := '0';
  signal ts : unsigned(63 downto 0) := (others=>'0');
  signal samples : sample14_array_t(0 to 7) := (others=>(others=>'0'));
  signal control : trigger_xcorr_control_array_t(0 to 7) := (others=>(
    enable=>'1',afe_comp_enable=>'0',invert_enable=>'0',filter_output_selector=>"00",
    threshold_xc=>(others=>'1'),continuation_config=>x"00000040",adhoc=>x"09",
    ti_trigger=>x"09",ti_trigger_stbr=>'0'));
  signal result : trigger_xcorr_result_array_t(0 to 7);
  signal triggers, records, continuations : slv64_array_t(0 to 7);
  signal ready : std_logic_array_t(0 to 7);
  signal words : slv72_array_t(0 to 7);
  type counts_t is array(0 to 7) of natural;
  signal timing_records : counts_t := (others=>0);
begin
  clk<=not clk after 5 ns; bclk<=not bclk after 2 ns;
  process(clk) begin if rising_edge(clk) then ts<=ts+1; end if; end process;
  dut : entity work.afe_grouped_selftrigger_island port map(
    clock_i=>clk,reset_i=>reset,builder_clock_i=>bclk,builder_reset_i=>reset,
    reset_st_counters_i=>'0',timestamp_i=>std_logic_vector(ts),version_i=>x"4",
    signal_delay_i=>"00000",descriptor_config_i=>(others=>'0'),
    calibration_mask_i=>mask,calibration_applied_o=>applied,
    force_trigger_i=>force_trigger,self_trigger_enable_i=>'1',timing_trigger_enable_i=>'0',
    trigger_inhibit_i=>inhibit,force_calibration_tag_i=>CALIBRATION_TAG_SOFTWARE_C,
    din_i=>samples,trigger_control_i=>control,trigger_result_o=>result,
    descriptor_result_o=>open,record_count_o=>records,full_count_o=>open,busy_count_o=>open,
    trigger_count_o=>triggers,packet_count_o=>open,continuation_count_o=>continuations,
    continuation_drop_count_o=>open,covered_trigger_count_o=>open,descriptor_overflow_count_o=>open,
    delayed_sample_o=>open,ready_o=>ready,rd_en_i=>ready,dout_o=>words);
  process(clk)
    variable index : counts_t := (others=>0);
  begin
    if rising_edge(clk) then
      if reset='1' then index:=(others=>0); timing_records<=(others=>0);
      else
        for ch in 0 to 7 loop
          if ready(ch)='1' then
            if index(ch)=1 and words(ch)(47 downto 46)=CALIBRATION_TAG_TIMING_C then
              timing_records(ch)<=timing_records(ch)+1;
              assert ch=0 or ch=7 report "timing tagged unselected channel" severity failure;
            end if;
            if index(ch)=62 then index(ch):=0; else index(ch):=index(ch)+1; end if;
          end if;
        end loop;
      end if;
    end if;
  end process;
  process
    variable before_restore : unsigned(63 downto 0);
    procedure tick(n:positive:=1) is begin for i in 1 to n loop wait until rising_edge(clk); wait for 1 ns; end loop; end;
    procedure pulse(xcorr,timing:boolean; command:std_logic_vector(7 downto 0):=x"09"; active:boolean:=false) is
    begin
      for ch in 0 to 7 loop
        if xcorr then samples(ch)(0)<='1'; end if;
        control(ch).ti_trigger<=command;
        if timing then control(ch).ti_trigger_stbr<='1'; end if;
      end loop;
      tick;
      if active then samples<=(others=>std_logic_vector(to_unsigned(1000,14)));
      else samples<=(others=>(others=>'0')); end if;
      for ch in 0 to 7 loop control(ch).ti_trigger_stbr<='0'; end loop;
      tick(500);
    end;
    procedure expect(selected,others_count:natural) is
    begin
      for ch in 0 to 7 loop
        if ch=0 or ch=7 then
          assert unsigned(triggers(ch))=selected report "selected channel " & integer'image(ch) severity failure;
        else
          assert unsigned(triggers(ch))=others_count report "unselected channel " & integer'image(ch) severity failure;
        end if;
      end loop;
    end;
  begin
    tick(4); reset<='0'; tick(100);
    pulse(true,false); expect(1,1);
    -- Candidates already in the pipeline must not leak across selection.
    samples<=(others=>std_logic_vector(to_unsigned(1,14))); tick;
    samples<=(others=>(others=>'0')); mask<=x"81"; tick(100);
    assert applied=x"81" severity failure; expect(1,2);
    pulse(true,false); expect(1,3);
    pulse(false,true,x"08"); expect(1,3);
    pulse(false,true); expect(2,3);
    -- Timing and xcorr together must retain xcorr on untouched channels.
    pulse(true,true); expect(3,4);
    -- Force must not enter calibration channels.
    force_trigger<='1'; tick; force_trigger<='0'; tick(500);
    assert unsigned(records(0))=3 and unsigned(records(7))=3 severity failure;
    inhibit<='1'; pulse(true,true); expect(3,4); inhibit<='0';
    control(0).enable<='0'; pulse(false,true);
    assert unsigned(triggers(0))=3 and unsigned(triggers(7))=4 severity failure;
    control(0).enable<='1';
    -- Pending timing must not turn into self triggers when restoring.
    for ch in 0 to 7 loop control(ch).ti_trigger_stbr<='1'; end loop;
    tick;
    for ch in 0 to 7 loop control(ch).ti_trigger_stbr<='0'; end loop;
    mask<=x"00"; tick(100);
    assert applied=x"00" severity failure;
    assert unsigned(triggers(0))=3 and unsigned(triggers(7))=4 severity failure;
    pulse(false,true);
    assert unsigned(triggers(0))=3 and unsigned(triggers(7))=4 severity failure;
    pulse(true,false);
    assert unsigned(triggers(0))=4 and unsigned(triggers(7))=5 severity failure;
    for ch in 1 to 6 loop assert unsigned(triggers(ch))=5 severity failure; end loop;
    tick(500);
    assert timing_records(0)=2 and timing_records(7)=3 report "calibration packet tags" severity failure;
    -- Calibration disables continuation even while an active waveform persists.
    -- Changing the selection must leave another channel's chain running.
    reset<='1'; tick(4); reset<='0';
    for ch in 0 to 7 loop control(ch).continuation_config<=x"80200040"; end loop;
    mask<=x"81"; tick(100);
    samples<=(others=>std_logic_vector(to_unsigned(1000,14)));
    pulse(true,true,active=>true);
    tick(2000);
    assert unsigned(continuations(0))=0 and unsigned(continuations(7))=0 severity failure;
    for ch in 1 to 6 loop assert unsigned(continuations(ch))>0 severity failure; end loop;
    before_restore:=unsigned(continuations(1)); mask<=x"00"; tick(1000);
    assert applied=x"00" and unsigned(continuations(1))>before_restore
      report "restoration interrupted an unselected continuation chain" severity failure;
    report "channel_calibration_tb PASS" severity note; stop; wait;
  end process;
  process begin wait for 100 us; assert false report "calibration test timeout" severity failure; end process;
end;
