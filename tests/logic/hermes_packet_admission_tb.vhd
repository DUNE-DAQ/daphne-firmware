library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.ipbus.all;
use work.tx_mux_decl.all;

entity hermes_packet_admission_tb is end entity;
architecture test of hermes_packet_admission_tb is
  signal src_clk, eth_clk: std_logic := '0';
  signal rst: std_logic := '1';
  signal d, q: src_d := SRC_D_NULL;
  signal ready, re, err: std_logic := '0';
  signal drain: boolean := false;
  signal ipbw: ipb_wbus := (ipb_addr => (others=>'0'), ipb_wdata => (others=>'0'), ipb_strobe=>'0', ipb_write=>'0');
  signal ipbr: ipb_rbus;
  signal received: natural := 0;
  function word(packet, index: natural) return std_logic_vector is
  begin return std_logic_vector(to_unsigned(packet*256+index,64)); end;
begin
  src_clk <= not src_clk after 8 ns;
  eth_clk <= not eth_clk after 3.2 ns;
  dut: entity work.tx_mux_ibuf
    generic map(IN_BUF_DEPTH=>512, PACKET_WORDS=>120)
    port map(packet_ready=>ready, ipb_clk=>src_clk, ipb_rst=>rst, ipb_in=>ipbw, ipb_out=>ipbr,
      src_clk=>src_clk, src_rst=>rst, ts=>(others=>'0'), d=>d, samp=>'0',
      eth_clk=>eth_clk, eth_rst=>rst, re=>re, q=>q, err=>err);
  process(eth_clk)
    variable cycle, packet, index: natural := 0;
  begin
    if rising_edge(eth_clk) then
      cycle:=cycle+1;
      re<='0';
      if drain and cycle mod 5 /= 0 then re<='1'; end if;
      if rst='0' then
        assert err='0' report "Hermes output FIFO entered error state" severity failure;
        if re='1' and q.valid='1' then
          if index=0 then
            assert unsigned(q.d(11 downto 0))=120 report "Wrong complete-packet length" severity failure;
            assert unsigned(q.d(23 downto 12))=packet report "Wrong fixed-packet sequence" severity failure;
            assert q.last='0' severity failure;
            index:=1;
          else
            assert q.d=word(packet,index-1) report "Corrupted, missing or reordered payload" severity failure;
            if index=120 then
              assert q.last='1' report "Missing last on final payload" severity failure;
              index:=0; packet:=packet+1; received<=packet;
            else
              assert q.last='0' report "Premature last" severity failure;
              index:=index+1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
  process
    procedure send_packet(packet: natural) is
    begin
      loop wait until rising_edge(src_clk); exit when ready='1'; end loop;
      -- Match scheduler/output register latency after whole-packet admission.
      wait until rising_edge(src_clk);
      for index in 0 to 119 loop
        d.d<=word(packet,index); d.valid<='1'; d.last<='0';
        if index=119 then d.last<='1'; end if;
        wait until rising_edge(src_clk);
      end loop;
      d<=SRC_D_NULL;
      wait until rising_edge(src_clk);
    end procedure;
  begin
    wait for 160 ns; wait until rising_edge(src_clk); rst<='0';
    for packet in 0 to 3 loop send_packet(packet); end loop;
    for cycle in 0 to 20 loop wait until rising_edge(src_clk); end loop;
    assert ready='0' report "Fifth packet admitted without 120 free words" severity failure;
    assert received=0 severity failure;
    drain<=true;
    for packet in 4 to 15 loop send_packet(packet); end loop;
    wait until received=16;
    for cycle in 0 to 30 loop wait until rising_edge(src_clk); end loop;
    assert ready='1' report "Admission failed to recover after congestion" severity failure;
    report "hermes_packet_admission_tb PASS: first packet retained, full-packet reservation, stalled drain and recovery" severity note;
    stop; wait;
  end process;
  process begin wait for 200 us; assert false report "Admission test watchdog" severity failure; end process;
end architecture;
