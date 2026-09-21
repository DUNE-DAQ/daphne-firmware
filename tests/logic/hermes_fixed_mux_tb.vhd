library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.ipbus.all;
use work.tx_mux_decl.all;

entity hermes_fixed_mux_tb is end;
architecture test of hermes_fixed_mux_tb is
  signal sc, ec : std_logic := '0';
  signal rst : std_logic := '1';
  signal d, q : src_d_array(1 downto 0) := (others=>SRC_D_NULL);
  signal outq : src_d;
  signal ready, re, err : std_logic_vector(1 downto 0);
  signal muxerr : std_logic;
  signal words, endings : natural := 0;
  signal busin : ipb_wbus := (ipb_addr=>(others=>'0'),ipb_wdata=>(others=>'0'),ipb_strobe=>'0',ipb_write=>'0');
begin
  sc <= not sc after 8 ns;
  ec <= not ec after 3.2 ns;
  inputs : for i in 0 to 1 generate
    ibuf : entity work.tx_mux_ibuf
      generic map(PACKET_WORDS=>63, IN_BUF_DEPTH=>512)
      port map(packet_ready=>ready(i),ipb_clk=>sc,ipb_rst=>rst,ipb_in=>busin,ipb_out=>open,
        src_clk=>sc,src_rst=>rst,ts=>(others=>'0'),d=>d(i),samp=>'0',eth_clk=>ec,
        eth_rst=>rst,re=>re(i),q=>q(i),err=>err(i));
  end generate;
  mux : entity work.tx_mux_out
    generic map(N_SRC=>2, IFACE_ID=>0)
    port map(ipb_clk=>sc,ipb_rst=>rst,ipb_in=>busin,ipb_out=>open,clk=>ec,rst=>rst,
      en=>'1',d=>q,re=>re,q=>outq,ready=>'1',mark=>'1',err=>muxerr);
  process(ec)
    variable index, source, sequence : natural := 0;
    type counts_t is array(0 to 1) of natural;
    variable packets : counts_t := (others=>0);
  begin
    if rising_edge(ec) and rst='0' then
      assert err="00" and muxerr='0' report "Hermes mux error" severity failure;
      if outq.valid='1' then
        if index=0 then
          assert unsigned(outq.d(63 downto 52))=63 report "Wrong fragment size" severity failure;
          source:=to_integer(unsigned(outq.d(31 downto 26)));
          assert source<2 report "Wrong source" severity failure;
          sequence:=to_integer(unsigned(outq.d(51 downto 40)));
          assert sequence=packets(source) report "Missing/reordered packet" severity failure;
          index:=1;
        else
          assert unsigned(outq.d)=source*10000+sequence*100+index-1
            report "Payload corruption" severity failure;
          if index=63 then packets(source):=packets(source)+1; index:=0;
          else index:=index+1; end if;
        end if;
        words<=words+1;
      end if;
      if outq.last='1' then endings<=endings+1; end if;
    end if;
  end process;
  process
  begin
    wait for 160 ns; wait until falling_edge(sc); rst<='0';
    for packet in 0 to 1 loop
      loop wait until falling_edge(sc); exit when ready="11"; end loop;
      for w in 0 to 62 loop
        for source in 0 to 1 loop
          d(source).d<=std_logic_vector(to_unsigned(source*10000+packet*100+w,64));
          d(source).valid<='1'; d(source).last<='0';
          if w=62 then d(source).last<='1'; end if;
        end loop;
        wait until falling_edge(sc);
      end loop;
      d<=(others=>SRC_D_NULL);
    end loop;
    wait for 10 us;
    assert words=256 and endings>0 report "Fixed packets never drained through selector/output mux" severity failure;
    report "hermes_fixed_mux_tb PASS: two sources, four complete fragments and UDP end marker";
    stop; wait;
  end process;
  process begin wait for 30 us; assert false report "watchdog" severity failure; end process;
end;
