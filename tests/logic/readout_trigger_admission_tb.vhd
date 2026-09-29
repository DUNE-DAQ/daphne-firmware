library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_subsystem_pkg.all;

entity readout_trigger_admission_tb is end;
architecture test of readout_trigger_admission_tb is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ts : unsigned(63 downto 0) := (others=>'0');
  signal source : std_logic_vector(2 downto 0) := "011";
  signal inhibit, sw, hw : std_logic := '0';
  signal admission, self_enable, timing_enable, forced, ready, rd : std_logic;
  signal tag, expected_tag : std_logic_vector(1 downto 0) := "00";
  signal trigger : trigger_xcorr_result_t := TRIGGER_XCORR_RESULT_NULL;
  signal continuation_enabled : std_logic := '0';
  signal adc : std_logic_vector(13 downto 0) := std_logic_vector(to_unsigned(8000,14));
  signal records, self_count : std_logic_vector(63 downto 0);
  signal data : std_logic_vector(71 downto 0);
  signal observed : natural := 0;
begin
  clk <= not clk after 8 ns;
  process(clk) begin
    if rising_edge(clk) then
      if rst='1' then ts <= (others=>'0'); else ts <= ts+1; end if;
    end if;
  end process;
  policy : entity work.readout_trigger_policy port map (
    clock_i=>clk,source_i=>source,inhibit_i=>inhibit,software_trigger_i=>sw,hardware_trigger_i=>hw,
    admission_enable_o=>admission,self_trigger_enable_o=>self_enable,timing_trigger_enable_o=>timing_enable,force_trigger_o=>forced,calibration_tag_o=>tag);
  builder : entity work.stc3_grouped_test_adapter port map (
    ch_id_i=>x"00",version_i=>x"4",threshold_xc_i=>x"0000000",signal_delay_i=>"00000",
    clock_i=>clk,reset_i=>rst,reset_st_counters_i=>'0',enable_i=>admission,
    self_trigger_enable_i=>self_enable,timing_trigger_enable_i=>timing_enable,force_trigger_i=>forced,force_calibration_tag_i=>tag,
    timestamp_i=>std_logic_vector(ts),din_i=>adc,trigger_i=>trigger,
    continuation_enable_i=>continuation_enabled,positive_pulse_i=>'0',trailer_capture_i=>'0',trailer_i=>PEAK_DESCRIPTOR_TRAILER_NULL,
    frame_match_o=>open,record_count_o=>records,trigger_count_o=>self_count,
    full_count_o=>open,busy_count_o=>open,spacing_reject_count_o=>open,queue_reject_count_o=>open,
    ring_reject_count_o=>open,output_reject_count_o=>open,packet_count_o=>open,delayed_sample_o=>open,
    continuation_count_o=>open,continuation_drop_count_o=>open,covered_trigger_count_o=>open,
    descriptor_overflow_count_o=>open,ready_o=>ready,rd_en_i=>rd,dout_o=>data);
  rd <= ready;
  process(clk)
    variable word_index : natural := 0;
  begin
    if rising_edge(clk) and rst='0' and ready='1' then
      if word_index=1 then
        assert data(47 downto 46)=expected_tag report "wrong source tag" severity failure;
        assert unsigned(data(45 downto 32))=8000 report "baseline metadata lost while gating xcorr" severity failure;
      end if;
      if word_index=62 then word_index:=0; observed<=observed+1;
      else word_index:=word_index+1; end if;
    end if;
  end process;
  process
    variable before_count, expected, total, total_self : natural := 0;
    variable sw_bit, hw_bit, xc_bit, timing_bit : boolean;
    procedure ticks(count : natural) is
    begin for i in 1 to count loop wait until falling_edge(clk); end loop; end;
  begin
    ticks(3); rst<='0';
    trigger.enabled<='1'; trigger.baseline<=std_logic_vector(to_unsigned(8000,14));
    trigger.calibration_tag<=CALIBRATION_TAG_NORMAL_C;
    ticks(600);
    for mode in 0 to 7 loop
      source<=std_logic_vector(to_unsigned(mode,3)); ticks(4);
      for mask in 0 to 15 loop
        sw_bit := mask mod 2 = 1; hw_bit := (mask/2) mod 2 = 1; xc_bit := (mask/4) mod 2 = 1; timing_bit := mask>=8;
        expected:=0; expected_tag<=CALIBRATION_TAG_NORMAL_C;
        if xc_bit and (mode=2 or mode=3) then expected:=1; end if;
        trigger.calibration_tag<=CALIBRATION_TAG_NORMAL_C;
        -- The timing strobe is gated before the real xcorr/timing OR. Model
        -- that upstream rejection, including simultaneous xcorr/timing input.
        if timing_bit and (mode=3 or mode=4) then
          expected:=1; trigger.calibration_tag<=CALIBRATION_TAG_TIMING_C; expected_tag<=CALIBRATION_TAG_TIMING_C;
        end if;
        if (xc_bit and (mode=2 or mode=3)) or (timing_bit and (mode=3 or mode=4)) then total_self:=total_self+1; end if;
        if hw_bit and (mode=1 or mode=3) then expected:=1; expected_tag<=CALIBRATION_TAG_BNC_C; end if;
        if sw_bit and (mode=0 or mode=3) then expected:=1; expected_tag<=CALIBRATION_TAG_SOFTWARE_C; end if;
        before_count:=to_integer(unsigned(records));
        if sw_bit then sw<='1'; end if;
        if hw_bit then hw<='1'; end if;
        if xc_bit or (timing_bit and (mode=3 or mode=4)) then trigger.trigger_pulse<='1'; end if;
        trigger.trigger_timestamp<=std_logic_vector(ts-64);
        trigger.trigger_sample<=std_logic_vector(to_unsigned(8000,14));
        ticks(1); sw<='0'; hw<='0'; trigger.trigger_pulse<='0'; ticks(1200);
        assert to_integer(unsigned(records))=before_count+expected report "wrong admission for mode/mask " & integer'image(mode) & "/" & integer'image(mask) severity failure;
        total:=total+expected;
        assert observed=total report "admitted frame did not drain" severity failure;
      end loop;
      inhibit<='1'; sw<='1'; hw<='1'; trigger.trigger_pulse<='1'; ticks(2);
      sw<='0'; hw<='0'; trigger.trigger_pulse<='0'; ticks(1200);
      assert to_integer(unsigned(records))=total report "inhibit admitted an event" severity failure;
      inhibit<='0'; ticks(3);
    end loop;
    assert to_integer(unsigned(self_count))=total_self report "suppressed self events counted" severity failure;
    -- An active software chain must stop on a source change, without losing
    -- queued packets. The next hardware event must own fresh BNC metadata.
    source<="000"; ticks(4); continuation_enabled<='1'; adc<=std_logic_vector(to_unsigned(1000,14));
    expected_tag<=CALIBRATION_TAG_SOFTWARE_C; sw<='1'; ticks(1); sw<='0'; ticks(800);
    assert to_integer(unsigned(records))>total+1 report "software continuation did not start" severity failure;
    source<="001"; ticks(1200); before_count:=to_integer(unsigned(records)); ticks(1200);
    assert to_integer(unsigned(records))=before_count and observed=before_count
      report "old chain continued or queued frames failed to drain after source change: records=" & integer'image(to_integer(unsigned(records))) & " expected=" & integer'image(before_count) & " observed=" & integer'image(observed) severity failure;
    expected_tag<=CALIBRATION_TAG_BNC_C; hw<='1'; ticks(1); hw<='0'; ticks(800);
    assert to_integer(unsigned(records))>before_count+1 report "new hardware chain was coalesced into old metadata" severity failure;
    inhibit<='1'; ticks(1200); before_count:=to_integer(unsigned(records)); ticks(1200);
    assert to_integer(unsigned(records))=before_count and observed=before_count
      report "inhibit failed to stop continuation or drain queued frames" severity failure;
    report "readout_trigger_admission_tb PASS: all modes/input combinations, inhibit, timing, invalid modes, tags and baseline" severity note;
    stop; wait;
  end process;
end architecture;
