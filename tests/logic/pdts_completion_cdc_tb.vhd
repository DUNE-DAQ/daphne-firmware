library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity pdts_completion_cdc_tb is end entity;

architecture test of pdts_completion_cdc_tb is
  signal sys_clk, clk : std_logic := '0';
  signal sys_rst, rst : std_logic := '1';
  signal addr_done, deskew_done : std_logic := '0';
  signal clk_lock : std_logic := '0';
  signal stat : std_logic_vector(3 downto 0);
begin
  sys_clk <= not sys_clk after 5 ns;
  clk <= not clk after 8 ns;
  dut : entity work.pdts_ep_sm
    generic map(SCLK_FREQ=>100.0, SKIP_FREQ=>true, SKIP_TSTAMP=>true)
    port map(sys_clk=>sys_clk, sys_rst=>sys_rst, clk=>clk, rst=>rst,
      clk_rst=>open, clk_lock=>clk_lock, cdr_rst=>open, cdr_locked=>'1',
      rx_en=>open, rx_rdy=>'1', addr_done=>addr_done, deskew_done=>deskew_done,
      pkt_err=>'0', resync=>'0', reset=>'0', reg_rst=>open, tsrdy=>'1',
      ready=>open, stat=>stat);
  process
    procedure tick is
    begin
      wait until rising_edge(sys_clk);
      wait for 1 ns;
    end procedure;
    procedure reach(expected : std_logic_vector(3 downto 0)) is
    begin
      for i in 0 to 50 loop
        exit when stat=expected;
        tick;
      end loop;
      assert stat=expected report "PDTS state transition timed out" severity failure;
    end procedure;
  begin
    wait for 120 ns;
    sys_rst<='0'; rst<='0';
    wait for 40 ns;
    clk_lock<='1';
    reach("0101");
    -- Change the source flag just before a destination edge. It must traverse
    -- the source register and both destination stages before the FSM sees it.
    wait until falling_edge(sys_clk);
    wait for 4 ns;
    addr_done<='1';
    tick;
    assert stat="0101" report "Address completion bypassed CDC" severity failure;
    tick;
    assert stat="0101" report "Address completion bypassed second CDC stage" severity failure;
    reach("0110");
    wait until falling_edge(sys_clk);
    wait for 4 ns;
    deskew_done<='1';
    tick;
    assert stat="0110" report "Deskew completion bypassed CDC" severity failure;
    tick;
    assert stat="0110" report "Deskew completion bypassed second CDC stage" severity failure;
    reach("1000");
    report "pdts_completion_cdc_tb PASS" severity note;
    stop; wait;
  end process;
  process
  begin
    wait for 2 us;
    assert false report "PDTS completion CDC timeout" severity failure;
    wait;
  end process;
end architecture;
