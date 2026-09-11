library ieee;
use ieee.std_logic_1164.all;
use std.env.all;
entity axi_lite_unavailable_tb is end;
architecture test of axi_lite_unavailable_tb is
  signal clk : std_logic := '0';
  signal rstn, awvalid, wvalid, bready, arvalid, rready : std_logic := '0';
  signal awready, wready, bvalid, arready, rvalid : std_logic;
  signal bresp, rresp : std_logic_vector(1 downto 0);
  signal rdata : std_logic_vector(31 downto 0);
begin
  clk <= not clk after 5 ns;
  dut : entity work.axi_lite_unavailable port map (
    s_axi_aclk => clk,
    s_axi_aresetn => rstn,
    s_axi_awaddr => (others=>'0'),
    s_axi_awprot => (others=>'0'),
    s_axi_awvalid => awvalid,
    s_axi_awready => awready,
    s_axi_wdata => (others=>'0'),
    s_axi_wstrb => (others=>'1'),
    s_axi_wvalid => wvalid,
    s_axi_wready => wready,
    s_axi_bresp => bresp,
    s_axi_bvalid => bvalid,
    s_axi_bready => bready,
    s_axi_araddr => (others=>'0'),
    s_axi_arprot => (others=>'0'),
    s_axi_arvalid => arvalid,
    s_axi_arready => arready,
    s_axi_rdata => rdata,
    s_axi_rresp => rresp,
    s_axi_rvalid => rvalid,
    s_axi_rready => rready);
  process
    procedure tick is
    begin wait until rising_edge(clk); wait for 1 ns; end;
  begin
    tick; assert awready='0' and wready='0' and arready='0' severity failure;
    rstn<='1'; tick;
    -- Address first; no response until data arrives.
    awvalid<='1'; tick; awvalid<='0';
    assert awready='0' and wready='1' and bvalid='0' severity failure;
    tick; wvalid<='1'; tick; wvalid<='0';
    assert bvalid='1' and bresp="11" severity failure;
    for i in 0 to 3 loop
      tick; assert bvalid='1' and awready='0' and wready='0' severity failure;
    end loop;
    bready<='1'; tick; bready<='0'; assert bvalid='0' severity failure;
    -- Data first, with a simultaneous independent read.
    wvalid<='1'; arvalid<='1'; tick; wvalid<='0'; arvalid<='0';
    assert wready='0' and awready='1' and bvalid='0' severity failure;
    assert rvalid='1' and rresp="11" and rdata=x"00000000" severity failure;
    tick; assert rvalid='1' and arready='0' severity failure;
    awvalid<='1'; tick; awvalid<='0';
    assert bvalid='1' and rvalid='1' severity failure;
    bready<='1'; rready<='1'; tick; bready<='0'; rready<='0';
    assert bvalid='0' and rvalid='0' severity failure;
    -- Simultaneous AW/W, then reset flushes a stalled response.
    awvalid<='1'; wvalid<='1'; tick; awvalid<='0'; wvalid<='0';
    assert bvalid='1' severity failure;
    rstn<='0'; tick; assert bvalid='0' and rvalid='0' severity failure;
    rstn<='1'; tick; awvalid<='1'; tick; awvalid<='0';
    rstn<='0'; tick; rstn<='1'; tick;
    wvalid<='1'; tick; wvalid<='0';
    assert bvalid='0' report "reset retained old AW handshake" severity failure;
    awvalid<='1'; tick; awvalid<='0'; assert bvalid='1' severity failure;
    report "axi_lite_unavailable_tb PASS" severity note;
    stop; wait;
  end process;
end;
