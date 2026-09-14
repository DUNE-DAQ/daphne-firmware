library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.pdts_defs.all;
use work.pdts_ep_defs.all;

-- Actual endpoint core receiving the actual transmitter's encoded idle stream.
-- The physical MMCM/CDR boundary is represented by clock stop/start and LOCKED;
-- no endpoint state machine, packet or CDC implementation is replaced.
entity pdts_core_cdc_tb is end;
architecture test of pdts_core_cdc_tb is
  signal sys_clk, master_clk, clk : std_logic := '0';
  signal sys_rst, master_rst : std_logic := '1';
  signal clk_rst, clk_lock, ready : std_logic;
  signal address_valid : std_logic := '0';
  signal address_value : std_logic_vector(15 downto 0) := x"0000";
  signal stat : std_logic_vector(3 downto 0);
  signal serial_data, char_strobe : std_logic;
  signal char_count : natural range 0 to 9 := 0;
begin
  sys_clk<=not sys_clk after 5.3 ns;
  master_clk<=not master_clk after 8.07 ns;
  -- Stop only on a falling edge, like an orderly clock-generator shutdown.
  process(master_clk)
  begin
    if falling_edge(master_clk) then clk<='0';
    elsif rising_edge(master_clk) then
      if clk_rst='0' then clk<='1'; else clk<='0'; end if;
    end if;
  end process;
  clk_lock<=not clk_rst after 50 ns;
  process(master_clk)
  begin
    if rising_edge(master_clk) then
      if master_rst='1' or char_count=9 then char_count<=0;
      else char_count<=char_count+1; end if;
    end if;
  end process;
  char_strobe<='1' when char_count=9 else '0';
  master : entity work.pdts_tx
    port map(clk=>master_clk, rst=>master_rst, stb=>char_strobe,
      scmd_in=>PDTS_CMD_W_NULL, scmd_out=>open, acmd_in=>PDTS_CMD_W_NULL,
      acmd_out=>open, q=>serial_data, err=>open);
  core : entity work.pdts_ep_core
    generic map(SCLK_FREQ=>100.0, SKIP_FREQ=>true, EXT_ADDR=>true,
                SKIP_DESKEW=>true, SKIP_TSTAMP=>true)
    port map(sys_clk=>sys_clk, sys_rst=>sys_rst, sys_addr=>address_value,
      sys_addr_valid=>address_valid, sys_stat=>stat, ctrl_out=>open,
      ctrl_in=>PDTS_CMI_NULL, clk=>clk, rst=>'0', phase=>open, phase_stb=>open,
      phase_done=>'0', clk_rst=>clk_rst, clk_lock=>clk_lock, cdr_rst=>open,
      locked=>'1', d=>serial_data, q=>open, txenb=>open, ready=>ready,
      tstamp=>open, sync=>open, sync_stb=>open);
  process
    procedure ready_after_address is
    begin
      for n in 0 to 15000 loop
        exit when ready='1';
        wait until rising_edge(sys_clk);
      end loop;
      assert ready='1' report "Actual endpoint core did not reach ready" severity failure;
      assert stat=x"8" report "Ready/state inconsistent after address publication" severity failure;
    end;
  begin
    wait for 150 ns; master_rst<='0'; sys_rst<='0';
    wait for 25 us;
    assert clk_rst='0' and stat=x"4" and ready='0'
      report "Core admitted traffic before initial coherent address, or clock startup stalled" severity failure;
    address_valid<='1'; ready_after_address;
    -- Reset stops the recovered clock, while the remote transmitter keeps going.
    -- The core's original rst port stays low to isolate the retained sys_rst path.
    sys_rst<='1'; address_valid<='0'; address_value<=x"BEEF";
    wait for 150 ns;
    assert clk_rst='1' and clk='0' report "Core reset did not stop clock boundary" severity failure;
    sys_rst<='0'; wait for 25 us;
    assert clk_rst='0' and stat=x"4" and ready='0'
      report "Stopped-clock reset retained stale address validity or deadlocked" severity failure;
    address_valid<='1'; ready_after_address;
    wait for 10 us;
    assert ready='1' report "Core lost ready after CDC recovery" severity failure;
    report "pdts_core_cdc_tb PASS" severity note; stop; wait;
  end process;
  process begin wait for 500 us; assert false report "Core test timeout" severity failure; end process;
end architecture;
