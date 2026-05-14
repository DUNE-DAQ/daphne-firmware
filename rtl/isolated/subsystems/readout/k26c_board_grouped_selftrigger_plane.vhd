library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.grouped_transport_pkg.all;

entity k26c_board_grouped_selftrigger_plane is
  generic (
    AFE_COUNT_G             : positive range 1 to 5 := 5;
    CHANNELS_PER_AFE_G      : positive := 8;
    CHANNELS_PER_PRODUCER_G : positive := 4;
    HERMES_IN_BUF_DEPTH_G   : natural  := 2048;
    HERMES_IN_BUF_MEMORY_TYPE_G : string := "ultra";
    RING_MEMORY_PRIMITIVE_G : string   := "ultra";
    ENABLE_OUTBUFFER_G      : boolean  := false
  );
  port (
    link_id                : in  std_logic_vector(5 downto 0);
    slot_id                : in  std_logic_vector(3 downto 0);
    crate_id               : in  std_logic_vector(9 downto 0);
    detector_id            : in  std_logic_vector(5 downto 0);
    version                : in  std_logic_vector(5 downto 0);
    filter_output_selector : in  std_logic_vector(1 downto 0);
    afe_comp_enable        : in  std_logic_vector((AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1 downto 0);
    invert_enable          : in  std_logic_vector((AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1 downto 0);
    st_config              : in  std_logic_vector(13 downto 0);
    signal_delay           : in  std_logic_vector(4 downto 0);
    clock                  : in  std_logic;
    reset                  : in  std_logic;
    reset_st_counters      : in  std_logic;
    timestamp              : in  std_logic_vector(63 downto 0);
    enable                 : in  std_logic_vector((AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1 downto 0);
    forcetrig              : in  std_logic;
    st_trigger_signal      : out std_logic_vector((AFE_COUNT_G * CHANNELS_PER_AFE_G) - 1 downto 0);
    adhoc                  : in  std_logic_vector(7 downto 0);
    ti_trigger             : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr        : in  std_logic;
    din_core               : in  array_5x9x16_type;

    trirg_s_axi_aclk       : in  std_logic;
    trirg_s_axi_aresetn    : in  std_logic;
    trirg_s_axi_awaddr     : in  std_logic_vector(31 downto 0);
    trirg_s_axi_awprot     : in  std_logic_vector(2 downto 0);
    trirg_s_axi_awvalid    : in  std_logic;
    trirg_s_axi_awready    : out std_logic;
    trirg_s_axi_wdata      : in  std_logic_vector(31 downto 0);
    trirg_s_axi_wstrb      : in  std_logic_vector(3 downto 0);
    trirg_s_axi_wvalid     : in  std_logic;
    trirg_s_axi_wready     : out std_logic;
    trirg_s_axi_bresp      : out std_logic_vector(1 downto 0);
    trirg_s_axi_bvalid     : out std_logic;
    trirg_s_axi_bready     : in  std_logic;
    trirg_s_axi_araddr     : in  std_logic_vector(31 downto 0);
    trirg_s_axi_arprot     : in  std_logic_vector(2 downto 0);
    trirg_s_axi_arvalid    : in  std_logic;
    trirg_s_axi_arready    : out std_logic;
    trirg_s_axi_rdata      : out std_logic_vector(31 downto 0);
    trirg_s_axi_rresp      : out std_logic_vector(1 downto 0);
    trirg_s_axi_rvalid     : out std_logic;
    trirg_s_axi_rready     : in  std_logic;

    thresh_s_axi_aclk      : in  std_logic;
    thresh_s_axi_aresetn   : in  std_logic;
    thresh_s_axi_awaddr    : in  std_logic_vector(31 downto 0);
    thresh_s_axi_awprot    : in  std_logic_vector(2 downto 0);
    thresh_s_axi_awvalid   : in  std_logic;
    thresh_s_axi_awready   : out std_logic;
    thresh_s_axi_wdata     : in  std_logic_vector(31 downto 0);
    thresh_s_axi_wstrb     : in  std_logic_vector(3 downto 0);
    thresh_s_axi_wvalid    : in  std_logic;
    thresh_s_axi_wready    : out std_logic;
    thresh_s_axi_bresp     : out std_logic_vector(1 downto 0);
    thresh_s_axi_bvalid    : out std_logic;
    thresh_s_axi_bready    : in  std_logic;
    thresh_s_axi_araddr    : in  std_logic_vector(31 downto 0);
    thresh_s_axi_arprot    : in  std_logic_vector(2 downto 0);
    thresh_s_axi_arvalid   : in  std_logic;
    thresh_s_axi_arready   : out std_logic;
    thresh_s_axi_rdata     : out std_logic_vector(31 downto 0);
    thresh_s_axi_rresp     : out std_logic_vector(1 downto 0);
    thresh_s_axi_rvalid    : out std_logic;
    thresh_s_axi_rready    : in  std_logic;

    outbuff_s_axi_aclk     : in  std_logic;
    outbuff_s_axi_aresetn  : in  std_logic;
    outbuff_s_axi_awaddr   : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_awprot   : in  std_logic_vector(2 downto 0);
    outbuff_s_axi_awvalid  : in  std_logic;
    outbuff_s_axi_awready  : out std_logic;
    outbuff_s_axi_wdata    : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_wstrb    : in  std_logic_vector(3 downto 0);
    outbuff_s_axi_wvalid   : in  std_logic;
    outbuff_s_axi_wready   : out std_logic;
    outbuff_s_axi_bresp    : out std_logic_vector(1 downto 0);
    outbuff_s_axi_bvalid   : out std_logic;
    outbuff_s_axi_bready   : in  std_logic;
    outbuff_s_axi_araddr   : in  std_logic_vector(31 downto 0);
    outbuff_s_axi_arprot   : in  std_logic_vector(2 downto 0);
    outbuff_s_axi_arvalid  : in  std_logic;
    outbuff_s_axi_arready  : out std_logic;
    outbuff_s_axi_rdata    : out std_logic_vector(31 downto 0);
    outbuff_s_axi_rresp    : out std_logic_vector(1 downto 0);
    outbuff_s_axi_rvalid   : out std_logic;
    outbuff_s_axi_rready   : in  std_logic;

    eth_clk_p              : in  std_logic;
    eth_clk_n              : in  std_logic;
    eth0_rx_p              : in  std_logic_vector(0 downto 0);
    eth0_rx_n              : in  std_logic_vector(0 downto 0);
    eth0_tx_p              : out std_logic_vector(0 downto 0);
    eth0_tx_n              : out std_logic_vector(0 downto 0);
    eth0_tx_dis            : out std_logic_vector(0 downto 0);

    out_buff_data          : out std_logic_vector(63 downto 0);
    out_buff_trig          : out std_logic;
    valid_debug            : out std_logic;
    last_debug             : out std_logic
  );
end entity k26c_board_grouped_selftrigger_plane;

architecture rtl of k26c_board_grouped_selftrigger_plane is
  constant SOURCE_COUNT_C : positive := (AFE_COUNT_G * CHANNELS_PER_AFE_G) / CHANNELS_PER_PRODUCER_G;

  signal grouped_readout_s : grouped_source_stream_array_t(0 to SOURCE_COUNT_C - 1);
  signal grouped_ready_s   : std_logic_vector(0 to SOURCE_COUNT_C - 1);
begin
  -- These identifiers are retained for interface parity with the deployed
  -- board plane. The grouped draft path does not yet thread them into the
  -- transport payload.

  datapath_plane_inst : entity work.k26c_grouped_selftrigger_datapath_plane
    generic map (
      AFE_COUNT_G             => AFE_COUNT_G,
      CHANNELS_PER_AFE_G      => CHANNELS_PER_AFE_G,
      CHANNELS_PER_PRODUCER_G => CHANNELS_PER_PRODUCER_G,
      RING_MEMORY_PRIMITIVE_G => RING_MEMORY_PRIMITIVE_G
    )
    port map (
      version                => version,
      filter_output_selector => filter_output_selector,
      afe_comp_enable        => afe_comp_enable,
      invert_enable          => invert_enable,
      st_config              => st_config,
      signal_delay           => signal_delay,
      clock                  => clock,
      reset                  => reset,
      reset_st_counters      => reset_st_counters,
      timestamp              => timestamp,
      enable                 => enable,
      forcetrig              => forcetrig,
      st_trigger_signal      => st_trigger_signal,
      adhoc                  => adhoc,
      ti_trigger             => ti_trigger,
      ti_trigger_stbr        => ti_trigger_stbr,
      din_core               => din_core,
      thresh_s_axi_aclk      => thresh_s_axi_aclk,
      thresh_s_axi_aresetn   => thresh_s_axi_aresetn,
      thresh_s_axi_awaddr    => thresh_s_axi_awaddr,
      thresh_s_axi_awprot    => thresh_s_axi_awprot,
      thresh_s_axi_awvalid   => thresh_s_axi_awvalid,
      thresh_s_axi_awready   => thresh_s_axi_awready,
      thresh_s_axi_wdata     => thresh_s_axi_wdata,
      thresh_s_axi_wstrb     => thresh_s_axi_wstrb,
      thresh_s_axi_wvalid    => thresh_s_axi_wvalid,
      thresh_s_axi_wready    => thresh_s_axi_wready,
      thresh_s_axi_bresp     => thresh_s_axi_bresp,
      thresh_s_axi_bvalid    => thresh_s_axi_bvalid,
      thresh_s_axi_bready    => thresh_s_axi_bready,
      thresh_s_axi_araddr    => thresh_s_axi_araddr,
      thresh_s_axi_arprot    => thresh_s_axi_arprot,
      thresh_s_axi_arvalid   => thresh_s_axi_arvalid,
      thresh_s_axi_arready   => thresh_s_axi_arready,
      thresh_s_axi_rdata     => thresh_s_axi_rdata,
      thresh_s_axi_rresp     => thresh_s_axi_rresp,
      thresh_s_axi_rvalid    => thresh_s_axi_rvalid,
      thresh_s_axi_rready    => thresh_s_axi_rready,
      grouped_readout_o      => grouped_readout_s,
      grouped_readout_ready_i=> grouped_ready_s
    );

  transport_plane_inst : entity work.k26c_board_grouped_transport_plane
    generic map (
      SOURCE_COUNT_G        => SOURCE_COUNT_C,
      HERMES_IN_BUF_DEPTH_G => HERMES_IN_BUF_DEPTH_G,
      HERMES_IN_BUF_MEMORY_TYPE_G => HERMES_IN_BUF_MEMORY_TYPE_G,
      ENABLE_OUTBUFFER_G    => ENABLE_OUTBUFFER_G
    )
    port map (
      clock               => clock,
      reset               => reset,
      timestamp           => timestamp,
      trirg_s_axi_aclk    => trirg_s_axi_aclk,
      trirg_s_axi_aresetn => trirg_s_axi_aresetn,
      trirg_s_axi_awaddr  => trirg_s_axi_awaddr,
      trirg_s_axi_awprot  => trirg_s_axi_awprot,
      trirg_s_axi_awvalid => trirg_s_axi_awvalid,
      trirg_s_axi_awready => trirg_s_axi_awready,
      trirg_s_axi_wdata   => trirg_s_axi_wdata,
      trirg_s_axi_wstrb   => trirg_s_axi_wstrb,
      trirg_s_axi_wvalid  => trirg_s_axi_wvalid,
      trirg_s_axi_wready  => trirg_s_axi_wready,
      trirg_s_axi_bresp   => trirg_s_axi_bresp,
      trirg_s_axi_bvalid  => trirg_s_axi_bvalid,
      trirg_s_axi_bready  => trirg_s_axi_bready,
      trirg_s_axi_araddr  => trirg_s_axi_araddr,
      trirg_s_axi_arprot  => trirg_s_axi_arprot,
      trirg_s_axi_arvalid => trirg_s_axi_arvalid,
      trirg_s_axi_arready => trirg_s_axi_arready,
      trirg_s_axi_rdata   => trirg_s_axi_rdata,
      trirg_s_axi_rresp   => trirg_s_axi_rresp,
      trirg_s_axi_rvalid  => trirg_s_axi_rvalid,
      trirg_s_axi_rready  => trirg_s_axi_rready,
      outbuff_s_axi_aclk   => outbuff_s_axi_aclk,
      outbuff_s_axi_aresetn=> outbuff_s_axi_aresetn,
      outbuff_s_axi_awaddr => outbuff_s_axi_awaddr,
      outbuff_s_axi_awprot => outbuff_s_axi_awprot,
      outbuff_s_axi_awvalid=> outbuff_s_axi_awvalid,
      outbuff_s_axi_awready=> outbuff_s_axi_awready,
      outbuff_s_axi_wdata  => outbuff_s_axi_wdata,
      outbuff_s_axi_wstrb  => outbuff_s_axi_wstrb,
      outbuff_s_axi_wvalid => outbuff_s_axi_wvalid,
      outbuff_s_axi_wready => outbuff_s_axi_wready,
      outbuff_s_axi_bresp  => outbuff_s_axi_bresp,
      outbuff_s_axi_bvalid => outbuff_s_axi_bvalid,
      outbuff_s_axi_bready => outbuff_s_axi_bready,
      outbuff_s_axi_araddr => outbuff_s_axi_araddr,
      outbuff_s_axi_arprot => outbuff_s_axi_arprot,
      outbuff_s_axi_arvalid=> outbuff_s_axi_arvalid,
      outbuff_s_axi_arready=> outbuff_s_axi_arready,
      outbuff_s_axi_rdata  => outbuff_s_axi_rdata,
      outbuff_s_axi_rresp  => outbuff_s_axi_rresp,
      outbuff_s_axi_rvalid => outbuff_s_axi_rvalid,
      outbuff_s_axi_rready => outbuff_s_axi_rready,
      eth_clk_p           => eth_clk_p,
      eth_clk_n           => eth_clk_n,
      eth0_rx_p           => eth0_rx_p,
      eth0_rx_n           => eth0_rx_n,
      eth0_tx_p           => eth0_tx_p,
      eth0_tx_n           => eth0_tx_n,
      eth0_tx_dis         => eth0_tx_dis,
      readout_i           => grouped_readout_s,
      readout_ready_o     => grouped_ready_s,
      out_buff_data       => out_buff_data,
      out_buff_trig       => out_buff_trig,
      valid_debug         => valid_debug,
      last_debug          => last_debug
    );
end architecture rtl;
