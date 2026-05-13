library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.grouped_transport_pkg.all;

entity k26c_board_grouped_outbuffer_plane is
  generic (
    SOURCE_COUNT_G : positive := 5
  );
  port (
    clock                : in  std_logic;

    outbuff_s_axi_aclk   : in  std_logic;
    outbuff_s_axi_aresetn: in  std_logic;
    outbuff_s_axi_awaddr : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_awprot : in  std_logic_vector(2 downto 0);
    outbuff_s_axi_awvalid: in  std_logic;
    outbuff_s_axi_awready: out std_logic;
    outbuff_s_axi_wdata  : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_wstrb  : in  std_logic_vector(3 downto 0);
    outbuff_s_axi_wvalid : in  std_logic;
    outbuff_s_axi_wready : out std_logic;
    outbuff_s_axi_bresp  : out std_logic_vector(1 downto 0);
    outbuff_s_axi_bvalid : out std_logic;
    outbuff_s_axi_bready : in  std_logic;
    outbuff_s_axi_araddr : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_arprot : in  std_logic_vector(2 downto 0);
    outbuff_s_axi_arvalid: in  std_logic;
    outbuff_s_axi_arready: out std_logic;
    outbuff_s_axi_rdata  : out std_logic_vector(31 downto 0);
    outbuff_s_axi_rresp  : out std_logic_vector(1 downto 0);
    outbuff_s_axi_rvalid : out std_logic;
    outbuff_s_axi_rready : in  std_logic;

    readout_i            : in  grouped_source_stream_array_t(0 to SOURCE_COUNT_G - 1);

    out_buff_data        : out std_logic_vector(63 downto 0);
    out_buff_trig        : out std_logic;
    valid_debug          : out std_logic;
    last_debug           : out std_logic
  );
end entity k26c_board_grouped_outbuffer_plane;

architecture rtl of k26c_board_grouped_outbuffer_plane is
  signal outbuff_axi_in       : AXILITE_INREC;
  signal outbuff_axi_out      : AXILITE_OUTREC;
  signal legacy_readout_data  : array_2x64_type := (others => (others => '0'));
  signal legacy_readout_valid : std_logic_vector(1 downto 0) := (others => '0');
  signal legacy_readout_last  : std_logic_vector(1 downto 0) := (others => '0');
begin
  outbuff_axi_in.ACLK    <= outbuff_s_axi_aclk;
  outbuff_axi_in.ARESETN <= outbuff_s_axi_aresetn;
  outbuff_axi_in.AWADDR  <= outbuff_s_axi_awaddr;
  outbuff_axi_in.AWPROT  <= outbuff_s_axi_awprot;
  outbuff_axi_in.AWVALID <= outbuff_s_axi_awvalid;
  outbuff_axi_in.WDATA   <= outbuff_s_axi_wdata;
  outbuff_axi_in.WSTRB   <= outbuff_s_axi_wstrb;
  outbuff_axi_in.WVALID  <= outbuff_s_axi_wvalid;
  outbuff_axi_in.BREADY  <= outbuff_s_axi_bready;
  outbuff_axi_in.ARADDR  <= outbuff_s_axi_araddr;
  outbuff_axi_in.ARPROT  <= outbuff_s_axi_arprot;
  outbuff_axi_in.ARVALID <= outbuff_s_axi_arvalid;
  outbuff_axi_in.RREADY  <= outbuff_s_axi_rready;

  outbuff_s_axi_awready <= outbuff_axi_out.AWREADY;
  outbuff_s_axi_wready  <= outbuff_axi_out.WREADY;
  outbuff_s_axi_bresp   <= outbuff_axi_out.BRESP;
  outbuff_s_axi_bvalid  <= outbuff_axi_out.BVALID;
  outbuff_s_axi_arready <= outbuff_axi_out.ARREADY;
  outbuff_s_axi_rdata   <= outbuff_axi_out.RDATA;
  outbuff_s_axi_rresp   <= outbuff_axi_out.RRESP;
  outbuff_s_axi_rvalid  <= outbuff_axi_out.RVALID;

  -- The deployed outbuffer path is still two-source shaped. The grouped draft
  -- preserves debug continuity by tapping the first two grouped producers
  -- rather than recreating the retired 40-channel seam.
  gen_legacy_debug_lanes : for idx in 0 to 1 generate
    constant SOURCE_IDX_C : natural := idx;
  begin
    gen_connected_lane : if SOURCE_IDX_C < SOURCE_COUNT_G generate
    begin
      legacy_readout_data(idx)  <= readout_i(SOURCE_IDX_C).data;
      legacy_readout_valid(idx) <= readout_i(SOURCE_IDX_C).valid;
      legacy_readout_last(idx)  <= readout_i(SOURCE_IDX_C).last;
    end generate gen_connected_lane;

    gen_empty_lane : if SOURCE_IDX_C >= SOURCE_COUNT_G generate
    begin
      legacy_readout_data(idx)  <= (others => '0');
      legacy_readout_valid(idx) <= '0';
      legacy_readout_last(idx)  <= '0';
    end generate gen_empty_lane;
  end generate gen_legacy_debug_lanes;

  outbuff_inst : entity work.outspybuff
    port map (
      clock   => clock,
      din     => legacy_readout_data,
      valid   => legacy_readout_valid,
      last    => legacy_readout_last,
      AXI_IN  => outbuff_axi_in,
      AXI_OUT => outbuff_axi_out
    );

  out_buff_data <= legacy_readout_data(0);
  out_buff_trig <= legacy_readout_valid(0) or legacy_readout_valid(1);
  valid_debug   <= legacy_readout_valid(0);
  last_debug    <= legacy_readout_last(0);
end architecture rtl;
