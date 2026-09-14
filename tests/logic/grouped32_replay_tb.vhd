library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use std.textio.all;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;
use work.grouped_frame_pkg.all;
entity grouped32_replay_tb is
  generic(OUTPUT_G:string:="packets.csv"; MODE_G:natural:=0; PHASE_PS_G:natural:=0);
end;
architecture test of grouped32_replay_tb is
  function end_cycle return natural is
  begin
    -- 32 slots/channel * 4 channels/lane * 122 clocks/packet = 15616.
    -- Overload cases therefore need more than 8000 quiet drain clocks.
    if MODE_G=2 or MODE_G=3 then return 72000; end if;
    return 62000;
  end;
  constant END_C:natural:=end_cycle;
  signal clk,fast:std_logic:='0';
  signal rst:std_logic:='1';
  signal ts:std_logic_vector(63 downto 0):=(others=>'0');
  signal adc:sample14_array_t(0 to 31):=(others=>(others=>'0'));
  signal triggers:trigger_xcorr_result_array_t(0 to 31):=(others=>TRIGGER_XCORR_RESULT_NULL);
  signal force_s,positive_s:std_logic_array_t(0 to 31):=(others=>'0');
  signal counter_reset:std_logic:='0'; signal enable_s,continuation:std_logic:='1';
  signal delay_s:std_logic_vector(4 downto 0):="00000";
  signal desc:grouped_descriptor_array_t(0 to 31);
  signal dvalid,dbusy,pwr,pcommit:std_logic_array_t(0 to 31);
  signal raddr:ring_address_array_t(0 to 31);
  signal rdata:sample14_array_t(0 to 31);
  type packet_addr_array_t is array(0 to 7) of unsigned(11 downto 0);
  signal waddr:packet_addr_array_t;
  signal wdata:slv72_array_t(0 to 7);
  signal woverflow:std_logic_array_t(0 to 7);
  signal grouped_ready,grouped_rd,reference_ready,reference_rd:std_logic_array_t(0 to 31);
  signal grouped_data,reference_data:slv72_array_t(0 to 31);
  signal grouped_full,grouped_busy,grouped_records,grouped_packets,grouped_drops:slv64_array_t(0 to 31);
  signal reference_full,reference_busy,reference_records,reference_packets,reference_drops:slv64_array_t(0 to 31);
  signal grouped_out,reference_out:array_8x64_type;
  signal grouped_valid,grouped_last,reference_valid,reference_last:std_logic_vector(7 downto 0);
  signal link_ready:std_logic_vector(7 downto 0):=(others=>'1');
  function onset(ch:natural) return natural is
  begin
    if MODE_G=1 then return 256+ch*7; end if;
    return 256;
  end;
  function raw_sample(ch,n:natural) return natural is
    variable baseline,amp:natural;
  begin
    if ch mod 2=0 then baseline:=8000; else baseline:=4000; end if;
    amp:=0;
    if n>=onset(ch) and n<54000 then
      if ch mod 3/=0 or n mod 40<32 then amp:=200+(n*13+ch*17) mod 1500; end if;
    end if;
    if ch mod 2=0 then return baseline-amp; else return baseline+amp; end if;
  end;
begin
  clk<=not clk after 8 ns;
  fast_clock:process begin
    wait for PHASE_PS_G*1 ps;
    loop wait for 1600 ps; fast<=not fast; end loop;
  end process;
  channels:for ch in 0 to 31 generate
  begin
    positive_s(ch)<='1' when ch mod 2=1 else '0';
    source:entity work.stc3_frame_source
      port map(builder_clock_i=>fast,desc_o=>desc(ch),desc_valid_o=>dvalid(ch),desc_busy_i=>dbusy(ch),
      ring_rd_addr_i=>raddr(ch),ring_data_o=>rdata(ch),packet_wr_i=>pwr(ch),packet_commit_i=>pcommit(ch),
      packet_addr_i=>waddr(ch/4),packet_data_i=>wdata(ch/4),packet_overflow_i=>woverflow(ch/4),
      ch_id_i=>std_logic_vector(to_unsigned(ch,8)),
      version_i=>x"3",
      threshold_xc_i=>x"0012345",
      signal_delay_i=>delay_s,
      clock_i=>clk,
      reset_i=>rst,
      reset_st_counters_i=>counter_reset,
      enable_i=>enable_s,
      force_trigger_i=>force_s(ch),
      force_calibration_tag_i=>std_logic_vector(to_unsigned(ch mod 4,2)),
      timestamp_i=>ts,
      din_i=>adc(ch),
      trigger_i=>triggers(ch),
      continuation_enable_i=>continuation,
      positive_pulse_i=>positive_s(ch),
      activity_threshold_i=>std_logic_vector(to_unsigned(64,14)),
      quiet_samples_i=>std_logic_vector(to_unsigned(32,9)),
      continuation_count_o=>open,
      continuation_drop_count_o=>grouped_drops(ch),
      covered_trigger_count_o=>open,
      descriptor_overflow_count_o=>open,
      trailer_capture_i=>'0',
      trailer_i=>PEAK_DESCRIPTOR_TRAILER_NULL,
      frame_match_o=>open,
      record_count_o=>grouped_records(ch),
      full_count_o=>grouped_full(ch),
      busy_count_o=>grouped_busy(ch),
      spacing_reject_count_o=>open,
      queue_reject_count_o=>open,
      ring_reject_count_o=>open,
      output_reject_count_o=>open,
      trigger_count_o=>open,
      packet_count_o=>grouped_packets(ch),
      delayed_sample_o=>open,
      ready_o=>grouped_ready(ch),
      rd_en_i=>grouped_rd(ch),
      dout_o=>grouped_data(ch));
    reference:entity work.stc3_record_builder
      port map(ch_id_i=>std_logic_vector(to_unsigned(ch,8)),
      version_i=>x"3",
      threshold_xc_i=>x"0012345",
      signal_delay_i=>delay_s,
      clock_i=>clk,
      reset_i=>rst,
      reset_st_counters_i=>counter_reset,
      enable_i=>enable_s,
      force_trigger_i=>force_s(ch),
      force_calibration_tag_i=>std_logic_vector(to_unsigned(ch mod 4,2)),
      timestamp_i=>ts,
      din_i=>adc(ch),
      trigger_i=>triggers(ch),
      continuation_enable_i=>continuation,
      positive_pulse_i=>positive_s(ch),
      activity_threshold_i=>std_logic_vector(to_unsigned(64,14)),
      quiet_samples_i=>std_logic_vector(to_unsigned(32,9)),
      continuation_count_o=>open,
      continuation_drop_count_o=>reference_drops(ch),
      covered_trigger_count_o=>open,
      descriptor_overflow_count_o=>open,
      trailer_capture_i=>'0',
      trailer_i=>PEAK_DESCRIPTOR_TRAILER_NULL,
      frame_match_o=>open,
      record_count_o=>reference_records(ch),
      full_count_o=>reference_full(ch),
      busy_count_o=>reference_busy(ch),
      spacing_reject_count_o=>open,
      queue_reject_count_o=>open,
      ring_reject_count_o=>open,
      output_reject_count_o=>open,
      trigger_count_o=>open,
      packet_count_o=>reference_packets(ch),
      delayed_sample_o=>open,
      ready_o=>reference_ready(ch),
      rd_en_i=>reference_rd(ch),
      dout_o=>reference_data(ch));
  end generate;
  builders:for g in 0 to 7 generate
    constant B:natural:=g*4;
  begin
    engine:entity work.afe_stc3_stream_serializer
      port map(clock_i=>clk,reset_i=>rst,builder_clock_i=>fast,builder_reset_i=>rst,
        desc_i=>desc(B to B+3),desc_valid_i=>dvalid(B to B+3),desc_busy_o=>dbusy(B to B+3),
        ring_rd_addr_o=>raddr(B to B+3),ring_data_i=>rdata(B to B+3),
        packet_wr_o=>pwr(B to B+3),packet_commit_o=>pcommit(B to B+3),packet_addr_o=>waddr(g),
        packet_data_o=>wdata(g),packet_overflow_o=>woverflow(g));
  end generate;
  grouped_mux:entity work.two_lane_readout_mux
    generic map(CHANNEL_COUNT_G=>32,LANE_COUNT_G=>8,CHANNELS_PER_LANE_G=>4)
    port map(clock_i=>clk,reset_i=>rst,ready_i=>grouped_ready,dout_i=>grouped_data,
      rd_en_o=>grouped_rd,dout_o=>grouped_out,valid_o=>grouped_valid,last_o=>grouped_last,packet_ready_i=>link_ready);
  reference_mux:entity work.two_lane_readout_mux
    generic map(CHANNEL_COUNT_G=>32,LANE_COUNT_G=>8,CHANNELS_PER_LANE_G=>4)
    port map(clock_i=>clk,reset_i=>rst,ready_i=>reference_ready,dout_i=>reference_data,
      rd_en_o=>reference_rd,dout_o=>reference_out,valid_o=>reference_valid,last_o=>reference_last,packet_ready_i=>link_ready);
  stimulus:process
    variable total_loss:natural:=0;
  begin
    for i in 0 to 15 loop wait until falling_edge(clk); end loop;
    rst<='0';
    if MODE_G=3 then continuation<='0'; delay_s<="11111"; end if;
    for n in 0 to END_C loop
      ts<=std_logic_vector(to_unsigned(n,64)); counter_reset<='0'; force_s<=(others=>'0');
      if MODE_G=2 and n>=2000 and n<36000 then link_ready<=(others=>'0');
      elsif MODE_G=1 and n mod 4096<20 then link_ready<=(others=>'0');
      else link_ready<=(others=>'1'); end if;
      if MODE_G=4 then
        if n=6000 then rst<='1'; elsif n=6032 then rst<='0'; end if;
        if n=12000 then counter_reset<='1'; end if;
        if n=16000 then enable_s<='0'; elsif n=17000 then enable_s<='1'; end if;
      end if;
      for ch in 0 to 31 loop
        adc(ch)<=std_logic_vector(to_unsigned(raw_sample(ch,n),14));
        triggers(ch).enabled<='1'; triggers(ch).trigger_pulse<='0';
        if ch mod 2=0 then triggers(ch).baseline<=std_logic_vector(to_unsigned(8000,14));
        else triggers(ch).baseline<=std_logic_vector(to_unsigned(16384-4000,14)); end if;
        triggers(ch).calibration_tag<=std_logic_vector(to_unsigned(ch mod 4,2));
        if n=onset(ch)+64 or (MODE_G=4 and (n=6400 or n=17200)) then
          triggers(ch).trigger_pulse<='1';
          triggers(ch).trigger_timestamp<=std_logic_vector(to_unsigned(n-64,64));
          triggers(ch).trigger_sample<=std_logic_vector(to_unsigned(raw_sample(ch,n-64),14));
        end if;
        if MODE_G=3 and n>=512 and n<54000 and (n+ch*3) mod 64=0 then force_s(ch)<='1'; end if;
      end loop;
      wait until falling_edge(clk);
    end loop;
    for ch in 0 to 31 loop
      if MODE_G<=1 then
        assert unsigned(grouped_full(ch))=0 and unsigned(grouped_busy(ch))=0 and unsigned(grouped_drops(ch))=0
          report "grouped builder lost data under sustainable four-channel activity" severity failure;
        assert unsigned(grouped_records(ch))=unsigned(grouped_packets(ch))
          report "admitted grouped records did not all finish" severity failure;
      end if;
      total_loss:=total_loss+to_integer(unsigned(grouped_full(ch)))+to_integer(unsigned(grouped_busy(ch)));
      assert grouped_ready(ch)='0' and reference_ready(ch)='0' report "undrained packet store" severity failure;
    end loop;
    if MODE_G=2 or MODE_G=3 then assert total_loss>0 report "overload case did not exercise loss" severity failure; end if;
    report "grouped32_replay_tb PASS mode="&integer'image(MODE_G)&" loss="&integer'image(total_loss) severity note;
    stop; wait;
  end process;
  capture:process(clk)
    file output_file:text open write_mode is OUTPUT_G;
    type indices_t is array(0 to 15) of natural range 0 to 119;
    type packets_t is array(0 to 15) of std_logic_vector(7679 downto 0);
    variable idx:indices_t:=(others=>0);
    variable packets:packets_t:=(others=>(others=>'0'));
    variable row:line;
    variable word:std_logic_vector(63 downto 0);
    variable valid,last:std_logic;
    variable channel:natural;
  begin
    if rising_edge(clk) then
      if rst='1' then idx:=(others=>0);
      else
        for lane in 0 to 15 loop
          if lane<8 then word:=grouped_out(lane); valid:=grouped_valid(lane); last:=grouped_last(lane);
          else word:=reference_out(lane-8); valid:=reference_valid(lane-8); last:=reference_last(lane-8); end if;
          if valid='1' then
            packets(lane)(64*idx(lane)+63 downto 64*idx(lane)):=word;
            if idx(lane)=119 then
              assert last='1' report "long packet" severity failure;
              channel:=to_integer(unsigned(packets(lane)(127 downto 120)));
              assert channel/4=lane mod 8 report "channel routed to wrong lane" severity failure;
              write(row,integer'image(lane/8)&","&integer'image(channel)&","&
                integer'image(to_integer(unsigned(ts)))&","&to_hstring(packets(lane)));
              writeline(output_file,row); idx(lane):=0;
            else assert last='0' report "short packet" severity failure; idx(lane):=idx(lane)+1; end if;
          else assert idx(lane)=0 report "gap inside a committed packet" severity failure;
          end if;
        end loop;
      end if;
    end if;
  end process;
end architecture;
