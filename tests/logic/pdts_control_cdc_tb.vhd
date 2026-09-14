library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.pdts_defs.all;
use work.pdts_ep_defs.all;
library xpm;
use xpm.vcomponents.all;

entity pdts_control_cdc_tb is end;
architecture test of pdts_control_cdc_tb is
  signal axi_clk, sys_clk, rx_clk : std_logic := '0';
  signal sys_run, rx_run : boolean := true;
  signal axi_resetn : std_logic := '0';
  signal reset_axi, reset_sys, addr_valid_sys : std_logic;
  signal addr_axi, addr_sys : std_logic_vector(15 downto 0);
  signal stat_sys, stat_axi : std_logic_vector(3 downto 0) := (others=>'0');
  signal levels_async, levels_axi : std_logic_vector(2 downto 0) := (others=>'0');
  signal awaddr, wdata, araddr, rdata : std_logic_vector(31 downto 0) := (others=>'0');
  signal awvalid, wvalid, bvalid, arvalid, rvalid, awready, wready, arready : std_logic := '0';
  signal bresp, rresp : std_logic_vector(1 downto 0);
  signal snapshot_reset, snapshot_valid, snapshot_update : std_logic := '1';
  signal snapshot_data, source_data, desired_data : std_logic_vector(15 downto 0) := (others=>'0');
  signal packet_addr, configured_addr : std_logic_vector(15 downto 0) := (others=>'0');
  signal pkt_reset, pkt_stb, pkt_k : std_logic := '0';
  signal pkt_data : std_logic_vector(7 downto 0) := (others=>'0');
  signal pkt_scmd, pkt_acmd : pdts_cmd_w;
  signal recovered_word : std_logic_vector(16 downto 0);
  signal recovered_valid, recovered_reset, address_done : std_logic;
  signal stat_recovered : std_logic_vector(3 downto 0);
  signal stat_recovered_valid : std_logic;
begin
  axi_clk <= not axi_clk after 5 ns;
  process begin
    wait for 5.3 ns;
    if sys_run then sys_clk<=not sys_clk; else sys_clk<='0'; end if;
  end process;
  process begin
    wait for 8.07 ns;
    if rx_run then rx_clk<=not rx_clk; else rx_clk<='0'; end if;
  end process;
  process(sys_clk) begin
    if rising_edge(sys_clk) then source_data<=desired_data; end if;
  end process;

  axi : entity work.ep_axi
    port map(S_AXI_ACLK=>axi_clk, S_AXI_ARESETN=>axi_resetn,
      S_AXI_AWADDR=>awaddr, S_AXI_AWPROT=>"000", S_AXI_AWVALID=>awvalid, S_AXI_AWREADY=>awready,
      S_AXI_WDATA=>wdata, S_AXI_WSTRB=>"1111", S_AXI_WVALID=>wvalid, S_AXI_WREADY=>wready,
      S_AXI_BRESP=>bresp, S_AXI_BVALID=>bvalid, S_AXI_BREADY=>'1',
      S_AXI_ARADDR=>araddr, S_AXI_ARPROT=>"000", S_AXI_ARVALID=>arvalid, S_AXI_ARREADY=>arready,
      S_AXI_RDATA=>rdata, S_AXI_RRESP=>rresp, S_AXI_RVALID=>rvalid, S_AXI_RREADY=>'1',
      ep_ts_rdy=>levels_axi(2), ep_stat=>stat_axi, mmcm0_locked=>levels_axi(0),
      mmcm1_locked=>levels_axi(1), ep_reset=>reset_axi, ep_addr=>addr_axi,
      mmcm1_reset=>open, mmcm0_reset=>open, use_ep=>open);
  boundary : entity work.pdts_endpoint_control_cdc
    port map(axi_clk_i=>axi_clk, axi_resetn_i=>axi_resetn,
      reset_axi_i=>reset_axi, addr_axi_i=>addr_axi, sys_clk_i=>sys_clk,
      reset_sys_o=>reset_sys, addr_sys_o=>addr_sys, addr_valid_sys_o=>addr_valid_sys,
      stat_sys_i=>stat_sys, stat_axi_o=>stat_axi,
      levels_async_i=>levels_async, levels_axi_o=>levels_axi);

  -- The same production helper used by both stages of the address path.
  recovered_reset_cdc : xpm_cdc_async_rst
    generic map(DEST_SYNC_FF=>3, INIT_SYNC_FF=>1, RST_ACTIVE_HIGH=>1)
    port map(src_arst=>reset_sys, dest_clk=>rx_clk, dest_arst=>recovered_reset);
  recovered_address : entity work.pdts_cdc_snapshot
    generic map(WIDTH_G=>17)
    port map(src_clk_i=>sys_clk, src_data_i=>addr_valid_sys & addr_sys,
      dst_clk_i=>rx_clk, dst_reset_i=>recovered_reset, dst_data_o=>recovered_word,
      dst_valid_o=>recovered_valid, dst_update_o=>open);
  recovered_status : entity work.pdts_cdc_snapshot
    generic map(WIDTH_G=>4)
    port map(src_clk_i=>sys_clk, src_data_i=>stat_sys,
      dst_clk_i=>rx_clk, dst_reset_i=>recovered_reset, dst_data_o=>stat_recovered,
      dst_valid_o=>stat_recovered_valid, dst_update_o=>open);
  regfile : entity work.pdts_ep_regfile
    generic map(EXT_ADDR=>true)
    port map(clk=>rx_clk, rst=>recovered_reset, ctrl_in=>PDTS_CMO_NULL, ctrl_out=>open,
      sys_addr=>recovered_word(15 downto 0),
      sys_addr_valid=>recovered_valid and recovered_word(16), addr=>configured_addr,
      stat=>stat_recovered, delay=>open, phase=>open, phase_done=>'0', resync=>open,
      reset=>open, txenb=>open, tstamp=>open, ts_stb=>open, addr_done=>address_done,
      deskew_done=>open);
  snapshot : entity work.pdts_cdc_snapshot
    generic map(WIDTH_G=>16)
    port map(src_clk_i=>sys_clk, src_data_i=>source_data, dst_clk_i=>rx_clk,
      dst_reset_i=>snapshot_reset, dst_data_o=>snapshot_data,
      dst_valid_o=>snapshot_valid, dst_update_o=>snapshot_update);
  packet : entity work.pdts_rx_pkt
    port map(clk=>rx_clk, rst=>pkt_reset, stb=>pkt_stb, addr=>packet_addr,
      d=>pkt_data, k=>pkt_k, scmd=>pkt_scmd, acmd_o=>pkt_acmd,
      acmd_i=>(rdy=>'1'), rdy=>open);

  process
    procedure rx_tick is begin wait until rising_edge(rx_clk); wait for 1 ns; end;
    procedure axi_tick is begin wait until rising_edge(axi_clk); wait for 1 ns; end;
    procedure write_control(value : std_logic_vector(31 downto 0)) is
    begin
      wait until falling_edge(axi_clk);
      awaddr<=x"00000008"; wdata<=value; awvalid<='1'; wvalid<='1';
      loop
        wait until rising_edge(axi_clk);
        exit when awready='1' and wready='1';
      end loop;
      wait for 1 ns; awvalid<='0'; wvalid<='0';
      while bvalid/='1' loop axi_tick; end loop;
      assert bresp="00" report "AXI control write failed" severity failure;
      axi_tick;
    end;
    procedure read_register(offset : natural; expected : std_logic_vector(31 downto 0)) is
    begin
      wait until falling_edge(axi_clk);
      araddr<=std_logic_vector(to_unsigned(offset,32)); arvalid<='1';
      loop wait until rising_edge(axi_clk); exit when arready='1'; end loop;
      wait for 1 ns; arvalid<='0';
      while rvalid/='1' loop axi_tick; end loop;
      assert rresp="00" and rdata=expected report "AXI readback mismatch" severity failure;
      axi_tick;
    end;
    procedure await_address(expected : std_logic_vector(15 downto 0)) is
    begin
      for n in 0 to 1000 loop
        exit when address_done='1' and configured_addr=expected;
        rx_tick;
      end loop;
      assert address_done='1' and configured_addr=expected
        report "Address publication timed out" severity failure;
    end;
    procedure byte(value : std_logic_vector(7 downto 0); special : std_logic := '0') is
    begin
      wait until falling_edge(rx_clk); pkt_stb<='1'; pkt_k<=special; pkt_data<=value; rx_tick;
    end;
    procedure packet_start(address_value : std_logic_vector(15 downto 0)) is
    begin
      pkt_reset<='1'; pkt_stb<='0'; rx_tick; rx_tick;
      packet_addr<=address_value; pkt_reset<='0'; byte(CCHAR,'1');
    end;
    variable old_value, new_value : std_logic_vector(15 downto 0);
  begin
    pkt_reset<='1';
    wait for 90 ns; axi_resetn<='1'; snapshot_reset<='0';
    await_address(x"0000");
    assert addr_axi=x"0000" and reset_axi='0' report "Default AXI control changed" severity failure;
    read_register(8,x"00000000");

    -- Stop the recovered clock throughout a complete asserted/released reset.
    -- System reset must still release, then the recovered reset bridge retains
    -- the request until clock restart. Admission must require the fresh address.
    rx_run<=false; wait for 40 ns;
    write_control(x"00011234"); wait for 80 ns;
    assert reset_sys='1' report "System reset did not assert" severity failure;
    write_control(x"0001ABCD"); write_control(x"00005678");
    wait for 300 ns;
    assert reset_sys='0' report "Reset waits for stopped recovered clock" severity failure;
    assert recovered_reset='1' report "Stopped-clock reset was lost" severity failure;
    rx_run<=true; rx_tick;
    assert address_done='0' report "Reset retained stale address validity" severity failure;
    await_address(x"5678");

    -- Repeated AXI updates may coalesce; the final complete register value must
    -- arrive, and the unchanged register ABI remains readable.
    for n in 1 to 12 loop write_control(std_logic_vector(to_unsigned(n*257,32))); end loop;
    await_address(x"0C0C"); read_register(8,x"00000C0C");
    wait until falling_edge(axi_clk); wait for 4 ns; levels_async<="101";
    axi_tick;
    assert levels_axi="000" report "Independent status bypassed first synchronization stage" severity failure;
    axi_tick;
    assert levels_axi="000" report "Independent status bypassed second synchronization stage" severity failure;
    axi_tick;
    assert levels_axi="101" report "Independent status mapping/latency changed" severity failure;
    stat_sys<=x"7"; wait for 2 us;
    read_register(4,x"00000001"); read_register(12,x"00000017");
    assert stat_recovered_valid='1' and stat_recovered=x"7" report "Recovered state snapshot missing" severity failure;
    stat_sys<=x"8"; wait for 2 us;
    read_register(12,x"00000018");

    -- The local system clock can stop too. An entire AXI reset pulse must be
    -- remembered until it restarts, and the address must refresh afterwards.
    sys_run<=false; wait for 25 ns;
    write_control(x"0001CAFE"); write_control(x"0000CAFE"); wait for 100 ns;
    assert reset_sys='1' report "Reset released while local system clock was stopped" severity failure;
    sys_run<=true; await_address(x"CAFE");

    -- Exercise every part of request/response/drain with resets at different
    -- phases. A pre-reset response must never validate a post-reset value.
    for trial in 0 to 24 loop
      old_value:=std_logic_vector(to_unsigned(16#1100#+trial,16));
      new_value:=std_logic_vector(to_unsigned(16#AA00#+trial,16));
      desired_data<=old_value;
      for n in 0 to 1000 loop exit when snapshot_valid='1' and snapshot_data=old_value; rx_tick; end loop;
      assert snapshot_data=old_value report "Initial snapshot missing" severity failure;
      wait for trial*23 ns;
      sys_run<=false; wait for 25 ns;
      snapshot_reset<='1'; rx_tick; rx_tick; desired_data<=new_value;
      snapshot_reset<='0';
      for n in 0 to 30 loop
        -- Repeated reset before the outstanding request can drain.
        if trial mod 3=0 and n=8 then snapshot_reset<='1'; end if;
        if trial mod 3=0 and n=11 then snapshot_reset<='0'; end if;
        rx_tick;
        assert snapshot_valid='0' report "Pre-reset response validated after reset" severity failure;
      end loop;
      sys_run<=true;
      for n in 0 to 1000 loop
        rx_tick; exit when snapshot_valid='1';
      end loop;
      assert snapshot_valid='1' and snapshot_data=new_value
        report "Fresh reset snapshot missing or stale" severity failure;
    end loop;

    -- Actual packet parser: both address bytes must use the comma's snapshot.
    for n in 0 to 15 loop
      old_value:=std_logic_vector(to_unsigned(16#1200#+n,16));
      new_value:=std_logic_vector(to_unsigned(16#AB80#+n,16));
      packet_start(old_value); byte(old_value(7 downto 0));
      packet_addr<=new_value;
      byte(old_value(15 downto 8)); byte(x"55");
      assert pkt_acmd.valid='1' report "Address changed within accepted packet" severity failure;
      packet_start(old_value); byte(old_value(7 downto 0));
      packet_addr<=new_value;
      byte(new_value(15 downto 8)); byte(x"55");
      assert pkt_acmd.valid='0' report "Mixed old/new address accepted" severity failure;
      packet_start(new_value); byte(new_value(7 downto 0)); byte(new_value(15 downto 8)); byte(x"55");
      assert pkt_acmd.valid='1' report "New packet did not use new address" severity failure;
    end loop;
    report "pdts_control_cdc_tb PASS" severity note; stop; wait;
  end process;
  process begin wait for 1 ms; assert false report "Test timeout" severity failure; end process;
end architecture;
