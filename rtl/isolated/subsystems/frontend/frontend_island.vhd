library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;

entity frontend_island is
  generic (
    AFE_COUNT_G : positive range 1 to 5 := 5
  );
  port (
    afe_p          : in  array_5x9_type;
    afe_n          : in  array_5x9_type;
    afe_clk_p      : out std_logic;
    afe_clk_n      : out std_logic;
    clk500         : in  std_logic;
    clk125         : in  std_logic;
    clock          : in  std_logic;
    dout           : out array_5x9x16_type;
    trig           : out std_logic;
    software_trig  : out std_logic;
    external_trig  : out std_logic;
    spy_trigger_source  : out std_logic_vector(1 downto 0);
    spy_trigger_inhibit : out std_logic;
    trig_IN        : in  std_logic;
    S_AXI_ACLK     : in  std_logic;
    S_AXI_ARESETN  : in  std_logic;
    S_AXI_AWADDR   : in  std_logic_vector(31 downto 0);
    S_AXI_AWPROT   : in  std_logic_vector(2 downto 0);
    S_AXI_AWVALID  : in  std_logic;
    S_AXI_AWREADY  : out std_logic;
    S_AXI_WDATA    : in  std_logic_vector(31 downto 0);
    S_AXI_WSTRB    : in  std_logic_vector(3 downto 0);
    S_AXI_WVALID   : in  std_logic;
    S_AXI_WREADY   : out std_logic;
    S_AXI_BRESP    : out std_logic_vector(1 downto 0);
    S_AXI_BVALID   : out std_logic;
    S_AXI_BREADY   : in  std_logic;
    S_AXI_ARADDR   : in  std_logic_vector(31 downto 0);
    S_AXI_ARPROT   : in  std_logic_vector(2 downto 0);
    S_AXI_ARVALID  : in  std_logic;
    S_AXI_ARREADY  : out std_logic;
    S_AXI_RDATA    : out std_logic_vector(31 downto 0);
    S_AXI_RRESP    : out std_logic_vector(1 downto 0);
    S_AXI_RVALID   : out std_logic;
    S_AXI_RREADY   : in  std_logic
  );
end entity frontend_island;

architecture rtl of frontend_island is
  signal idelayctrl_ready    : std_logic;
  signal idelayctrl_reset    : std_logic;
  signal idelay_tap          : array_5x9_type;
  signal idelay_load         : std_logic_vector(4 downto 0);
  signal idelay_load_clk125  : std_logic_vector(4 downto 0);
  signal idelay_en_vtc       : std_logic;
  signal iserdes_bitslip     : array_5x4_type;
  signal iserdes_reset       : std_logic;
  signal software_trig_axi        : std_logic;
  signal external_trig_axi        : std_logic;
  signal spy_trigger_source_axi   : std_logic_vector(1 downto 0);
  signal spy_trigger_inhibit_axi  : std_logic;
begin
  frontend_common_inst : entity work.frontend_common
    port map (
      afe_clk_p_o          => afe_clk_p,
      afe_clk_n_o          => afe_clk_n,
      clk500_i             => clk500,
      clk125_i             => clk125,
      clock_i              => clock,
      idelayctrl_reset_i   => idelayctrl_reset,
      idelayctrl_ready_o   => idelayctrl_ready,
      idelay_load_i             => idelay_load,
      idelay_load_clk125_o      => idelay_load_clk125,
      software_trig_axi_i       => software_trig_axi,
      external_trig_axi_i       => external_trig_axi,
      spy_trigger_source_axi_i  => spy_trigger_source_axi,
      spy_trigger_inhibit_axi_i => spy_trigger_inhibit_axi,
      software_trig_o           => software_trig,
      external_trig_o           => external_trig,
      spy_trigger_source_o      => spy_trigger_source,
      spy_trigger_inhibit_o     => spy_trigger_inhibit,
      trig_o                    => trig
    );

  capture_bank_inst : entity work.frontend_capture_bank
    generic map (
      AFE_COUNT_G => AFE_COUNT_G
    )
    port map (
      afe_p_i           => afe_p,
      afe_n_i           => afe_n,
      clk500_i          => clk500,
      clk125_i          => clk125,
      clock_i           => clock,
      idelay_load_i     => idelay_load_clk125,
      idelay_tap_i      => idelay_tap,
      idelay_en_vtc_i   => idelay_en_vtc,
      iserdes_reset_i   => iserdes_reset,
      iserdes_bitslip_i => iserdes_bitslip,
      dout_o            => dout
    );

  fe_axi_inst : entity work.fe_axi
    port map (
      S_AXI_ACLK       => S_AXI_ACLK,
      S_AXI_ARESETN    => S_AXI_ARESETN,
      S_AXI_AWADDR     => S_AXI_AWADDR,
      S_AXI_AWPROT     => S_AXI_AWPROT,
      S_AXI_AWVALID    => S_AXI_AWVALID,
      S_AXI_AWREADY    => S_AXI_AWREADY,
      S_AXI_WDATA      => S_AXI_WDATA,
      S_AXI_WSTRB      => S_AXI_WSTRB,
      S_AXI_WVALID     => S_AXI_WVALID,
      S_AXI_WREADY     => S_AXI_WREADY,
      S_AXI_BRESP      => S_AXI_BRESP,
      S_AXI_BVALID     => S_AXI_BVALID,
      S_AXI_BREADY     => S_AXI_BREADY,
      S_AXI_ARADDR     => S_AXI_ARADDR,
      S_AXI_ARPROT     => S_AXI_ARPROT,
      S_AXI_ARVALID    => S_AXI_ARVALID,
      S_AXI_ARREADY    => S_AXI_ARREADY,
      S_AXI_RDATA      => S_AXI_RDATA,
      S_AXI_RRESP      => S_AXI_RRESP,
      S_AXI_RVALID     => S_AXI_RVALID,
      S_AXI_RREADY     => S_AXI_RREADY,
      trig_IN          => trig_IN,
      idelayctrl_ready => idelayctrl_ready,
      idelayctrl_reset => idelayctrl_reset,
      idelay_tap       => idelay_tap,
      idelay_en_vtc       => idelay_en_vtc,
      idelay_load         => idelay_load,
      iserdes_bitslip     => iserdes_bitslip,
      iserdes_reset       => iserdes_reset,
      trig                => open,
      software_trig       => software_trig_axi,
      external_trig       => external_trig_axi,
      spy_trigger_source  => spy_trigger_source_axi,
      spy_trigger_inhibit => spy_trigger_inhibit_axi
    );
end architecture rtl;
