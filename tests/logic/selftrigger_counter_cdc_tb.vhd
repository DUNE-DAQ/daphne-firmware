library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity selftrigger_counter_cdc_tb is
  generic (CHANNEL_COUNT_G : positive := 32);
end entity;

architecture tb of selftrigger_counter_cdc_tb is
  constant TIMEOUT_C : positive := 96;
  constant LAST_CHANNEL_C : natural := CHANNEL_COUNT_G - 1;
  signal axi_clk, counter_clk : std_logic := '0';
  signal counter_run : boolean := true;
  signal epoch : natural := 1;
  signal carry_enable : boolean := false;
  signal axi_in : AXILITE_INREC := (
    ACLK=>'0', ARESETN=>'0', AWADDR=>(others=>'0'), AWPROT=>(others=>'0'),
    AWVALID=>'0', WDATA=>(others=>'0'), WSTRB=>(others=>'0'), WVALID=>'0',
    BREADY=>'1', ARADDR=>(others=>'0'), ARPROT=>(others=>'0'), ARVALID=>'0', RREADY=>'0');
  signal axi_out : AXILITE_OUTREC;
  signal threshold : slv28_array_t(0 to LAST_CHANNEL_C);
  signal continuation_config : slv32_array_t(0 to LAST_CHANNEL_C);
  type counters_t is array (0 to 8) of slv64_array_t(0 to LAST_CHANNEL_C);
  signal counters : counters_t := (others=>(others=>(others=>'0')));

  function value_for(kind, channel, generation : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(16#12000000# + kind * 65536 + channel * 256 + generation, 32)) &
           std_logic_vector(to_unsigned(16#34000000# + kind * 65536 + channel * 256 + generation, 32));
  end function;

  function address_for(kind, channel : natural; high_word : boolean := false) return natural is
    variable address : natural;
  begin
    case kind is
      when 0 => address := channel * 32 + 4;
      when 1 => address := channel * 32 + 12;
      when 2 => address := channel * 32 + 20;
      when 3 => address := 16#500# + channel * 16;
      when 4 => address := 16#508# + channel * 16;
      when others => address := 16#800# + channel * 32 + (kind - 5) * 8;
    end case;
    if high_word then address := address + 4; end if;
    return address;
  end function;
begin
  axi_clk <= not axi_clk after 5 ns;
  axi_in.ACLK <= axi_clk;
  counter_clock : process
  begin
    wait for 1300 ps;
    loop
      wait for 3700 ps;
      if counter_run then counter_clk <= not counter_clk;
      else counter_clk <= '0'; end if;
    end loop;
  end process;

  -- Every input is registered on the acquisition clock, as in the real producer.
  produce : process(counter_clk)
    variable carry_active : boolean := false;
    variable carry_value : unsigned(63 downto 0) := x"12345678FFFFFFE0";
  begin
    if rising_edge(counter_clk) then
      for kind in 0 to 8 loop
        for channel in 0 to LAST_CHANNEL_C loop
          counters(kind)(channel) <= value_for(kind, channel, epoch);
        end loop;
      end loop;
      if carry_enable then
        if not carry_active then carry_value := x"12345678FFFFFFE0";
        else carry_value := carry_value + 1; end if;
        counters(0)(0) <= std_logic_vector(carry_value);
      end if;
      carry_active := carry_enable;
    end if;
  end process;

  dut : entity work.selftrigger_register_bank
    generic map(CHANNEL_COUNT_G=>CHANNEL_COUNT_G, COUNTER_READ_TIMEOUT_G=>TIMEOUT_C)
    port map(AXI_IN=>axi_in, AXI_OUT=>axi_out, counter_clock_i=>counter_clk,
      threshold_xc_o=>threshold, continuation_config_o=>continuation_config,
      record_count_i=>counters(0), busy_count_i=>counters(1), full_count_i=>counters(2),
      tcount_i=>counters(3), pcount_i=>counters(4), continuation_count_i=>counters(5),
      continuation_drop_count_i=>counters(6), covered_trigger_count_i=>counters(7),
      descriptor_overflow_count_i=>counters(8));

  -- Count real handshakes, including addresses offered while the response stalls.
  protocol : process(axi_in.ACLK)
    variable pending : natural := 0;
    variable stalled : boolean := false;
    variable held_data : std_logic_vector(31 downto 0);
    variable held_resp : std_logic_vector(1 downto 0);
  begin
    if rising_edge(axi_in.ACLK) then
      if axi_in.ARESETN='0' then pending := 0; stalled := false;
      else
        if stalled then
          assert axi_out.RVALID='1' and axi_out.RDATA=held_data and axi_out.RRESP=held_resp
            report "AXI response changed under backpressure" severity failure;
        end if;
        if axi_in.ARVALID='1' and axi_out.ARREADY='1' then pending := pending + 1; end if;
        if axi_out.RVALID='1' and axi_in.RREADY='1' then
          assert pending>0 report "Response without an accepted address" severity failure;
          pending := pending - 1;
        end if;
        assert pending<=1 report "AR handshake accepted more than one outstanding read" severity failure;
        stalled := axi_out.RVALID='1' and axi_in.RREADY='0';
        held_data := axi_out.RDATA; held_resp := axi_out.RRESP;
      end if;
    end if;
  end process;

  stimulus : process
    variable data, low_word, high_word : std_logic_vector(31 downto 0);
    variable expected : std_logic_vector(63 downto 0);
    variable channel : natural;
    procedure ticks(count : natural) is
    begin
      for i in 1 to count loop wait until rising_edge(axi_in.ACLK); end loop;
      wait for 1 ns;
    end procedure;
    procedure issue(address : natural) is
      variable accepted : boolean := false;
    begin
      wait until falling_edge(axi_in.ACLK);
      axi_in.ARADDR <= std_logic_vector(to_unsigned(address,32)); axi_in.ARVALID <= '1';
      for i in 0 to TIMEOUT_C*3 loop
        wait until rising_edge(axi_in.ACLK);
        if axi_out.ARREADY='1' then accepted := true; exit; end if;
      end loop;
      assert accepted report "AR handshake was lost" severity failure;
      axi_in.ARVALID <= '0'; wait for 1 ns;
    end procedure;
    procedure response(variable result : out std_logic_vector(31 downto 0);
                       expected_resp : std_logic_vector(1 downto 0) := "00";
                       stall_cycles : natural := 0) is
      variable received : boolean := false;
    begin
      for i in 0 to TIMEOUT_C*3 loop
        if axi_out.RVALID='1' then received := true; exit; end if;
        wait until rising_edge(axi_in.ACLK); wait for 1 ns;
      end loop;
      assert received report "Read exceeded bounded completion time" severity failure;
      assert axi_out.RRESP=expected_resp report "Unexpected RRESP: " & to_hstring(axi_out.RRESP)
        severity failure;
      result := axi_out.RDATA;
      ticks(stall_cycles);
      axi_in.RREADY <= '1'; wait until rising_edge(axi_in.ACLK);
      axi_in.RREADY <= '0'; wait for 1 ns;
    end procedure;
    procedure read_word(address : natural; expected_word : std_logic_vector(31 downto 0);
                        expected_resp : std_logic_vector(1 downto 0) := "00";
                        stall_cycles : natural := 0) is
      variable result : std_logic_vector(31 downto 0);
    begin
      issue(address); response(result,expected_resp,stall_cycles);
      assert result=expected_word report "Read mismatch at " & integer'image(address) &
        ": got " & to_hstring(result) & " expected " & to_hstring(expected_word) severity failure;
    end procedure;
    procedure reset_axi is
    begin
      wait until falling_edge(axi_in.ACLK); axi_in.ARESETN<='0';
      axi_in.ARVALID<='0'; axi_in.RREADY<='0'; ticks(4);
      axi_in.ARESETN<='1'; ticks(2);
      assert axi_out.RVALID='0' report "Old response survived AXI reset" severity failure;
    end procedure;
  begin
    ticks(5); axi_in.ARESETN <= '1'; ticks(3);
    read_word(0,x"0FFFFFFF");
    read_word(LAST_CHANNEL_C*32+28,CONTINUATION_CONFIG_DEFAULT_C);

    -- Unique values detect crossed selectors, address aliases and stale epochs.
    for edge_channel in 0 to 1 loop
      if edge_channel=0 then channel:=0; else channel:=LAST_CHANNEL_C; end if;
      for kind in 0 to 8 loop
        expected:=value_for(kind,channel,1);
        read_word(address_for(kind,channel),expected(31 downto 0),"00",kind mod 3);
        read_word(address_for(kind,channel,true),expected(63 downto 32));
      end loop;
    end loop;
    report "all nine counter types and edge channels passed" severity note;

    -- Counter reads are separate snapshots, with no shared cross-counter epoch.
    expected:=value_for(0,0,1); read_word(address_for(0,0),expected(31 downto 0));
    epoch<=2; ticks(4);
    expected:=value_for(8,LAST_CHANNEL_C,2);
    read_word(address_for(8,LAST_CHANNEL_C,true),expected(63 downto 32));
    expected:=value_for(0,0,2);
    read_word(address_for(0,0,true),expected(63 downto 32));

    -- Force a real low-word rollover between the paired software reads.
    carry_enable<=true; ticks(2);
    issue(address_for(0,0)); response(low_word);
    assert unsigned(low_word)>=unsigned'(x"FFFFFFE0")
      report "Carry stimulus did not sample before the rollover" severity failure;
    ticks(75);
    issue(address_for(0,0,true)); response(high_word);
    assert high_word=x"12345678" report "Low/high pair tore across 32-bit carry" severity failure;
    -- The high consumes the cache; a second high must take a fresh snapshot.
    read_word(address_for(0,0,true),x"12345679");
    carry_enable<=false; ticks(5);
    report "paired carry and consume-on-high passed" severity note;

    -- Keep the next address valid throughout a backpressured first response.
    issue(address_for(1,0));
    for i in 0 to TIMEOUT_C*3 loop
      exit when axi_out.RVALID='1'; ticks(1);
    end loop;
    assert axi_out.RVALID='1' report "Missing stalled response" severity failure;
    expected:=value_for(1,0,2);
    assert axi_out.RDATA=expected(31 downto 0) severity failure;
    wait until falling_edge(axi_in.ACLK);
    axi_in.ARADDR<=std_logic_vector(to_unsigned(address_for(7,LAST_CHANNEL_C),32));
    axi_in.ARVALID<='1'; ticks(15);
    assert axi_out.ARREADY='0' report "Busy read accepted another AR address" severity failure;
    response(data);
    for i in 0 to TIMEOUT_C*3 loop
      wait until rising_edge(axi_in.ACLK); exit when axi_out.ARREADY='1';
      assert i<TIMEOUT_C*3 report "Queued AR address was lost" severity failure;
    end loop;
    axi_in.ARVALID<='0'; wait for 1 ns;
    response(data,"00",7); expected:=value_for(7,LAST_CHANNEL_C,2);
    assert data=expected(31 downto 0) report "Queued AR returned wrong counter" severity failure;
    report "backpressure and queued address passed" severity note;

    -- An acquisition-clock outage must not hang AXI or poison the next read.
    ticks(30); counter_run<=false; ticks(3);
    read_word(address_for(0,0),x"00000000","10",4);
    read_word(0,x"0FFFFFFF");
    read_word(address_for(2,0),x"00000000","10");
    epoch<=3; counter_run<=true;
    expected:=value_for(8,LAST_CHANNEL_C,3);
    read_word(address_for(8,LAST_CHANNEL_C),expected(31 downto 0));
    report "stopped-clock timeout, local reads and late-response isolation passed" severity note;

    -- Reset the AXI client with the resetless mailbox still waiting for a clock.
    ticks(30); counter_run<=false; ticks(3); issue(address_for(1,0)); ticks(5);
    reset_axi;
    read_word(LAST_CHANNEL_C*32,x"0FFFFFFF");
    epoch<=4; counter_run<=true;
    expected:=value_for(6,LAST_CHANNEL_C,4);
    read_word(address_for(6,LAST_CHANNEL_C),expected(31 downto 0));

    -- Also reset during a live exchange and while a response is held by RREADY.
    ticks(30); issue(address_for(0,0)); ticks(4); reset_axi;
    expected:=value_for(5,LAST_CHANNEL_C,4);
    read_word(address_for(5,LAST_CHANNEL_C),expected(31 downto 0));
    issue(address_for(4,0));
    for i in 0 to TIMEOUT_C*3 loop
      exit when axi_out.RVALID='1'; ticks(1);
    end loop;
    assert axi_out.RVALID='1' report "Missing response before reset" severity failure;
    reset_axi; epoch<=5; ticks(4);
    expected:=value_for(4,0,5);
    read_word(address_for(4,0,true),expected(63 downto 32));
    ticks(30);
    report "selftrigger_counter_cdc_tb PASS channels=" & integer'image(CHANNEL_COUNT_G) severity note;
    finish;
  end process;
  watchdog : process
  begin
    wait for 200 us; assert false report "selftrigger counter CDC watchdog" severity failure;
  end process;
end architecture;
