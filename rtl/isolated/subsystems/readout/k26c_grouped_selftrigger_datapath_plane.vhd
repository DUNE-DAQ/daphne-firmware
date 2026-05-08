library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;
use work.grouped_transport_pkg.all;

entity k26c_grouped_selftrigger_datapath_plane is
  generic (
    AFE_COUNT_G             : positive range 1 to 5 := 5;
    CHANNELS_PER_AFE_G      : positive := 8;
    CHANNELS_PER_PRODUCER_G : positive := 4
  );
  port (
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

    grouped_readout_o      : out grouped_source_stream_array_t(
      0 to ((AFE_COUNT_G * CHANNELS_PER_AFE_G) / CHANNELS_PER_PRODUCER_G) - 1
    );
    grouped_readout_ready_i : in  std_logic_vector(
      0 to ((AFE_COUNT_G * CHANNELS_PER_AFE_G) / CHANNELS_PER_PRODUCER_G) - 1
    )
  );
end entity k26c_grouped_selftrigger_datapath_plane;

architecture rtl of k26c_grouped_selftrigger_datapath_plane is
  constant CHANNEL_COUNT_C : positive := AFE_COUNT_G * CHANNELS_PER_AFE_G;

  signal threshold_axi_in  : AXILITE_INREC;
  signal threshold_axi_out : AXILITE_OUTREC;
  signal threshold_xc      : slv28_array_t(0 to CHANNEL_COUNT_C - 1);
  signal tcount            : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal pcount            : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal record_count      : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal full_count        : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal busy_count        : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal delayed_sample    : sample14_array_t(0 to CHANNEL_COUNT_C - 1);
  signal trigger_control   : trigger_xcorr_control_array_t(0 to CHANNEL_COUNT_C - 1);
  signal trigger_result    : trigger_xcorr_result_array_t(0 to CHANNEL_COUNT_C - 1);
  signal descriptor_result : peak_descriptor_result_array_t(0 to CHANNEL_COUNT_C - 1);
begin
  threshold_axi_in.ACLK    <= thresh_s_axi_aclk;
  threshold_axi_in.ARESETN <= thresh_s_axi_aresetn;
  threshold_axi_in.AWADDR  <= thresh_s_axi_awaddr;
  threshold_axi_in.AWPROT  <= thresh_s_axi_awprot;
  threshold_axi_in.AWVALID <= thresh_s_axi_awvalid;
  threshold_axi_in.WDATA   <= thresh_s_axi_wdata;
  threshold_axi_in.WSTRB   <= thresh_s_axi_wstrb;
  threshold_axi_in.WVALID  <= thresh_s_axi_wvalid;
  threshold_axi_in.BREADY  <= thresh_s_axi_bready;
  threshold_axi_in.ARADDR  <= thresh_s_axi_araddr;
  threshold_axi_in.ARPROT  <= thresh_s_axi_arprot;
  threshold_axi_in.ARVALID <= thresh_s_axi_arvalid;
  threshold_axi_in.RREADY  <= thresh_s_axi_rready;

  thresh_s_axi_awready <= threshold_axi_out.AWREADY;
  thresh_s_axi_wready  <= threshold_axi_out.WREADY;
  thresh_s_axi_bresp   <= threshold_axi_out.BRESP;
  thresh_s_axi_bvalid  <= threshold_axi_out.BVALID;
  thresh_s_axi_arready <= threshold_axi_out.ARREADY;
  thresh_s_axi_rdata   <= threshold_axi_out.RDATA;
  thresh_s_axi_rresp   <= threshold_axi_out.RRESP;
  thresh_s_axi_rvalid  <= threshold_axi_out.RVALID;

  gen_monitor_outputs : for idx in 0 to CHANNEL_COUNT_C - 1 generate
  begin
    st_trigger_signal(idx) <= trigger_result(idx).trigger_pulse;
  end generate gen_monitor_outputs;

  grouped_bridge_inst : entity work.grouped_selftrigger_fabric_bridge
    generic map (
      AFE_COUNT_G             => AFE_COUNT_G,
      CHANNELS_PER_PRODUCER_G => CHANNELS_PER_PRODUCER_G
    )
    port map (
      clock_i                  => clock,
      reset_i                  => reset,
      frontend_dout_i          => din_core,
      core_chan_enable_i       => enable,
      afe_comp_enable_i        => afe_comp_enable,
      invert_enable_i          => invert_enable,
      threshold_xc_i           => threshold_xc,
      adhoc_i                  => adhoc,
      filter_output_selector_i => filter_output_selector,
      ti_trigger_i             => ti_trigger,
      ti_trigger_stbr_i        => ti_trigger_stbr,
      descriptor_config_i      => st_config,
      signal_delay_i           => signal_delay,
      reset_st_counters_i      => reset_st_counters,
      force_trigger_i          => forcetrig,
      timestamp_i              => timestamp,
      version_i                => version(3 downto 0),
      trigger_result_o         => trigger_result,
      descriptor_result_o      => descriptor_result,
      record_count_o           => record_count,
      full_count_o             => full_count,
      busy_count_o             => busy_count,
      trigger_count_o          => tcount,
      packet_count_o           => pcount,
      delayed_sample_o         => delayed_sample,
      grouped_readout_ready_i  => grouped_readout_ready_i,
      grouped_readout_o        => grouped_readout_o
    );

  selftrigger_register_bank_inst : entity work.selftrigger_register_bank
    generic map (
      CHANNEL_COUNT_G => CHANNEL_COUNT_C
    )
    port map (
      AXI_IN         => threshold_axi_in,
      AXI_OUT        => threshold_axi_out,
      threshold_xc_o => threshold_xc,
      record_count_i => record_count,
      full_count_i   => full_count,
      busy_count_i   => busy_count,
      tcount_i       => tcount,
      pcount_i       => pcount
    );
end architecture rtl;
