library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.udp_core_pkg.all;
use work.axi4s_pkg.all;

-- The DUT is the real UDP MM top with real XPM. Its TX datapath boundary exposes
-- header inputs in tdata(185:0); it does not generate or validate Ethernet frames.
entity hermes_network_config_cdc_tb is end entity;
architecture test of hermes_network_config_cdc_tb is
  subtype snapshot_t is std_logic_vector(185 downto 0);
  signal mm_clk, tx_clk : std_logic := '0';
  signal tx_run : boolean := true;
  signal mm_rst : std_logic := '1';
  signal setting_index : natural := 0;
  signal regs : t_udp_core_settings;
  signal arp_regs : t_arp_mode_control;
  signal lut_regs : t_farm_mode_lut_out;
  signal observed : t_axi4s_mosi;
  signal expected_old, expected_new, expected_reset : snapshot_t := (others=>'0');
  signal check_enabled : boolean := false;
  function settings(seed : natural) return t_udp_core_settings is
    variable r : t_udp_core_settings;
  begin
    -- Every consumed configuration field has a distinct bit pattern; zero is
    -- also a valid snapshot, including after reset during a pending transfer.
    r.dst_mac_addr_upper := std_logic_vector(to_unsigned(16#1020#*seed,16));
    r.dst_mac_addr_lower := std_logic_vector(to_unsigned(16#3040506#*seed,32));
    r.dst_ip_addr := std_logic_vector(to_unsigned(16#7123456#*seed,32));
    r.udp_ports.dst_port := std_logic_vector(to_unsigned(16#3041#*seed,16));
    r.ethertype := std_logic_vector(to_unsigned(16#102#*seed,16));
    r.ipv4_header_0.ip_ver_hdr_len := std_logic_vector(to_unsigned(16#21#*seed,8));
    r.ipv4_header_0.ip_service := std_logic_vector(to_unsigned(16#32#*seed,8));
    r.ipv4_header_1.ip_count := std_logic_vector(to_unsigned(16#1023#*seed,16));
    r.ipv4_header_1.ip_fragment := std_logic_vector(to_unsigned(16#4056#*seed,16));
    r.ipv4_header_2.ip_ttl := std_logic_vector(to_unsigned(16#15#*seed,8));
    r.ipv4_header_2.ip_protocol := std_logic_vector(to_unsigned(16#23#*seed,8));
    r.ifg := std_logic_vector(to_unsigned(16#19#*seed,16));
    r.control.tuser_dst_prt := '0'; r.control.tuser_src_prt := '0';
    if seed mod 2=1 then r.control.tuser_dst_prt:='1'; end if;
    if seed>1 then r.control.tuser_src_prt:='1'; end if;
    return r;
  end function;
  function reverse_octets(v : std_logic_vector) return std_logic_vector is
    variable normalized : std_logic_vector(v'length-1 downto 0) := v;
    variable r : std_logic_vector(v'length-1 downto 0);
  begin
    for i in 0 to v'length/8-1 loop
      r(8*i+7 downto 8*i):=normalized(normalized'left-8*i downto normalized'left-8*i-7);
    end loop;
    return r;
  end function;
  function header_inputs(seed : natural) return snapshot_t is
    variable r : t_udp_core_settings := settings(seed);
  begin
    return reverse_octets(r.dst_mac_addr_upper & r.dst_mac_addr_lower) &
      reverse_octets(r.dst_ip_addr) & reverse_octets(r.udp_ports.dst_port) &
      r.ethertype & r.ipv4_header_0.ip_ver_hdr_len & r.ipv4_header_0.ip_service &
      r.ipv4_header_1.ip_count & r.ipv4_header_1.ip_fragment &
      r.ipv4_header_2.ip_ttl & r.ipv4_header_2.ip_protocol & r.ifg(7 downto 0) &
      r.control.tuser_dst_prt & r.control.tuser_src_prt;
  end function;
begin
  mm_clk <= not mm_clk after 5 ns;
  process begin wait for 3203 ps;
    if tx_run then tx_clk<=not tx_clk; else tx_clk<='0'; end if;
  end process;
  process(mm_clk) begin
    if rising_edge(mm_clk) then
      if mm_rst='1' then regs<=settings(0); else regs<=settings(setting_index); end if;
    end if;
  end process;
  dut : entity work.udp_core_xml_mm_scalable_top
    generic map(G_MM_TX_CDC=>true, G_INC_RX_PATH=>false, G_INC_PING=>false,
      G_INC_ARP=>false, G_INC_LUTS=>false, G_INC_ETH=>false, G_INC_IPV4=>false)
    port map(udp_core_settings_control_regs=>regs, udp_core_settings_status_regs=>open,
      arp_mode_control_regs=>arp_regs, arp_mode_status_regs=>open,
      farm_mode_lut_control=>lut_regs, farm_mode_lut_status=>open,
      mm_clk=>mm_clk, mm_rst=>mm_rst, tx_core_clk=>tx_clk, rx_core_clk=>tx_clk,
      tx_core_rst_s_n=>'1', rx_core_rst_s_n=>'1', rx_axi4s_s_aclk=>tx_clk,
      rx_axi4s_s_areset_n=>'1', rx_in_axi4s_s_mosi=>c_axi4s_mosi_default,
      rx_in_axi4s_s_miso=>open, tx_axi4s_m_aclk=>tx_clk, tx_axi4s_m_areset_n=>'1',
      tx_out_axi4s_m_mosi=>observed, tx_out_axi4s_m_miso=>c_axi4s_miso_default,
      udp_axi4s_s_mosi=>c_axi4s_mosi_default, udp_axi4s_s_miso=>open,
      udp_axi4s_m_miso=>c_axi4s_miso_default, udp_axi4s_m_mosi=>open,
      ipv4_axi4s_s_miso=>open, ipv4_axi4s_m_mosi=>open,
      eth_axi4s_s_miso=>open, eth_axi4s_m_mosi=>open,
      use_ext_addr=>'1', ext_mac_addr=>X"102030405060", ext_ip_addr=>X"0A000001", ext_port_addr=>X"BEEF");
  process begin
    wait until rising_edge(tx_clk); wait for 1 ps;
    if check_enabled then
      assert observed.tdata(185 downto 0)=expected_old or
             observed.tdata(185 downto 0)=expected_new or
             observed.tdata(185 downto 0)=expected_reset
        report "Torn or unexpected 186-bit header snapshot" severity failure;
    end if;
  end process;
  process
    procedure await_snapshot(seed : natural) is
      variable expected : snapshot_t := header_inputs(seed);
    begin
      for cycle in 1 to 180 loop
        wait until rising_edge(tx_clk); wait for 1 ps;
        if observed.tdata(185 downto 0)=expected then return; end if;
      end loop;
      assert false report "Missing snapshot after mailbox reset: seed=" & integer'image(seed) severity failure;
    end procedure;
  begin
    wait for 80 ns; mm_rst<='0'; setting_index<=1;
    expected_old<=header_inputs(0); expected_new<=header_inputs(1);
    await_snapshot(1); check_enabled<=true;
    setting_index<=0; await_snapshot(0);
    setting_index<=1; await_snapshot(1); wait for 400 ns;
    report "Initial configuration and explicit zero/nonzero writes arrived coherently";

    -- Pause the destination after the first exchange is idle. Source captures
    -- word 2, then its register bank resets to zero before the TX clock resumes.
    -- Both word 2 and reset word 0 must arrive, in order, with no cancellation.
    wait until falling_edge(tx_clk); tx_run<=false;
    expected_old<=header_inputs(1); expected_new<=header_inputs(2);
    wait until falling_edge(mm_clk); setting_index<=2;
    for cycle in 1 to 4 loop wait until rising_edge(mm_clk); end loop;
    wait until falling_edge(mm_clk); mm_rst<='1'; setting_index<=0;
    wait for 60 ns; mm_rst<='0'; wait for 50 ns;
    tx_run<=true; await_snapshot(2); await_snapshot(0); wait for 400 ns;
    report "Stopped-clock reset preserved pending word and delivered reset snapshot";

    -- Reset at several phases of an active source/acknowledgment round trip.
    -- Once reset has completed, zero must replace the previous settings even
    -- if source input equals its power-on value. New writes must still work.
    for phase in 0 to 5 loop
      expected_old<=header_inputs(0); expected_new<=header_inputs(3);
      setting_index<=3;
      for cycle in 1 to phase+3 loop wait until rising_edge(mm_clk); end loop;
      wait for 1 ns; mm_rst<='1'; setting_index<=0;
      wait for 30 ns; mm_rst<='0'; wait for 1000 ns;
      assert observed.tdata(185 downto 0)=header_inputs(0)
        report "Reset default was lost at handshake phase " & integer'image(phase) severity failure;
      expected_new<=header_inputs(1); setting_index<=1; await_snapshot(1);
      wait for 400 ns;
      expected_old<=header_inputs(1); expected_new<=header_inputs(0);
      setting_index<=0; await_snapshot(0); wait for 400 ns;
    end loop;
    report "hermes_network_config_cdc_tb PASS: actual UDP top, real XPM, all 186 bits, stopped clock, reset in flight and recovery";
    stop; wait;
  end process;
  process begin wait for 30 us; assert false report "Network configuration CDC watchdog" severity failure; end process;
end architecture;
