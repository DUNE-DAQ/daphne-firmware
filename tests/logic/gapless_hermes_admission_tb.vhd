library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;
use work.ipbus.all;
use work.tx_mux_decl.all;

entity gapless_hermes_admission_tb is end;
architecture test of gapless_hermes_admission_tb is
  constant WORDS_C : positive := 63;
  constant PER_CHANNEL_C : positive := 16;
  type indices_t is array(0 to 3) of natural range 0 to WORDS_C-1;
  type counts_t is array(0 to 3) of natural range 0 to PER_CHANNEL_C;
  signal src_clock_s, eth_clock_s : std_logic := '0';
  signal reset_s : std_logic := '1';
  signal ready_s, read_s : std_logic_array_t(0 to 3);
  signal input_s : slv72_array_t(0 to 3);
  signal output_s : array_64_type(0 downto 0);
  signal valid_s, last_s, credit_s : std_logic_vector(0 downto 0);
  signal indices_s : indices_t := (others=>0);
  signal counts_s : counts_t := (others=>0);
  signal packet_s, received_s : src_d := SRC_D_NULL;
  signal read_eth_s, error_s : std_logic := '0';
  signal drain_s : boolean := false;
  signal completed_s, gapless_boundaries_s : natural := 0;
  signal ipb_request_s : ipb_wbus := (ipb_addr=>(others=>'0'),ipb_wdata=>(others=>'0'),ipb_strobe=>'0',ipb_write=>'0');
  signal ipb_response_s : ipb_rbus;
  function payload(channel, packet, index : natural) return std_logic_vector is
  begin
    return x"C256" & std_logic_vector(to_unsigned(channel,8)) &
      std_logic_vector(to_unsigned(packet,8)) & std_logic_vector(to_unsigned(index,32));
  end;
begin
  src_clock_s <= not src_clock_s after 8 ns;
  eth_clock_s <= not eth_clock_s after 3.2 ns;
  channels : for ch in 0 to 3 generate
    ready_s(ch) <= '1' when counts_s(ch)<PER_CHANNEL_C else '0';
    input_s(ch)(63 downto 0) <= payload(ch,counts_s(ch),indices_s(ch));
    input_s(ch)(71 downto 64) <= x"ED" when indices_s(ch)=WORDS_C-1 else x"00";
  end generate;
  readout_mux : entity work.two_lane_readout_mux
    generic map(CHANNEL_COUNT_G=>4,LANE_COUNT_G=>1,CHANNELS_PER_LANE_G=>4,GAPLESS_G=>true)
    port map(clock_i=>src_clock_s,reset_i=>reset_s,ready_i=>ready_s,dout_i=>input_s,
      rd_en_o=>read_s,dout_o=>output_s,valid_o=>valid_s,last_o=>last_s,packet_ready_i=>credit_s);
  packet_s <= (d=>output_s(0),valid=>valid_s(0),last=>last_s(0));
  hermes_input_buffer : entity work.tx_mux_ibuf
    generic map(IN_BUF_DEPTH=>512,PACKET_WORDS=>WORDS_C)
    port map(packet_ready=>credit_s(0),ipb_clk=>src_clock_s,ipb_rst=>reset_s,
      ipb_in=>ipb_request_s,ipb_out=>ipb_response_s,src_clk=>src_clock_s,src_rst=>reset_s,
      ts=>(others=>'0'),d=>packet_s,samp=>'0',eth_clk=>eth_clock_s,eth_rst=>reset_s,
      re=>read_eth_s,q=>received_s,err=>error_s);
  source : process(src_clock_s)
    variable previous_last : std_logic := '0';
  begin
    if rising_edge(src_clock_s) then
      if reset_s='1' then
        indices_s<=(others=>0); counts_s<=(others=>0);
        previous_last:='0'; gapless_boundaries_s<=0;
      else
        if previous_last='1' and valid_s(0)='1' then
          gapless_boundaries_s<=gapless_boundaries_s+1;
        end if;
        previous_last:=last_s(0);
        for ch in 0 to 3 loop
          if read_s(ch)='1' then
            assert ready_s(ch)='1' report "read exhausted source" severity failure;
            if indices_s(ch)=WORDS_C-1 then
              indices_s(ch)<=0; counts_s(ch)<=counts_s(ch)+1;
            else indices_s(ch)<=indices_s(ch)+1; end if;
          end if;
        end loop;
      end if;
    end if;
  end process;
  sink : process(eth_clock_s)
    variable index, packet, cycle : natural := 0;
  begin
    if rising_edge(eth_clock_s) then
      cycle:=cycle+1;
      read_eth_s<='0';
      if drain_s and cycle mod 7/=0 and cycle mod 503<390 then read_eth_s<='1'; end if;
      if reset_s='1' then index:=0; packet:=0; completed_s<=0; read_eth_s<='0';
      else
        assert error_s='0' report "Hermes overflow/underflow" severity failure;
        if read_eth_s='1' and received_s.valid='1' then
          if index=0 then
            assert unsigned(received_s.d(11 downto 0))=WORDS_C severity failure;
            assert unsigned(received_s.d(23 downto 12))=packet severity failure;
            assert received_s.last='0' severity failure;
            index:=1;
          else
            assert received_s.d=payload(packet mod 4,packet/4,index-1)
              report "gapless packet payload reordered or lost" severity failure;
            if index=WORDS_C then
              assert received_s.last='1' severity failure;
              index:=0; packet:=packet+1; completed_s<=packet;
            else
              assert received_s.last='0' severity failure;
              index:=index+1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
  stimulus : process
  begin
    wait for 160 ns; wait until falling_edge(src_clock_s); reset_s<='0';
    -- Deliberately reset during an admitted packet. Both FIFO domains reset;
    -- the following epoch must restart at channel0/packet0 without any tail.
    wait until valid_s(0)='1'; wait for 160 ns;
    wait until falling_edge(src_clock_s); reset_s<='1';
    wait for 160 ns; wait until falling_edge(src_clock_s); reset_s<='0';
    wait for 15 us;
    assert credit_s(0)='0' and completed_s=0
      report "FIFO did not backpressure a stalled sink" severity failure;
    drain_s<=true;
    wait until completed_s=4*PER_CHANNEL_C;
    wait for 1 us;
    assert gapless_boundaries_s>8 report "gapless transitions were not exercised" severity failure;
    assert credit_s(0)='1' report "credit failed to recover" severity failure;
    report "gapless_hermes_admission_tb PASS: 64 packets,63 words,reset during packet,stalled sink,gapless boundaries" severity note;
    stop; wait;
  end process;
  watchdog : process begin wait for 200 us; assert false report "gapless admission watchdog" severity failure; end process;
end;
