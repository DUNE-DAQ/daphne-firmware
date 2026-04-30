library ieee;
use ieee.std_logic_1164.all;

library work;
use work.grouped_transport_pkg.all;

entity grouped_hermes_readout_ooc_src10_top is
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
    readout_i       : in  grouped_source_stream_array_t(9 downto 0);
    timestamp_i     : in  std_logic_vector(63 downto 0);
    sample_strobe_i : in  std_logic;
    timeslice_mark_i: in  std_logic;
    udp_ready_i     : in  std_logic;
    mux_ready_i     : in  std_logic;
    mux_data_o      : out std_logic_vector(63 downto 0);
    mux_valid_o     : out std_logic;
    mux_last_o      : out std_logic
  );
end entity grouped_hermes_readout_ooc_src10_top;

architecture rtl of grouped_hermes_readout_ooc_src10_top is
begin
  dut : entity work.grouped_hermes_readout_ooc_shell
    generic map (
      SOURCE_COUNT_G => 10
    )
    port map (
      ipb_clk_i       => ipb_clk_i,
      ipb_rst_i       => ipb_rst_i,
      ipb_addr_i      => ipb_addr_i,
      ipb_wdata_i     => ipb_wdata_i,
      ipb_strobe_i    => ipb_strobe_i,
      ipb_write_i     => ipb_write_i,
      ipb_rdata_o     => ipb_rdata_o,
      ipb_ack_o       => ipb_ack_o,
      ipb_err_o       => ipb_err_o,
      src_clk_i       => src_clk_i,
      src_rst_i       => src_rst_i,
      eth_clk_i       => eth_clk_i,
      eth_rst_i       => eth_rst_i,
      readout_i       => readout_i,
      timestamp_i     => timestamp_i,
      sample_strobe_i => sample_strobe_i,
      timeslice_mark_i=> timeslice_mark_i,
      udp_ready_i     => udp_ready_i,
      mux_ready_i     => mux_ready_i,
      mux_data_o      => mux_data_o,
      mux_valid_o     => mux_valid_o,
      mux_last_o      => mux_last_o
    );
end architecture rtl;
