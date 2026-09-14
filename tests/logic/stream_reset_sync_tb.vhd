library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
entity stream_reset_sync_tb is generic(STAGES_G:positive:=4); end;
architecture test of stream_reset_sync_tb is
  signal clk:std_logic:='0'; signal reset:std_logic:='1'; signal output_reset:std_logic;
  signal running:boolean:=true;
begin
  process begin
    wait for 5 ns;
    if running then clk<=not clk; else clk<='0'; end if;
  end process;
  dut:entity work.stream_reset_sync generic map(STAGES_G=>STAGES_G)
    port map(clock_i=>clk,reset_i=>reset,reset_o=>output_reset);
  process
    procedure check_release is
    begin
      for edge in 1 to STAGES_G loop
        wait until rising_edge(clk); wait for 1 ns;
        if edge<STAGES_G then assert output_reset='1' report "reset released early" severity failure;
        else assert output_reset='0' report "reset did not release" severity failure; end if;
      end loop;
    end;
  begin
    wait for 22 ns; reset<='0'; check_release;
    wait until falling_edge(clk); running<=false;
    wait for 3 ns; reset<='1'; wait for 1 ns;
    assert output_reset='1' report "reset did not assert with stopped clock" severity failure;
    reset<='0'; wait for 50 ns;
    assert output_reset='1' report "reset released without destination clocks" severity failure;
    running<=true; check_release;
    report "stream_reset_sync_tb PASS" severity note; stop; wait;
  end process;
end architecture;
