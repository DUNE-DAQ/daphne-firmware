library ieee;
use ieee.std_logic_1164.all;

entity legacy_board_control_bridge is
port(
    fan_tach: in std_logic_vector(1 downto 0);
    fan_ctrl: out std_logic;
    hvbias_en: out std_logic;
    mux_en: out std_logic_vector(1 downto 0);
    mux_a: out std_logic_vector(1 downto 0);
    stat_led: out std_logic_vector(5 downto 0);
    version: in std_logic_vector(27 downto 0);
    adhoc: out std_logic_vector(7 downto 0);
    core_chan_enable: out std_logic_vector(39 downto 0);
    filter_output_selector: out std_logic_vector(1 downto 0);
    afe_comp_enable: out std_logic_vector(39 downto 0);
    invert_enable: out std_logic_vector(39 downto 0);
    st_config: out std_logic_vector(13 downto 0);
    signal_delay: out std_logic_vector(4 downto 0);
    reset_st_counters: out std_logic;

    stuff_s_axi_aclk: in std_logic;
    stuff_s_axi_aresetn: in std_logic;
    stuff_s_axi_awaddr: in std_logic_vector(31 downto 0);
    stuff_s_axi_awprot: in std_logic_vector(2 downto 0);
    stuff_s_axi_awvalid: in std_logic;
    stuff_s_axi_awready: out std_logic;
    stuff_s_axi_wdata: in std_logic_vector(31 downto 0);
    stuff_s_axi_wstrb: in std_logic_vector(3 downto 0);
    stuff_s_axi_wvalid: in std_logic;
    stuff_s_axi_wready: out std_logic;
    stuff_s_axi_bresp: out std_logic_vector(1 downto 0);
    stuff_s_axi_bvalid: out std_logic;
    stuff_s_axi_bready: in std_logic;
    stuff_s_axi_araddr: in std_logic_vector(31 downto 0);
    stuff_s_axi_arprot: in std_logic_vector(2 downto 0);
    stuff_s_axi_arvalid: in std_logic;
    stuff_s_axi_arready: out std_logic;
    stuff_s_axi_rdata: out std_logic_vector(31 downto 0);
    stuff_s_axi_rresp: out std_logic_vector(1 downto 0);
    stuff_s_axi_rvalid: out std_logic;
    stuff_s_axi_rready: in std_logic
);
end entity legacy_board_control_bridge;

architecture rtl of legacy_board_control_bridge is
begin
  stuff_inst: entity work.stuff
    port map(
      fan_tach               => fan_tach,
      fan_ctrl               => fan_ctrl,
      hvbias_en              => hvbias_en,
      mux_en                 => mux_en,
      mux_a                  => mux_a,
      stat_led               => stat_led,
      version                => version,
      adhoc                  => adhoc,
      core_chan_enable       => core_chan_enable,
      filter_output_selector => filter_output_selector,
      afe_comp_enable        => afe_comp_enable,
      invert_enable          => invert_enable,
      st_config              => st_config,
      signal_delay           => signal_delay,
      reset_st_counters      => reset_st_counters,
      S_AXI_ACLK             => stuff_s_axi_aclk,
      S_AXI_ARESETN          => stuff_s_axi_aresetn,
      S_AXI_AWADDR           => stuff_s_axi_awaddr,
      S_AXI_AWPROT           => stuff_s_axi_awprot,
      S_AXI_AWVALID          => stuff_s_axi_awvalid,
      S_AXI_AWREADY          => stuff_s_axi_awready,
      S_AXI_WDATA            => stuff_s_axi_wdata,
      S_AXI_WSTRB            => stuff_s_axi_wstrb,
      S_AXI_WVALID           => stuff_s_axi_wvalid,
      S_AXI_WREADY           => stuff_s_axi_wready,
      S_AXI_BRESP            => stuff_s_axi_bresp,
      S_AXI_BVALID           => stuff_s_axi_bvalid,
      S_AXI_BREADY           => stuff_s_axi_bready,
      S_AXI_ARADDR           => stuff_s_axi_araddr,
      S_AXI_ARPROT           => stuff_s_axi_arprot,
      S_AXI_ARVALID          => stuff_s_axi_arvalid,
      S_AXI_ARREADY          => stuff_s_axi_arready,
      S_AXI_RDATA            => stuff_s_axi_rdata,
      S_AXI_RRESP            => stuff_s_axi_rresp,
      S_AXI_RVALID           => stuff_s_axi_rvalid,
      S_AXI_RREADY           => stuff_s_axi_rready
    );
end architecture rtl;
