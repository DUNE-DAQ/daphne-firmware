library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity k26c_board_outbuffer_plane is
port(
    clock: in std_logic;

    outbuff_s_axi_aclk: in std_logic;
    outbuff_s_axi_aresetn: in std_logic;
    outbuff_s_axi_awaddr: in std_logic_vector(31 downto 0);
    outbuff_s_axi_awprot: in std_logic_vector(2 downto 0);
    outbuff_s_axi_awvalid: in std_logic;
    outbuff_s_axi_awready: out std_logic;
    outbuff_s_axi_wdata: in std_logic_vector(31 downto 0);
    outbuff_s_axi_wstrb: in std_logic_vector(3 downto 0);
    outbuff_s_axi_wvalid: in std_logic;
    outbuff_s_axi_wready: out std_logic;
    outbuff_s_axi_bresp: out std_logic_vector(1 downto 0);
    outbuff_s_axi_bvalid: out std_logic;
    outbuff_s_axi_bready: in std_logic;
    outbuff_s_axi_araddr: in std_logic_vector(31 downto 0);
    outbuff_s_axi_arprot: in std_logic_vector(2 downto 0);
    outbuff_s_axi_arvalid: in std_logic;
    outbuff_s_axi_arready: out std_logic;
    outbuff_s_axi_rdata: out std_logic_vector(31 downto 0);
    outbuff_s_axi_rresp: out std_logic_vector(1 downto 0);
    outbuff_s_axi_rvalid: out std_logic;
    outbuff_s_axi_rready: in std_logic;

    readout_data_i: in array_2x64_type;
    readout_valid_i: in std_logic_vector(1 downto 0);
    readout_last_i: in std_logic_vector(1 downto 0);

    out_buff_data: out std_logic_vector(63 downto 0);
    out_buff_trig: out std_logic;
    valid_debug: out std_logic;
    last_debug: out std_logic
);
end k26c_board_outbuffer_plane;

architecture rtl of k26c_board_outbuffer_plane is
begin
  -- The readout monitor remains combinational; no output spy RAM exists.
  removed_output_spy_inst : entity work.axi_lite_unavailable
    port map (
      s_axi_aclk => outbuff_s_axi_aclk,
      s_axi_aresetn => outbuff_s_axi_aresetn,
      s_axi_awaddr => outbuff_s_axi_awaddr,
      s_axi_awprot => outbuff_s_axi_awprot,
      s_axi_awvalid => outbuff_s_axi_awvalid,
      s_axi_awready => outbuff_s_axi_awready,
      s_axi_wdata => outbuff_s_axi_wdata,
      s_axi_wstrb => outbuff_s_axi_wstrb,
      s_axi_wvalid => outbuff_s_axi_wvalid,
      s_axi_wready => outbuff_s_axi_wready,
      s_axi_bresp => outbuff_s_axi_bresp,
      s_axi_bvalid => outbuff_s_axi_bvalid,
      s_axi_bready => outbuff_s_axi_bready,
      s_axi_araddr => outbuff_s_axi_araddr,
      s_axi_arprot => outbuff_s_axi_arprot,
      s_axi_arvalid => outbuff_s_axi_arvalid,
      s_axi_arready => outbuff_s_axi_arready,
      s_axi_rdata => outbuff_s_axi_rdata,
      s_axi_rresp => outbuff_s_axi_rresp,
      s_axi_rvalid => outbuff_s_axi_rvalid,
      s_axi_rready => outbuff_s_axi_rready
    );

  out_buff_data <= readout_data_i(0);
  out_buff_trig <= readout_valid_i(0) or readout_valid_i(1);
  valid_debug   <= readout_valid_i(0);
  last_debug    <= readout_last_i(0);
end architecture rtl;
