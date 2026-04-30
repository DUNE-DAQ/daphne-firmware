library ieee;
use ieee.std_logic_1164.all;

library work;
use work.grouped_transport_pkg.all;
use work.ipbus.all;
use work.tx_mux_decl.all;

entity grouped_hermes_readout_ooc_shell is
  generic (
    SOURCE_COUNT_G : positive := 5;
    IN_BUF_DEPTH_G : natural := 2048
  );
  port (
    ipb_clk_i       : in  std_logic;
    ipb_rst_i       : in  std_logic;
    ipb_addr_i      : in  std_logic_vector(31 downto 0);
    ipb_wdata_i     : in  std_logic_vector(31 downto 0);
    ipb_strobe_i    : in  std_logic;
    ipb_write_i     : in  std_logic;
    ipb_rdata_o     : out std_logic_vector(31 downto 0);
    ipb_ack_o       : out std_logic;
    ipb_err_o       : out std_logic;
    src_clk_i       : in  std_logic;
    src_rst_i       : in  std_logic;
    eth_clk_i       : in  std_logic;
    eth_rst_i       : in  std_logic;
    readout_i       : in  grouped_source_stream_array_t(SOURCE_COUNT_G - 1 downto 0);
    timestamp_i     : in  std_logic_vector(63 downto 0);
    sample_strobe_i : in  std_logic;
    timeslice_mark_i: in  std_logic;
    udp_ready_i     : in  std_logic;
    mux_ready_i     : in  std_logic;
    mux_data_o      : out std_logic_vector(63 downto 0);
    mux_valid_o     : out std_logic;
    mux_last_o      : out std_logic
  );
end entity grouped_hermes_readout_ooc_shell;

architecture rtl of grouped_hermes_readout_ooc_shell is
  component tx_mux is
    generic(
      N_SRC        : positive;
      IFACE_ID     : integer;
      IN_BUF_DEPTH : natural
    );
    port(
      ipb_clk   : in  std_logic;
      ipb_rst   : in  std_logic;
      ipb_in    : in  ipb_wbus;
      ipb_out   : out ipb_rbus;
      src_clk   : in  std_logic;
      src_rst   : in  std_logic;
      ts        : in  std_logic_vector(63 downto 0);
      d         : in  src_d_array(N_SRC - 1 downto 0);
      samp      : in  std_logic;
      mark      : in  std_logic;
      eth_clk   : in  std_logic;
      eth_rst   : in  std_logic;
      eth_q     : out src_d;
      eth_ready : in  std_logic;
      udp_ready : in  std_logic
    );
  end component tx_mux;

  signal ipb_in_s  : ipb_wbus := IPB_WBUS_NULL;
  signal ipb_out_s : ipb_rbus := IPB_RBUS_NULL;
  signal mux_q_s   : src_d     := SRC_D_NULL;
begin
  ipb_in_s.ipb_addr   <= ipb_addr_i;
  ipb_in_s.ipb_wdata  <= ipb_wdata_i;
  ipb_in_s.ipb_strobe <= ipb_strobe_i;
  ipb_in_s.ipb_write  <= ipb_write_i;

  ipb_rdata_o <= ipb_out_s.ipb_rdata;
  ipb_ack_o   <= ipb_out_s.ipb_ack;
  ipb_err_o   <= ipb_out_s.ipb_err;

  mux_data_o  <= mux_q_s.d;
  mux_valid_o <= mux_q_s.valid;
  mux_last_o  <= mux_q_s.last;

  dut : tx_mux
    generic map (
      N_SRC        => SOURCE_COUNT_G,
      IFACE_ID     => 0,
      IN_BUF_DEPTH => IN_BUF_DEPTH_G
    )
    port map (
      ipb_clk   => ipb_clk_i,
      ipb_rst   => ipb_rst_i,
      ipb_in    => ipb_in_s,
      ipb_out   => ipb_out_s,
      src_clk   => src_clk_i,
      src_rst   => src_rst_i,
      ts        => timestamp_i,
      d         => to_src_d_array(readout_i),
      samp      => sample_strobe_i,
      mark      => timeslice_mark_i,
      eth_clk   => eth_clk_i,
      eth_rst   => eth_rst_i,
      eth_q     => mux_q_s,
      eth_ready => mux_ready_i,
      udp_ready => udp_ready_i
    );
end architecture rtl;
