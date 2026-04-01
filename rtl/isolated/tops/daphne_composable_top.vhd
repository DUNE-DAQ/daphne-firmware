library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity daphne_composable_top is
  generic (
    AFE_COUNT_G         : positive range 1 to 5 := 5;
    ENABLE_SELFTRIGGER_G : boolean := true;
    ENABLE_TIMING_G     : boolean := true;
    ENABLE_HERMES_G     : boolean := true;
    ENABLE_SPYBUFFER_G  : boolean := true
  );
  port (
    afe_p                 : in  array_5x9_type;
    afe_n                 : in  array_5x9_type;
    afe_clk_p             : out std_logic;
    afe_clk_n             : out std_logic;
    clk500                : in  std_logic;
    clk125                : in  std_logic;
    clock                 : in  std_logic;
    trig_in               : in  std_logic;
    frontend_axi_aclk     : in  std_logic;
    frontend_axi_aresetn  : in  std_logic;
    frontend_axi_awaddr   : in  std_logic_vector(31 downto 0);
    frontend_axi_awprot   : in  std_logic_vector(2 downto 0);
    frontend_axi_awvalid  : in  std_logic;
    frontend_axi_awready  : out std_logic;
    frontend_axi_wdata    : in  std_logic_vector(31 downto 0);
    frontend_axi_wstrb    : in  std_logic_vector(3 downto 0);
    frontend_axi_wvalid   : in  std_logic;
    frontend_axi_wready   : out std_logic;
    frontend_axi_bresp    : out std_logic_vector(1 downto 0);
    frontend_axi_bvalid   : out std_logic;
    frontend_axi_bready   : in  std_logic;
    frontend_axi_araddr   : in  std_logic_vector(31 downto 0);
    frontend_axi_arprot   : in  std_logic_vector(2 downto 0);
    frontend_axi_arvalid  : in  std_logic;
    frontend_axi_arready  : out std_logic;
    frontend_axi_rdata    : out std_logic_vector(31 downto 0);
    frontend_axi_rresp    : out std_logic_vector(1 downto 0);
    frontend_axi_rvalid   : out std_logic;
    frontend_axi_rready   : in  std_logic;
    timing_clk_axi_i      : in  std_logic;
    timing_resetn_axi_i   : in  std_logic;
    timing_ctrl_i         : in  timing_control_t;
    timing_stat_o         : out timing_status_t;
    timing_timestamp_o    : out std_logic_vector(63 downto 0);
    timing_sync_o         : out std_logic_vector(7 downto 0);
    timing_sync_stb_o     : out std_logic;
    hermes_descriptor_i   : in  trigger_descriptor_t;
    hermes_descriptor_taken_o : out std_logic;
    hermes_stat_o         : out hermes_boundary_status_t;
    config_valid_i        : in  std_logic_vector(AFE_COUNT_G - 1 downto 0);
    config_cmd_i          : in  afe_config_command_bank_t(0 to AFE_COUNT_G - 1);
    config_status_o       : out afe_config_status_bank_t(0 to AFE_COUNT_G - 1);
    afe_miso_i            : in  std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_sclk_o            : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_sen_o             : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_mosi_o            : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_sclk_o           : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_mosi_o           : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_ldac_n_o         : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_sync_n_o         : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_sclk_o         : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_mosi_o         : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_ldac_n_o       : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_sync_n_o       : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    reset_st_counters_i   : in  std_logic;
    force_trigger_i       : in  std_logic;
    timestamp_i           : in  std_logic_vector(63 downto 0);
    version_i             : in  std_logic_vector(3 downto 0);
    signal_delay_i        : in  std_logic_vector(4 downto 0);
    descriptor_config_i   : in  std_logic_vector(13 downto 0);
    trigger_control_i     : in  trigger_xcorr_control_array_t(0 to (AFE_COUNT_G * 8) - 1);
    rd_en_i               : in  std_logic_array_t(0 to (AFE_COUNT_G * 8) - 1);
    frontend_dout_o       : out array_5x9x16_type;
    frontend_trig_o       : out std_logic;
    trigger_result_o      : out trigger_xcorr_result_array_t(0 to (AFE_COUNT_G * 8) - 1);
    descriptor_result_o   : out peak_descriptor_result_array_t(0 to (AFE_COUNT_G * 8) - 1);
    record_count_o        : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    full_count_o          : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    busy_count_o          : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    trigger_count_o       : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    packet_count_o        : out slv64_array_t(0 to (AFE_COUNT_G * 8) - 1);
    delayed_sample_o      : out sample14_array_t(0 to (AFE_COUNT_G * 8) - 1);
    ready_o               : out std_logic_array_t(0 to (AFE_COUNT_G * 8) - 1);
    dout_o                : out slv72_array_t(0 to (AFE_COUNT_G * 8) - 1)
  );
end entity daphne_composable_top;

architecture rtl of daphne_composable_top is
  signal frontend_dout_s       : array_5x9x16_type;
  signal frontend_trig_s       : std_logic;
begin
  frontend_island_inst : entity work.frontend_island
    generic map (
      AFE_COUNT_G => AFE_COUNT_G
    )
    port map (
      afe_p         => afe_p,
      afe_n         => afe_n,
      afe_clk_p     => afe_clk_p,
      afe_clk_n     => afe_clk_n,
      clk500        => clk500,
      clk125        => clk125,
      clock         => clock,
      dout          => frontend_dout_s,
      trig          => frontend_trig_s,
      trig_IN       => trig_in,
      S_AXI_ACLK    => frontend_axi_aclk,
      S_AXI_ARESETN => frontend_axi_aresetn,
      S_AXI_AWADDR  => frontend_axi_awaddr,
      S_AXI_AWPROT  => frontend_axi_awprot,
      S_AXI_AWVALID => frontend_axi_awvalid,
      S_AXI_AWREADY => frontend_axi_awready,
      S_AXI_WDATA   => frontend_axi_wdata,
      S_AXI_WSTRB   => frontend_axi_wstrb,
      S_AXI_WVALID  => frontend_axi_wvalid,
      S_AXI_WREADY  => frontend_axi_wready,
      S_AXI_BRESP   => frontend_axi_bresp,
      S_AXI_BVALID  => frontend_axi_bvalid,
      S_AXI_BREADY  => frontend_axi_bready,
      S_AXI_ARADDR  => frontend_axi_araddr,
      S_AXI_ARPROT  => frontend_axi_arprot,
      S_AXI_ARVALID => frontend_axi_arvalid,
      S_AXI_ARREADY => frontend_axi_arready,
      S_AXI_RDATA   => frontend_axi_rdata,
      S_AXI_RRESP   => frontend_axi_rresp,
      S_AXI_RVALID  => frontend_axi_rvalid,
      S_AXI_RREADY  => frontend_axi_rready
    );

  frontend_shell_inst : entity work.daphne_composable_frontend_shell
    generic map (
      AFE_COUNT_G          => AFE_COUNT_G,
      ENABLE_SELFTRIGGER_G => ENABLE_SELFTRIGGER_G,
      ENABLE_TIMING_G      => ENABLE_TIMING_G,
      ENABLE_HERMES_G      => ENABLE_HERMES_G,
      ENABLE_SPYBUFFER_G   => ENABLE_SPYBUFFER_G
    )
    port map (
      clock_i                   => clock,
      frontend_resetn_i         => frontend_axi_aresetn,
      timing_clk_axi_i          => timing_clk_axi_i,
      timing_resetn_axi_i       => timing_resetn_axi_i,
      timing_ctrl_i             => timing_ctrl_i,
      timing_stat_o             => timing_stat_o,
      timing_timestamp_o        => timing_timestamp_o,
      timing_sync_o             => timing_sync_o,
      timing_sync_stb_o         => timing_sync_stb_o,
      hermes_descriptor_i       => hermes_descriptor_i,
      hermes_descriptor_taken_o => hermes_descriptor_taken_o,
      hermes_stat_o             => hermes_stat_o,
      config_valid_i            => config_valid_i,
      config_cmd_i              => config_cmd_i,
      config_status_o           => config_status_o,
      afe_miso_i                => afe_miso_i,
      afe_sclk_o                => afe_sclk_o,
      afe_sen_o                 => afe_sen_o,
      afe_mosi_o                => afe_mosi_o,
      trim_sclk_o               => trim_sclk_o,
      trim_mosi_o               => trim_mosi_o,
      trim_ldac_n_o             => trim_ldac_n_o,
      trim_sync_n_o             => trim_sync_n_o,
      offset_sclk_o             => offset_sclk_o,
      offset_mosi_o             => offset_mosi_o,
      offset_ldac_n_o           => offset_ldac_n_o,
      offset_sync_n_o           => offset_sync_n_o,
      reset_st_counters_i       => reset_st_counters_i,
      force_trigger_i           => force_trigger_i,
      timestamp_i               => timestamp_i,
      version_i                 => version_i,
      signal_delay_i            => signal_delay_i,
      descriptor_config_i       => descriptor_config_i,
      frontend_dout_i           => frontend_dout_s,
      frontend_trig_i           => frontend_trig_s,
      trigger_control_i         => trigger_control_i,
      rd_en_i                   => rd_en_i,
      frontend_dout_o           => frontend_dout_o,
      frontend_trig_o           => frontend_trig_o,
      trigger_result_o          => trigger_result_o,
      descriptor_result_o       => descriptor_result_o,
      record_count_o            => record_count_o,
      full_count_o              => full_count_o,
      busy_count_o              => busy_count_o,
      trigger_count_o           => trigger_count_o,
      packet_count_o            => packet_count_o,
      delayed_sample_o          => delayed_sample_o,
      ready_o                   => ready_o,
      dout_o                    => dout_o
    );

  -- ENABLE_TIMING_G / ENABLE_HERMES_G / ENABLE_SPYBUFFER_G are carried here so
  -- this top can grow into the full composable shell without changing its public
  -- generic contract. The frontend-facing top now delegates adapter/timing/Hermes/
  -- AFE ownership to daphne_composable_frontend_shell so the public shell seam can
  -- be validated offline without pulling in the vendor-specific frontend island.
end architecture rtl;
