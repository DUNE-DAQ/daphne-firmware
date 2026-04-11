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

    readout_data_o: out array_2x64_type;
    readout_valid_o: out std_logic_vector(1 downto 0);
    readout_last_o: out std_logic_vector(1 downto 0)
);
end k26c_selftrigger_datapath_plane;

architecture rtl of k26c_selftrigger_datapath_plane is
  signal threshold_axi_in:   AXILITE_INREC;
  signal threshold_axi_out:  AXILITE_OUTREC;
  signal threshold_xc:       slv28_array_t(0 to 39);
  signal threshold_xc_sync:  slv28_array_t(0 to 39);
  signal TCount:             slv64_array_t(0 to 39);
  signal PCount:             slv64_array_t(0 to 39);
  signal record_count:       slv64_array_t(0 to 39);
  signal full_count:         slv64_array_t(0 to 39);
  signal busy_count:         slv64_array_t(0 to 39);
  signal trigger_samples:    sample14_array_t(0 to 39);
  signal trigger_control:    trigger_xcorr_control_array_t(0 to 39);
  signal trigger_result:     trigger_xcorr_result_array_t(0 to 39);
  signal core_chan_enable_sync: std_logic_vector(39 downto 0);
  signal afe_comp_enable_sync:  std_logic_vector(39 downto 0);
  signal invert_enable_sync:    std_logic_vector(39 downto 0);
  signal adhoc_sync:            std_logic_vector(7 downto 0);
  signal filter_output_selector_sync: std_logic_vector(1 downto 0);
  signal st_config_sync:        std_logic_vector(13 downto 0);
  signal signal_delay_sync:     std_logic_vector(4 downto 0);
  signal reset_st_counters_sync: std_logic;
  signal config_valid:       std_logic_vector(4 downto 0) := (others => '0');
  signal config_cmd:         afe_config_command_bank_t(0 to 4) := (others => AFE_CONFIG_COMMAND_NULL);
  signal config_status:      afe_config_status_bank_t(0 to 4);
  signal afe_miso:           std_logic_vector(4 downto 0) := (others => '0');
  signal afe_sclk:           std_logic_vector(4 downto 0);
  signal afe_sen:            std_logic_vector(4 downto 0);
  signal afe_mosi:           std_logic_vector(4 downto 0);
  signal trim_sclk:          std_logic_vector(4 downto 0);
  signal trim_mosi:          std_logic_vector(4 downto 0);
  signal trim_ldac_n:        std_logic_vector(4 downto 0);
  signal trim_sync_n:        std_logic_vector(4 downto 0);
  signal offset_sclk:        std_logic_vector(4 downto 0);
  signal offset_mosi:        std_logic_vector(4 downto 0);
  signal offset_ldac_n:      std_logic_vector(4 downto 0);
  signal offset_sync_n:      std_logic_vector(4 downto 0);
  signal ready:              std_logic_array_t(0 to 39);
  signal rd_en:              std_logic_array_t(0 to 39);
  signal fabric_dout:        slv72_array_t(0 to 39);
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

  gen_legacy_monitor_outputs : for idx in 0 to 39 generate
  begin
    st_trigger_signal(idx) <= trigger_result(idx).trigger_pulse;
  end generate gen_legacy_monitor_outputs;

  frontend_adapter_inst : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => 5
    )
    port map(
      afe_dout_i        => din_core,
      trigger_samples_o => trigger_samples
    );

  control_sync_inst : entity work.trigger_control_sync
    generic map (
      CHANNEL_COUNT_G => 40
    )
    port map (
      src_clk_i                => thresh_s_axi_aclk,
      src_reset_i              => not thresh_s_axi_aresetn,
      dst_clk_i                => clock,
      dst_reset_i              => reset,
      core_chan_enable_i       => enable,
      afe_comp_enable_i        => afe_comp_enable,
      invert_enable_i          => invert_enable,
      threshold_xc_i           => threshold_xc,
      adhoc_i                  => adhoc,
      filter_output_selector_i => filter_output_selector,
      descriptor_config_i      => st_config,
      signal_delay_i           => signal_delay,
      reset_st_counters_i      => reset_st_counters,
      core_chan_enable_o       => core_chan_enable_sync,
      afe_comp_enable_o        => afe_comp_enable_sync,
      invert_enable_o          => invert_enable_sync,
      threshold_xc_o           => threshold_xc_sync,
      adhoc_o                  => adhoc_sync,
      filter_output_selector_o => filter_output_selector_sync,
      descriptor_config_o      => st_config_sync,
      signal_delay_o           => signal_delay_sync,
      reset_st_counters_o      => reset_st_counters_sync
    );

  control_adapter_inst : entity work.trigger_control_adapter
    generic map (
      CHANNEL_COUNT_G => 40
    )
    port map(
      core_chan_enable_i       => core_chan_enable_sync,
      afe_comp_enable_i        => afe_comp_enable_sync,
      invert_enable_i          => invert_enable_sync,
      threshold_xc_i           => threshold_xc_sync,
      adhoc_i                  => adhoc_sync,
      filter_output_selector_i => filter_output_selector_sync,
      ti_trigger_i             => ti_trigger,
      ti_trigger_stbr_i        => ti_trigger_stbr,
      descriptor_config_i      => st_config_sync,
      signal_delay_i           => signal_delay_sync,
      reset_st_counters_i      => reset_st_counters_sync,
      trigger_control_o        => trigger_control,
      descriptor_config_o      => open,
      signal_delay_o           => open,
      reset_st_counters_o      => open
    );

  daphne_composable_core_top_inst : entity work.daphne_composable_core_top
    generic map (
      AFE_COUNT_G          => 5,
      ENABLE_SELFTRIGGER_G => true,
      ENABLE_TIMING_G      => false,
      ENABLE_HERMES_G      => false
    )
    port map (
      clock_i                   => clock,
      reset_i                   => reset,
      timing_clk_axi_i          => clock,
      timing_resetn_axi_i       => not reset,
      timing_ctrl_i             => TIMING_CONTROL_NULL,
      timing_stat_o             => open,
      timing_timestamp_o        => open,
      timing_sync_o             => open,
      timing_sync_stb_o         => open,
      hermes_descriptor_i       => TRIGGER_DESCRIPTOR_NULL,
      hermes_descriptor_taken_o => open,
      hermes_stat_o             => open,
      config_valid_i            => config_valid,
      config_cmd_i              => config_cmd,
      config_status_o           => config_status,
      afe_miso_i                => afe_miso,
      afe_sclk_o                => afe_sclk,
      afe_sen_o                 => afe_sen,
      afe_mosi_o                => afe_mosi,
      trim_sclk_o               => trim_sclk,
      trim_mosi_o               => trim_mosi,
      trim_ldac_n_o             => trim_ldac_n,
      trim_sync_n_o             => trim_sync_n,
      offset_sclk_o             => offset_sclk,
      offset_mosi_o             => offset_mosi,
      offset_ldac_n_o           => offset_ldac_n,
      offset_sync_n_o           => offset_sync_n,
      reset_st_counters_i       => reset_st_counters_sync,
      force_trigger_i           => forcetrig,
      timestamp_i               => timestamp,
      version_i                 => version(3 downto 0),
      signal_delay_i            => signal_delay_sync,
      descriptor_config_i       => st_config_sync,
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
      delayed_sample_o          => open,
      ready_o                   => ready,
      dout_o                    => fabric_dout
    );

  two_lane_readout_mux_inst : entity work.two_lane_readout_mux
    port map (
      clock_i => clock,
      reset_i => reset,
      ready_i => ready,
      dout_i  => fabric_dout,
      rd_en_o => rd_en,
      dout_o  => readout_data_o,
      valid_o => readout_valid_o,
      last_o  => readout_last_o
    );

  selftrigger_register_bank_inst : entity work.selftrigger_register_bank
    port map (
      AXI_IN         => threshold_axi_in,
      AXI_OUT        => threshold_axi_out,
      threshold_xc_o => threshold_xc,
      record_count_i => record_count,
      full_count_i   => full_count,
      busy_count_i   => busy_count,
      tcount_i       => TCount,
      pcount_i       => PCount
    );
end architecture rtl;
