-- Behavioral handshake model; vendor XPM verification remains a synthesis-lab check.
library ieee;
use ieee.std_logic_1164.all;
entity xpm_cdc_handshake is
  generic(DEST_EXT_HSK:integer:=1; DEST_SYNC_FF:integer:=2; INIT_SYNC_FF:integer:=1;
    SIM_ASSERT_CHK:integer:=1; SRC_SYNC_FF:integer:=2; WIDTH:integer:=1);
  port(src_clk:in std_logic; src_in:in std_logic_vector(WIDTH-1 downto 0);
    src_send:in std_logic; src_rcv:out std_logic; dest_clk:in std_logic;
    dest_out:out std_logic_vector(WIDTH-1 downto 0); dest_req:out std_logic; dest_ack:in std_logic);
end entity;
architecture sim of xpm_cdc_handshake is
  signal data_s:std_logic_vector(WIDTH-1 downto 0):=(others=>'0');
  signal req_pipe:std_logic_vector(DEST_SYNC_FF-1 downto 0):=(others=>'0');
  signal ack_pipe:std_logic_vector(SRC_SYNC_FF-1 downto 0):=(others=>'0');
  signal sent_s, prev_s:std_logic:='0';
begin
  assert DEST_EXT_HSK=1 report "handshake model requires external acknowledgement" severity failure;
  process(src_clk) begin
    if rising_edge(src_clk) then
      ack_pipe<=ack_pipe(SRC_SYNC_FF-2 downto 0)&dest_ack;
      if src_send='1' and prev_s='0' then data_s<=src_in; end if;
      sent_s<=src_send; prev_s<=src_send;
    end if;
  end process;
  process(dest_clk) begin
    if rising_edge(dest_clk) then
      req_pipe<=req_pipe(DEST_SYNC_FF-2 downto 0)&sent_s;
      dest_req<=req_pipe(DEST_SYNC_FF-1);
      if req_pipe(DEST_SYNC_FF-1)='1' then dest_out<=data_s; end if;
    end if;
  end process;
  src_rcv<=ack_pipe(SRC_SYNC_FF-1);
end architecture;
