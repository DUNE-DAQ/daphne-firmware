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
begin
  timing_subsystem_inst : entity work.legacy_timing_subsystem_bridge
    port map (
      sysclk_p                 => sysclk_p,
      sysclk_n                 => sysclk_n,
      sfp_tmg_los              => sfp_tmg_los,
      rx0_tmg_p                => rx0_tmg_p,
      rx0_tmg_n                => rx0_tmg_n,
      sfp_tmg_tx_dis           => sfp_tmg_tx_dis,
      tx0_tmg_p                => tx0_tmg_p,
      tx0_tmg_n                => tx0_tmg_n,
      clock_gen_debug_o        => clock_gen_debug,
      mmcm0_100mhz_clk_debug_o => mmcm0_100mhz_clk_debug,
      ep_62p5mhz_clk_debug_o   => ep_62p5mhz_clk_debug,
      f_ok_debug_o             => f_ok_debug,
      sctr_debug_o             => sctr_debug,
      cctr_debug_o             => cctr_debug,
      mclk_o                   => open,
      clock_o                  => clock_o,
      clk500_o                 => clk500_o,
      clk125_o                 => clk125_o,
      sclk200_o                => open,
      timestamp_o              => timestamp_o,
      sync_o                   => sync_o,
      sync_stb_o               => sync_stb_o,
      timing_stat_o            => timing_stat_o,
      s_axi_aclk               => s_axi_aclk,
      s_axi_aresetn            => s_axi_aresetn,
      s_axi_awaddr             => s_axi_awaddr,
      s_axi_awprot             => s_axi_awprot,
      s_axi_awvalid            => s_axi_awvalid,
      s_axi_awready            => s_axi_awready,
      s_axi_wdata              => s_axi_wdata,
      s_axi_wstrb              => s_axi_wstrb,
      s_axi_wvalid             => s_axi_wvalid,
      s_axi_wready             => s_axi_wready,
      s_axi_bresp              => s_axi_bresp,
      s_axi_bvalid             => s_axi_bvalid,
      s_axi_bready             => s_axi_bready,
      s_axi_araddr             => s_axi_araddr,
      s_axi_arprot             => s_axi_arprot,
      s_axi_arvalid            => s_axi_arvalid,
      s_axi_arready            => s_axi_arready,
      s_axi_rdata              => s_axi_rdata,
      s_axi_rresp              => s_axi_rresp,
      s_axi_rvalid             => s_axi_rvalid,
      s_axi_rready             => s_axi_rready
    );
end architecture rtl;
