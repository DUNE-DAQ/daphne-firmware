library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_selftrigger_register_bank_smoke_tb is
end entity legacy_selftrigger_register_bank_smoke_tb;

architecture tb of legacy_selftrigger_register_bank_smoke_tb is
  constant clk_period : time := 10 ns;

  signal clk : std_logic := '0';
  signal axi_in : AXILITE_INREC := (
    ACLK => '0',
    ARESETN => '0',
    AWADDR => (others => '0'),
    AWPROT => (others => '0'),
    AWVALID => '0',
    WDATA => (others => '0'),
    WSTRB => (others => '0'),
    WVALID => '0',
    BREADY => '1',
    ARADDR => (others => '0'),
    ARPROT => (others => '0'),
    ARVALID => '0',
    RREADY => '1'
  );
  signal axi_out : AXILITE_OUTREC;

  signal threshold_xc : slv28_array_t(0 to 39);
  signal record_count : slv64_array_t(0 to 39) := (
    0 => x"0123456789ABCDEF",
    39 => x"1111222233334444",
    others => (others => '0')
  );
  signal full_count : slv64_array_t(0 to 39) := (
    0 => x"AAAABBBBCCCCDDDD",
    39 => x"9999AAAABBBBCCCC",
    others => (others => '0')
  );
  signal busy_count : slv64_array_t(0 to 39) := (
    0 => x"00000000DEADBEEF",
    39 => x"123456789ABCDEF0",
    others => (others => '0')
  );
  signal tcount : slv64_array_t(0 to 39) := (
    0 => x"0102030405060708",
    39 => x"FFEEDDCCBBAA9988",
    others => (others => '0')
  );
  signal pcount : slv64_array_t(0 to 39) := (
    0 => x"8877665544332211",
    39 => x"CAFEBABE12345678",
    others => (others => '0')
  );
begin
  clk <= not clk after clk_period / 2;
  axi_in.ACLK <= clk;

  dut : entity work.legacy_selftrigger_register_bank
    port map (
      AXI_IN => axi_in,
      AXI_OUT => axi_out,
      threshold_xc_o => threshold_xc,
      record_count_i => record_count,
      full_count_i => full_count,
      busy_count_i => busy_count,
      tcount_i => tcount,
      pcount_i => pcount
    );

  stimulus : process
    variable readback : std_logic_vector(31 downto 0);
  begin
    wait for 3 * clk_period;
    axi_in.ARESETN <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;

    assert threshold_xc(0) = x"FFFFFFF"
      report "Channel 0 threshold did not reset to all ones"
      severity failure;
    assert threshold_xc(39) = x"FFFFFFF"
      report "Channel 39 threshold did not reset to all ones"
      severity failure;

    axi_in.AWADDR <= x"00000000";
    axi_in.WDATA <= x"0ABCDEF0";
    axi_in.WSTRB <= "1111";
    axi_in.AWVALID <= '1';
    axi_in.WVALID <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    axi_in.AWVALID <= '0';
    axi_in.WVALID <= '0';
    wait for 1 ns;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert threshold_xc(0) = x"ABCDEF0"
      report "Channel 0 threshold write did not update the exported register"
      severity failure;

    axi_in.AWADDR <= x"000004E0";
    axi_in.WDATA <= x"00FEDCBA";
    axi_in.WSTRB <= "1111";
    axi_in.AWVALID <= '1';
    axi_in.WVALID <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    axi_in.AWVALID <= '0';
    axi_in.WVALID <= '0';
    wait for 1 ns;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert threshold_xc(39) = x"0FEDCBA"
      report "Channel 39 threshold write did not update the exported register"
      severity failure;

    axi_in.AWADDR <= x"00000020";
    axi_in.WDATA <= x"01234567";
    axi_in.WSTRB <= "0011";
    axi_in.AWVALID <= '1';
    axi_in.WVALID <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    axi_in.AWVALID <= '0';
    axi_in.WVALID <= '0';
    wait for 1 ns;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert threshold_xc(1) = x"FFFFFFF"
      report "Partial-strobe write unexpectedly modified channel 1"
      severity failure;

    axi_in.ARADDR <= x"00000000";
    axi_in.ARVALID <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    axi_in.ARVALID <= '0';
    wait for 1 ns;
    readback := axi_out.RDATA;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert readback = x"0ABCDEF0"
      report "Threshold readback mismatch on channel 0"
      severity failure;

    axi_in.ARADDR <= x"00000004";
    axi_in.ARVALID <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    axi_in.ARVALID <= '0';
    wait for 1 ns;
    readback := axi_out.RDATA;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert readback = x"89ABCDEF"
      report "Record-count low readback mismatch on channel 0"
      severity failure;

    axi_in.ARADDR <= x"00000018";
    axi_in.ARVALID <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    axi_in.ARVALID <= '0';
    wait for 1 ns;
    readback := axi_out.RDATA;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert readback = x"AAAABBBB"
      report "Full-count high readback mismatch on channel 0"
      severity failure;

    axi_in.ARADDR <= x"00000500";
    axi_in.ARVALID <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    axi_in.ARVALID <= '0';
    wait for 1 ns;
    readback := axi_out.RDATA;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert readback = x"05060708"
      report "TCount low readback mismatch on channel 0"
      severity failure;

    axi_in.ARADDR <= x"0000077C";
    axi_in.ARVALID <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    axi_in.ARVALID <= '0';
    wait for 1 ns;
    readback := axi_out.RDATA;
    wait until rising_edge(clk);
    wait for 1 ns;
    assert readback = x"CAFEBABE"
      report "PCount high readback mismatch on channel 39"
      severity failure;

    assert false report "legacy_selftrigger_register_bank_smoke_tb completed successfully" severity note;
    wait;
  end process;
end architecture tb;
