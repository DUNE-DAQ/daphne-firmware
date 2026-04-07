library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity k26c_board_timing_plane is
  port (
    sysclk_p                : in  std_logic;
    sysclk_n                : in  std_logic;
    sfp_tmg_los             : in  std_logic;
    rx0_tmg_p               : in  std_logic;
    rx0_tmg_n               : in  std_logic;
    sfp_tmg_tx_dis          : out std_logic;
    tx0_tmg_p               : out std_logic;
    tx0_tmg_n               : out std_logic;
    clock_gen_debug         : out std_logic;
    mmcm0_100mhz_clk_debug  : out std_logic;
    ep_62p5mhz_clk_debug    : out std_logic;
    f_ok_debug              : out std_logic;
    sctr_debug              : out std_logic_vector(15 downto 0);
    cctr_debug              : out std_logic_vector(15 downto 0);
    clock_o                 : out std_logic;
    clk500_o                : out std_logic;
    clk125_o                : out std_logic;
    timestamp_o             : out std_logic_vector(63 downto 0);
    sync_o                  : out std_logic_vector(7 downto 0);
    sync_stb_o              : out std_logic;
    timing_stat_o           : out timing_status_t;
    s_axi_aclk              : in  std_logic;
    s_axi_aresetn           : in  std_logic;
    s_axi_awaddr            : in  std_logic_vector(31 downto 0);
    s_axi_awprot            : in  std_logic_vector(2 downto 0);
    s_axi_awvalid           : in  std_logic;
    s_axi_awready           : out std_logic;
    s_axi_wdata             : in  std_logic_vector(31 downto 0);
    s_axi_wstrb             : in  std_logic_vector(3 downto 0);
    s_axi_wvalid            : in  std_logic;
    s_axi_wready            : out std_logic;
    s_axi_bresp             : out std_logic_vector(1 downto 0);
    s_axi_bvalid            : out std_logic;
    s_axi_bready            : in  std_logic;
    s_axi_araddr            : in  std_logic_vector(31 downto 0);
    s_axi_arprot            : in  std_logic_vector(2 downto 0);
    s_axi_arvalid           : in  std_logic;
    s_axi_arready           : out std_logic;
    s_axi_rdata             : out std_logic_vector(31 downto 0);
    s_axi_rresp             : out std_logic_vector(1 downto 0);
    s_axi_rvalid            : out std_logic;
    s_axi_rready            : in  std_logic
  );
end entity k26c_board_timing_plane;

architecture rtl of k26c_board_timing_plane is
  signal timing_status_s : timing_status_t := TIMING_STATUS_NULL;
begin
  endpoint_inst : entity work.endpoint
    port map (
      sysclk_p                 => sysclk_p,
      sysclk_n                 => sysclk_n,
      clock_gen_debug          => clock_gen_debug,
      mmcm0_100MHZ_CLK_debug   => mmcm0_100mhz_clk_debug,
      ep_62p5MHZ_CLK_debug     => ep_62p5mhz_clk_debug,
      sfp_tmg_los              => sfp_tmg_los,
      rx0_tmg_p                => rx0_tmg_p,
      rx0_tmg_n                => rx0_tmg_n,
      sfp_tmg_tx_dis           => sfp_tmg_tx_dis,
      tx0_tmg_p                => tx0_tmg_p,
      tx0_tmg_n                => tx0_tmg_n,
      mclk                     => open,
      clock                    => clock_o,
      clk500                   => clk500_o,
      clk125                   => clk125_o,
      sclk200                  => open,
      timestamp                => timestamp_o,
      sync                     => sync_o,
      sync_stb                 => sync_stb_o,
      F_OK_DEBUG               => f_ok_debug,
      SCTR_DEBUG               => sctr_debug,
      CCTR_DEBUG               => cctr_debug,
      mmcm0_locked_o           => timing_status_s.mmcm0_locked,
      mmcm1_locked_o           => timing_status_s.mmcm1_locked,
      endpoint_ready_o         => timing_status_s.endpoint_ready,
      endpoint_state_o         => timing_status_s.endpoint_state,
      timestamp_valid_o        => timing_status_s.timestamp_valid,
      S_AXI_ACLK               => s_axi_aclk,
      S_AXI_ARESETN            => s_axi_aresetn,
      S_AXI_AWADDR             => s_axi_awaddr,
      S_AXI_AWPROT             => s_axi_awprot,
      S_AXI_AWVALID            => s_axi_awvalid,
      S_AXI_AWREADY            => s_axi_awready,
      S_AXI_WDATA              => s_axi_wdata,
      S_AXI_WSTRB              => s_axi_wstrb,
      S_AXI_WVALID             => s_axi_wvalid,
      S_AXI_WREADY             => s_axi_wready,
      S_AXI_BRESP              => s_axi_bresp,
      S_AXI_BVALID             => s_axi_bvalid,
      S_AXI_BREADY             => s_axi_bready,
      S_AXI_ARADDR             => s_axi_araddr,
      S_AXI_ARPROT             => s_axi_arprot,
      S_AXI_ARVALID            => s_axi_arvalid,
      S_AXI_ARREADY            => s_axi_arready,
      S_AXI_RDATA              => s_axi_rdata,
      S_AXI_RRESP              => s_axi_rresp,
      S_AXI_RVALID             => s_axi_rvalid,
      S_AXI_RREADY             => s_axi_rready
    );

  timing_stat_o <= timing_status_s;
end architecture rtl;
