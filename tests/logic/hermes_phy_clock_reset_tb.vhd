library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.ipbus.all;
use work.xgmii_pkg.all;
use work.hermes_phy_controls_pkg.all;

entity hermes_phy_clock_reset_tb is end entity;
architecture test of hermes_phy_clock_reset_tb is
  type periods_t is array(0 to 3) of time;
  constant TX_HALF : periods_t := (5 ns, 6 ns, 7 ns, 8 ns);
  constant RX_HALF : periods_t := (7300 ps, 8400 ps, 9500 ps, 10600 ps);
  signal ipb_clk, ref_clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal tx_run : std_logic_vector(3 downto 0) := (others=>'1');
  signal tx_clk, rx_clk, tx_reset, rx_reset, ready, txp, txn, tx_disable : std_logic_vector(3 downto 0);
  signal tx_d, rx_d : xgmii_d_array(3 downto 0) := (others=>(others=>'0'));
  signal tx_c, rx_c : xgmii_c_array(3 downto 0) := (others=>(others=>'0'));
  signal ipbw : ipb_wbus := (ipb_addr=>(others=>'0'), ipb_wdata=>(others=>'0'), ipb_strobe=>'0', ipb_write=>'0');
  signal ipbr : ipb_rbus;
  signal isolation : boolean := false;
  signal affected_lane : natural range 0 to 3 := 0;
begin
  ipb_clk <= not ipb_clk after 4 ns;
  ref_clk <= not ref_clk after 3200 ps;
  clocks: for i in 0 to 3 generate
    process
    begin
      wait for TX_HALF(i);
      if tx_run(i)='1' then tx_clocks_s(i)<=not tx_clocks_s(i);
      else tx_clocks_s(i)<='0'; end if;
    end process;
    rx_clocks_s(i) <= not rx_clocks_s(i) after RX_HALF(i);
    -- Neither reset may release between edges of its destination clock.
    process(tx_reset(i))
    begin
      if falling_edge(tx_reset(i)) then
        assert tx_clocks_s(i)='1' and tx_clocks_s(i)'last_event=0 ns
          report "Asynchronous TX reset release, lane " & integer'image(i) severity failure;
      end if;
    end process;
    process(rx_reset(i))
    begin
      if falling_edge(rx_reset(i)) then
        assert rx_clocks_s(i)='1' and rx_clocks_s(i)'last_event=0 ns
          report "Asynchronous RX reset release, lane " & integer'image(i) severity failure;
      end if;
    end process;
  end generate;

  dut: entity work.ultrascale_pcs_pma
    generic map(N_MGT=>4)
    port map(eth_clk_p=>ref_clk, eth_clk_n=>not ref_clk,
      ipb_clk=>ipb_clk, ipb_rst=>reset, ipb_in=>ipbw, ipb_out=>ipbr, clk_drp=>ipb_clk,
      tx_clk_o=>tx_clk, rx_clk_o=>rx_clk,
      sfp_rxp_array=>"1100", sfp_rxn_array=>"1010",
      sfp_txp_array=>txp, sfp_txn_array=>txn, sfp_tx_dis_array=>tx_disable,
      tx_path_ready_array=>ready, tx_reset_o=>tx_reset, rx_reset_o=>rx_reset,
      tx_xgmii_d_array=>tx_d, tx_xgmii_c_array=>tx_c,
      rx_xgmii_d_array=>rx_d, rx_xgmii_c_array=>rx_c);

  -- Continuous mapping/isolation checks after initial delta-cycle settling.
  process
  begin
    wait for 1 ps;
    assert tx_clk=tx_clocks_s and rx_clk=rx_clocks_s
      report "PHY clock output has wrong lane or TX/RX source" severity failure;
    assert tx_disable="0000" report "Unexpected SFP TX disable" severity failure;
    for i in 0 to 3 loop
      assert unsigned(rx_d(i))=16#CAFE00#+i and unsigned(rx_c(i))=16#A0#+i
        report "RX XGMII source mapping error" severity failure;
      assert txp(i)=tx_d(i)(0) and txn(i)=tx_c(i)(0)
        report "TX XGMII lane mapping error" severity failure;
      if isolation and i/=affected_lane then
        assert ready(i)='1' and tx_reset(i)='0' and rx_reset(i)='0'
          report "Lane-local event disturbed lane " & integer'image(i) severity failure;
      end if;
    end loop;
    wait on tx_clocks_s, rx_clocks_s, tx_clk, rx_clk, ready, tx_reset, rx_reset, txp, txn, tx_d, tx_c, isolation;
  end process;

  process
    procedure settle is begin wait for 1 ps; end procedure;
    procedure healthy is
    begin
      assert ready="1111" and tx_reset="0000" and rx_reset="0000"
        report "Not all lanes recovered" severity failure;
    end procedure;
    procedure tx_edge(signal clock : in std_logic) is
    begin wait until rising_edge(clock); settle; end procedure;
    procedure rx_edge(signal clock : in std_logic) is
    begin wait until rising_edge(clock); settle; end procedure;
  begin
    wait for 80 ns;
    assert ready="0000" and tx_reset="1111" and rx_reset="1111"
      report "Initial global reset failed" severity failure;
    tx_done_s <= "1111"; rx_done_s <= "1111"; link_up_s <= "1111";
    wait for 3333 ps;
    reset <= '0';
    -- Lane 0 requires two reset-release edges followed by two RX-ready edges.
    for edge in 1 to 3 loop
      tx_edge(tx_clocks_s(0));
      assert ready(0)='0' and tx_reset(0)='1'
        report "TX reset/readiness released too early" severity failure;
    end loop;
    tx_edge(tx_clocks_s(0));
    assert ready(0)='1' and tx_reset(0)='0' report "TX release did not complete in four edges" severity failure;
    wait for 100 ns; healthy;
    report "Initial reset release and four distinct TX/RX clock mappings passed";

    -- Distinct changing signatures catch crossed TX XGMII lane connections.
    for active in 0 to 3 loop
      for i in 0 to 3 loop
        tx_d(i)<=(others=>'0'); tx_c(i)<=(others=>'1');
        if i=active then tx_d(i)(0)<='1'; tx_c(i)(0)<='0'; end if;
      end loop;
      wait for 20 ns;
    end loop;

    affected_lane<=2; isolation<=true;
    wait until rising_edge(rx_clocks_s(2)); link_up_s(2)<='0'; settle;
    assert rx_reset(2)='1' and ready(2)='1' report "Link-down domain handling failed" severity failure;
    tx_edge(tx_clocks_s(2));
    assert ready(2)='1' report "RX status crossed into TX in fewer than two edges" severity failure;
    tx_edge(tx_clocks_s(2));
    assert ready(2)='0' and tx_reset(2)='1' report "TX failed to observe link-down" severity failure;
    wait for 50 ns;
    wait until rising_edge(rx_clocks_s(2)); link_up_s(2)<='1'; settle;
    assert rx_reset(2)='0' report "RX link-up not observed" severity failure;
    tx_edge(tx_clocks_s(2));
    assert ready(2)='0' report "TX accepted link-up in fewer than two edges" severity failure;
    tx_edge(tx_clocks_s(2)); healthy;
    isolation<=false;
    report "Lane 2 link loss/recovery and two-stage RX-to-TX readiness passed";

    -- Independent TX and RX reset requests must affect their own lane/domain.
    affected_lane<=1; isolation<=true;
    wait for 2311 ps; tx_done_s(1)<='0'; settle;
    assert ready(1)='0' and tx_reset(1)='1' and rx_reset(1)='0'
      report "Lane-local TX reset assertion failed" severity failure;
    wait for 17333 ps; tx_done_s(1)<='1'; settle;
    for edge in 1 to 3 loop
      tx_edge(tx_clocks_s(1));
      assert tx_reset(1)='1' and ready(1)='0' report "Local TX reset released too early" severity failure;
    end loop;
    tx_edge(tx_clocks_s(1)); healthy;
    wait for 2777 ps; rx_done_s(1)<='0'; settle;
    assert rx_reset(1)='1' report "Lane-local RX reset did not assert asynchronously" severity failure;
    wait for 12333 ps; rx_done_s(1)<='1'; settle;
    rx_edge(rx_clocks_s(1));
    assert rx_reset(1)='1' report "RX reset released before two edges" severity failure;
    rx_edge(rx_clocks_s(1)); healthy;
    isolation<=false;
    report "Lane 1 independent TX/RX resets and lane isolation passed";

    -- A stopped TX clock must hold reset during global reset release.
    tx_run(3)<='0'; wait for 25 ns;
    reset<='1'; settle;
    assert ready="0000" and tx_reset="1111" and rx_reset="1111"
      report "Global reset did not assert with one TX clock stopped" severity failure;
    wait for 40333 ps; reset<='0'; settle;
    wait for 150 ns;
    assert ready="0111" and tx_reset="1000" and rx_reset="0000"
      report "Stopped-clock lane released, or live lanes failed to recover" severity failure;
    tx_run(3)<='1';
    for edge in 1 to 3 loop
      tx_edge(tx_clocks_s(3));
      assert ready(3)='0' and tx_reset(3)='1' report "Resumed lane released too early" severity failure;
    end loop;
    tx_edge(tx_clocks_s(3)); healthy;
    report "hermes_phy_clock_reset_tb PASS: four clocks per direction, lane mapping, link recovery, isolated resets and stopped-clock global reset";
    stop; wait;
  end process;
  process
  begin wait for 4 us; assert false report "PHY clock/reset test watchdog" severity failure; end process;
end architecture;
