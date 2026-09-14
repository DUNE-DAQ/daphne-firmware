library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity k26c_selftrigger_datapath_plane is
port(
    version: in std_logic_vector(5 downto 0);
    filter_output_selector: in std_logic_vector(1 downto 0);
    afe_comp_enable: in std_logic_vector(39 downto 0);
    invert_enable: in std_logic_vector(39 downto 0);
    st_config: in std_logic_vector(13 downto 0);
    signal_delay: in std_logic_vector(4 downto 0);
    clock: in std_logic;
    reset: in std_logic;
    reset_st_counters: in std_logic;
    timestamp: in std_logic_vector(63 downto 0);
    enable: in std_logic_vector(39 downto 0);
    forcetrig: in std_logic;
    force_calibration_tag: in std_logic_vector(1 downto 0);
    st_trigger_signal: out std_logic_vector(39 downto 0);
    adhoc: in std_logic_vector(7 downto 0);
    ti_trigger: in std_logic_vector(7 downto 0);
    ti_trigger_stbr: in std_logic;
    din_core: in array_5x9x16_type;

    thresh_s_axi_aclk: in std_logic;
    thresh_s_axi_aresetn: in std_logic;
    thresh_s_axi_awaddr: in std_logic_vector(31 downto 0);
    thresh_s_axi_awprot: in std_logic_vector(2 downto 0);
    thresh_s_axi_awvalid: in std_logic;
    thresh_s_axi_awready: out std_logic;
    thresh_s_axi_wdata: in std_logic_vector(31 downto 0);
    thresh_s_axi_wstrb: in std_logic_vector(3 downto 0);
    thresh_s_axi_wvalid: in std_logic;
    thresh_s_axi_wready: out std_logic;
    thresh_s_axi_bresp: out std_logic_vector(1 downto 0);
    thresh_s_axi_bvalid: out std_logic;
    thresh_s_axi_bready: in std_logic;
    thresh_s_axi_araddr: in std_logic_vector(31 downto 0);
    thresh_s_axi_arprot: in std_logic_vector(2 downto 0);
    thresh_s_axi_arvalid: in std_logic;
    thresh_s_axi_arready: out std_logic;
    thresh_s_axi_rdata: out std_logic_vector(31 downto 0);
    thresh_s_axi_rresp: out std_logic_vector(1 downto 0);
    thresh_s_axi_rvalid: out std_logic;
    thresh_s_axi_rready: in std_logic;

    readout_data_o: out array_8x64_type;
    readout_valid_o: out std_logic_vector(7 downto 0);
    readout_last_o: out std_logic_vector(7 downto 0);
    readout_ready_i: in std_logic_vector(7 downto 0) := (others => '1');
    readout_reset_o: out std_logic
);
end k26c_selftrigger_datapath_plane;

architecture rtl of k26c_selftrigger_datapath_plane is
  constant ACTIVE_AFE_COUNT_C     : positive := 4;
  constant ACTIVE_CHANNEL_COUNT_C : positive := 32;
  constant READOUT_LANE_COUNT_C   : positive := 8;
  constant CHANNELS_PER_LANE_C    : positive := 4;
  signal builder_clock_s, builder_reset_s, acquisition_reset_s : std_logic;
  signal threshold_axi_in:   AXILITE_INREC;
  signal threshold_axi_out:  AXILITE_OUTREC;
  signal threshold_xc:       slv28_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal continuation_config: slv32_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal TCount:             slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal PCount:             slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal continuation_count: slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal continuation_drop_count: slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal covered_trigger_count: slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal descriptor_overflow_count: slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal record_count:       slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal full_count:         slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal busy_count:         slv64_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal trigger_samples:    sample14_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal trigger_control:    trigger_xcorr_control_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal trigger_result:     trigger_xcorr_result_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal ready:              std_logic_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal rd_en:              std_logic_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
  signal fabric_dout:        slv72_array_t(0 to ACTIVE_CHANNEL_COUNT_C - 1);
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

  gen_legacy_monitor_outputs : for idx in 0 to ACTIVE_CHANNEL_COUNT_C - 1 generate
  begin
    st_trigger_signal(idx) <= trigger_result(idx).trigger_pulse;
  end generate gen_legacy_monitor_outputs;
  st_trigger_signal(39 downto ACTIVE_CHANNEL_COUNT_C) <= (others => '0');

  frontend_adapter_inst : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => ACTIVE_AFE_COUNT_C
    )
    port map(
      afe_dout_i        => din_core,
      trigger_samples_o => trigger_samples
    );

  control_adapter_inst : entity work.trigger_control_adapter
    generic map (
      CHANNEL_COUNT_G => ACTIVE_CHANNEL_COUNT_C
    )
    port map(
      core_chan_enable_i       => enable(ACTIVE_CHANNEL_COUNT_C - 1 downto 0),
      afe_comp_enable_i        => afe_comp_enable(ACTIVE_CHANNEL_COUNT_C - 1 downto 0),
      invert_enable_i          => invert_enable(ACTIVE_CHANNEL_COUNT_C - 1 downto 0),
      threshold_xc_i           => threshold_xc,
      continuation_config_i    => continuation_config,
      adhoc_i                  => adhoc,
      filter_output_selector_i => filter_output_selector,
      ti_trigger_i             => ti_trigger,
      ti_trigger_stbr_i        => ti_trigger_stbr,
      descriptor_config_i      => st_config,
      signal_delay_i           => signal_delay,
      reset_st_counters_i      => reset_st_counters,
      trigger_control_o        => trigger_control,
      descriptor_config_o      => open,
      signal_delay_o           => open,
      reset_st_counters_o      => open
    );

  readout_reset_o <= acquisition_reset_s;

  grouped_clock_inst : entity work.grouped_builder_clock
    port map(clock_i=>clock, reset_i=>reset, builder_clock_o=>builder_clock_s,
      builder_reset_o=>builder_reset_s, acquisition_reset_o=>acquisition_reset_s);

  grouped_fabric_inst : entity work.grouped_selftrigger_fabric
    generic map (AFE_COUNT_G=>ACTIVE_AFE_COUNT_C)
    port map (
      clock_i=>clock, reset_i=>acquisition_reset_s,
      builder_clock_i=>builder_clock_s, builder_reset_i=>builder_reset_s,
      reset_st_counters_i       => reset_st_counters,
      force_trigger_i           => forcetrig,
      force_calibration_tag_i   => force_calibration_tag,
      timestamp_i               => timestamp,
      version_i                 => version(3 downto 0),
      signal_delay_i            => signal_delay,
      descriptor_config_i       => st_config,
      din_i                     => trigger_samples,
      trigger_control_i         => trigger_control,
      rd_en_i                   => rd_en,
      trigger_result_o          => trigger_result,
      descriptor_result_o       => open,
      record_count_o            => record_count,
      full_count_o              => full_count,
      busy_count_o              => busy_count,
      trigger_count_o           => TCount,
      packet_count_o            => PCount,
      continuation_count_o            => continuation_count,
      continuation_drop_count_o            => continuation_drop_count,
      covered_trigger_count_o            => covered_trigger_count,
      descriptor_overflow_count_o            => descriptor_overflow_count,
      delayed_sample_o          => open,
      ready_o                   => ready,
      dout_o                    => fabric_dout
    );

  -- Two adjacent four-channel lanes feed each Hermes link:0..7,8..15,
  --16..23 and24..31. The public monitor/config ports remain 40 bits wide;
  --channels32..39 are intentionally unavailable in this resource-fit build.
  two_lane_readout_mux_inst : entity work.two_lane_readout_mux
    generic map(
      CHANNEL_COUNT_G     => ACTIVE_CHANNEL_COUNT_C,
      LANE_COUNT_G        => READOUT_LANE_COUNT_C,
      CHANNELS_PER_LANE_G => CHANNELS_PER_LANE_C
    )
    port map (
      clock_i => clock,
      reset_i => acquisition_reset_s,
      ready_i => ready,
      dout_i  => fabric_dout,
      rd_en_o => rd_en,
      dout_o  => readout_data_o,
      valid_o => readout_valid_o,
      last_o  => readout_last_o,
      packet_ready_i => readout_ready_i
    );

  selftrigger_register_bank_inst : entity work.selftrigger_register_bank
    generic map (
      CHANNEL_COUNT_G => ACTIVE_CHANNEL_COUNT_C
    )
    port map (
      AXI_IN         => threshold_axi_in,
      AXI_OUT        => threshold_axi_out,
      counter_clock_i => clock,
      threshold_xc_o => threshold_xc,
      continuation_config_o => continuation_config,
      record_count_i => record_count,
      full_count_i   => full_count,
      busy_count_i   => busy_count,
      tcount_i       => TCount,
      pcount_i       => PCount,
      continuation_count_i       => continuation_count,
      continuation_drop_count_i       => continuation_drop_count,
      covered_trigger_count_i       => covered_trigger_count,
      descriptor_overflow_count_i       => descriptor_overflow_count
    );
end architecture rtl;
