library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;
entity continuation_registers_tb is end;
architecture test of continuation_registers_tb is
  signal clk : std_logic := '0';
  signal ai : AXILITE_INREC := (
    ACLK=>'0',ARESETN=>'0',AWADDR=>(others=>'0'),AWPROT=>(others=>'0'),
    AWVALID=>'0',WDATA=>(others=>'0'),WSTRB=>"1111",WVALID=>'0',BREADY=>'1',
    ARADDR=>(others=>'0'),ARPROT=>(others=>'0'),ARVALID=>'0',RREADY=>'1');
  signal ao : AXILITE_OUTREC;
  signal th : slv28_array_t(0 to 39);
  signal cfg : slv32_array_t(0 to 39);
  signal tc : trigger_xcorr_control_array_t(0 to 39);
  signal zeros : slv64_array_t(0 to 39) := (others=>(others=>'0'));
  signal telemetry : slv64_array_t(0 to 39) := (0=>x"12345678ABCDEF01",39=>x"FEDCBA9876543210",others=>(others=>'0'));
begin
  clk <= not clk after 5 ns;
  ai.ACLK <= clk;
  bank : entity work.selftrigger_register_bank port map(
    AXI_IN=>ai,AXI_OUT=>ao,counter_clock_i=>clk,threshold_xc_o=>th,continuation_config_o=>cfg,
    record_count_i=>zeros,full_count_i=>zeros,busy_count_i=>zeros,tcount_i=>zeros,pcount_i=>zeros,
    continuation_count_i=>telemetry,continuation_drop_count_i=>telemetry,
    covered_trigger_count_i=>telemetry,descriptor_overflow_count_i=>telemetry);
  adapter : entity work.trigger_control_adapter port map(
    core_chan_enable_i=>(others=>'1'),afe_comp_enable_i=>(others=>'0'),invert_enable_i=>(others=>'0'),
    threshold_xc_i=>th,continuation_config_i=>cfg,adhoc_i=>(others=>'0'),filter_output_selector_i=>"00",
    ti_trigger_i=>(others=>'0'),ti_trigger_stbr_i=>'0',descriptor_config_i=>(others=>'0'),
    signal_delay_i=>(others=>'0'),reset_st_counters_i=>'0',trigger_control_o=>tc,
    descriptor_config_o=>open,signal_delay_o=>open,reset_st_counters_o=>open);
  process
    procedure tick is begin wait until rising_edge(clk); wait for 1 ns; end;
    procedure wr(addr:natural; data:std_logic_vector(31 downto 0); strobes:std_logic_vector(3 downto 0):="1111") is
    begin
      ai.AWADDR<=std_logic_vector(to_unsigned(addr,32)); ai.WDATA<=data;
      ai.WSTRB<=strobes; ai.AWVALID<='1'; ai.WVALID<='1';
      wait until rising_edge(clk) and ao.AWREADY='1' and ao.WREADY='1';
      wait for 1 ns; ai.AWVALID<='0'; ai.WVALID<='0'; tick; tick;
    end;
    procedure rd(addr:natural; expected:std_logic_vector(31 downto 0)) is
    begin
      ai.ARADDR<=std_logic_vector(to_unsigned(addr,32)); ai.ARVALID<='1';
      wait until rising_edge(clk) and ao.ARREADY='1';
      wait for 1 ns; ai.ARVALID<='0';
      while ao.RVALID /= '1' loop tick; end loop;
      assert ao.RVALID='1' and ao.RDATA=expected report "register readback mismatch at" & integer'image(addr) severity failure;
      tick; tick;
    end;
  begin
    tick; tick; ai.ARESETN<='1'; tick;
    assert cfg(0)=x"80200040" and cfg(39)=x"80200040" severity failure;
    rd(16#1C#,x"80200040"); rd(16#4FC#,x"80200040");
    for c in 0 to 3 loop
      rd(16#800#+8*c,x"ABCDEF01"); rd(16#804#+8*c,x"12345678");
      rd(16#CE0#+8*c,x"76543210"); rd(16#CE4#+8*c,x"FEDCBA98");
    end loop;
    wr(16#1C#,x"01010011");
    assert tc(0).continuation_config=x"01010011" and tc(1).continuation_config=x"80200040" severity failure;
    rd(16#1C#,x"01010011");
    wr(16#4FC#,x"FFFFFFFF"); rd(16#4FC#,x"81FF3FFF");
    wr(16#1C#,x"00000000","0011"); rd(16#1C#,x"01010011");
    wr(0,x"01234567"); rd(0,x"01234567"); rd(16#1C#,x"01010011");
    ai.ARESETN<='0'; tick; ai.ARESETN<='1'; tick;
    rd(16#1C#,x"80200040"); rd(0,x"0FFFFFFF");
    report "continuation_registers_tb PASS" severity note;
    stop; wait;
  end process;
  process begin wait for 30 us; assert false report "AXI test timeout" severity failure; end process;
end;
