library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.ipbus.all;
use work.tx_mux_decl.all;

entity hermes_control_cdc_tb is end entity;
architecture test of hermes_control_cdc_tb is
  signal ipb_clk, tx_clk : std_logic := '0';
  signal ipb_reset, tx_reset : std_logic := '1';
  signal enable, ready, source_run : std_logic := '0';
  signal source_limit : natural := 0;
  signal block_index : natural := 0;
  signal word_index : natural range 0 to 120 := 0;
  signal d : src_d_array(0 downto 0) := (others=>SRC_D_NULL);
  signal q : src_d;
  signal re : std_logic_vector(0 downto 0);
  signal err : std_logic;
  signal ipbw : ipb_wbus := (ipb_addr=>(others=>'0'), ipb_wdata=>(others=>'0'), ipb_strobe=>'0', ipb_write=>'0');
  signal ipbr : ipb_rbus;
  signal check_id : std_logic_vector(19 downto 0) := (others=>'0');
  signal headers, packets : natural := 0;
  constant ID_A : std_logic_vector(19 downto 0) := X"13579";
  constant ID_B : std_logic_vector(19 downto 0) := X"AAAAA";
  constant ID_C : std_logic_vector(19 downto 0) := X"ECA86";
  function payload(block_id, word_id : natural) return std_logic_vector is
  begin
    return X"CAFE1234" & std_logic_vector(to_unsigned(block_id,16)) & std_logic_vector(to_unsigned(word_id,16));
  end function;
begin
  ipb_clk <= not ipb_clk after 5 ns;
  tx_clk <= not tx_clk after 3203 ps;
  dut : entity work.tx_mux_out generic map(N_SRC=>1, IFACE_ID=>2)
    port map(ipb_clk=>ipb_clk, ipb_rst=>ipb_reset, ipb_in=>ipbw, ipb_out=>ipbr,
      clk=>tx_clk, rst=>tx_reset, en=>enable, d=>d, re=>re, q=>q,
      ready=>ready, mark=>'1', err=>err);

  -- Model only the source FIFO contract: length word, followed by 120 data
  -- words. Eight records share each UDP packet in the actual mux state machine.
  d(0).valid <= '1' when source_run='1' and block_index<source_limit else '0';
  d(0).last <= '1' when word_index=120 else '0';
  d(0).d <= X"00000000" & X"01" & std_logic_vector(to_unsigned(block_index,12)) & X"078"
    when word_index=0 else payload(block_index,word_index);
  process(tx_clk)
  begin
    if rising_edge(tx_clk) then
      if tx_reset='1' then block_index<=0; word_index<=0;
      elsif re(0)='1' and d(0).valid='1' then
        if word_index=120 then block_index<=block_index+1; word_index<=0;
        else word_index<=word_index+1; end if;
      end if;
    end if;
  end process;

  process(tx_clk)
    variable remaining : natural := 0;
    variable expected_block : natural := 0;
    variable expected_word : natural := 1;
    variable packet_headers : natural := 0;
    variable stalled : boolean := false;
    variable held : src_d := SRC_D_NULL;
  begin
    if rising_edge(tx_clk) then
      if tx_reset='1' then
        remaining:=0; expected_block:=0; expected_word:=1; packet_headers:=0; stalled:=false;
      else
        assert err='0' report "Unexpected mux overflow" severity failure;
        if stalled then
          assert q=held report "TX data/header changed while backpressured" severity failure;
        end if;
        stalled := ready='0' and (q.valid='1' or q.last='1');
        held:=q;
        if ready='1' and q.valid='1' then
          if remaining=0 then
            assert q.d(25 downto 6)=check_id
              report "Torn/stale configuration or mid-packet ID change: got " & to_hstring(q.d(25 downto 6)) &
                     " expected " & to_hstring(check_id) severity failure;
            assert unsigned(q.d(63 downto 52))=120 and unsigned(q.d(51 downto 40))=expected_block
              report "Incorrect fragment length or sequence" severity failure;
            assert q.d(33 downto 32)="10" report "Changed interface ID" severity failure;
            remaining:=120; expected_word:=1; headers<=headers+1; packet_headers:=packet_headers+1;
          else
            assert q.d=payload(expected_block,expected_word) report "Payload corruption across CDC update" severity failure;
            remaining:=remaining-1; expected_word:=expected_word+1;
            if remaining=0 then expected_block:=expected_block+1; end if;
          end if;
        end if;
        if ready='1' and q.last='1' then
          assert remaining=0 and packet_headers=8 report "Partial packet or unexpected record grouping" severity failure;
          packets<=packets+1; packet_headers:=0;
        end if;
      end if;
    end if;
  end process;

  process
    procedure write_id(value : std_logic_vector(19 downto 0)) is
    begin
      wait until falling_edge(ipb_clk);
      ipbw.ipb_addr<=(others=>'0'); ipbw.ipb_wdata<=X"000" & value;
      ipbw.ipb_write<='1'; ipbw.ipb_strobe<='1';
      wait until rising_edge(ipb_clk); wait for 1 ps;
      assert ipbr.ipb_ack='1' and ipbr.ipb_err='0' report "IPbus write ABI changed" severity failure;
      wait until falling_edge(ipb_clk); ipbw.ipb_strobe<='0'; ipbw.ipb_write<='0';
    end procedure;
  begin
    wait for 80 ns; ipb_reset<='0'; tx_reset<='0'; ready<='1';
    wait for 100 ns; source_run<='1'; source_limit<=8; enable<='1';
    wait until packets=1; enable<='0';
    report "Default configuration and first whole packet passed";

    write_id(ID_A); wait for 700 ns;
    check_id<=ID_A; source_limit<=16; enable<='1';
    wait until headers=9; wait until falling_edge(tx_clk); ready<='0';
    write_id(ID_B); write_id(ID_C);
    wait for 700 ns;
    -- Drop transmit enable while the first fragment is stalled, then let that
    -- fragment drain. Enable clears the legacy length/content bookkeeping,
    -- but the UDP packet is still open: no q.last has been accepted yet.
    enable<='0';
    wait until falling_edge(tx_clk); ready<='1';
    wait until block_index=9;
    wait for 70 ns;
    assert packets=1 report "Disable unexpectedly closed the open UDP packet" severity failure;
    enable<='1';
    wait until packets=2;
    check_id<=ID_C; source_limit<=24;
    wait until packets=3; enable<='0';
    report "Writes and enable toggles during a stalled packet apply only after its accepted end marker";

    -- Reset IPbus after the new request starts but before the round trip can
    -- complete. The TX clock/reset domain is independent; the mailbox must
    -- drain the old request and then deliver the reset default without wedging.
    write_id(ID_B); wait for 12 ns;
    ipb_reset<='1'; tx_reset<='1'; source_run<='0';
    wait for 90 ns; ipb_reset<='0';
    wait for 600 ns; tx_reset<='0';
    check_id<=(others=>'0'); source_limit<=8;
    wait for 100 ns; source_run<='1'; enable<='1';
    wait until packets=4; enable<='0'; source_run<='0';
    wait for 600 ns;
    ipbw.ipb_addr<=X"00000001"; ipbw.ipb_strobe<='1'; wait for 1 ns;
    assert ipbr.ipb_ack='1' and ipbr.ipb_err='0' and not is_x(ipbr.ipb_rdata)
      report "Invalid synchronized IPbus status read" severity failure;
    assert ipbr.ipb_rdata(23 downto 20)=X"0" and ipbr.ipb_rdata(1 downto 0)="10"
      report "Coherent idle FSM status did not settle" severity failure;
    report "hermes_control_cdc_tb PASS: defaults, coherent writes, packet boundaries, enable toggles, stalls, reset in flight, payloads and status";
    stop; wait;
  end process;
  process begin wait for 70 us; assert false report "Control CDC test watchdog" severity failure; end process;
end architecture;
