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
begin
  afe_clk_p <= clock;
  afe_clk_n <= not clock;
  trig      <= trig_IN;

  S_AXI_AWREADY <= '0';
  S_AXI_WREADY  <= '0';
  S_AXI_BRESP   <= (others => '0');
  S_AXI_BVALID  <= '0';
  S_AXI_ARREADY <= '0';
  S_AXI_RDATA   <= (others => '0');
  S_AXI_RRESP   <= (others => '0');
  S_AXI_RVALID  <= '0';

  gen_afe : for afe in 4 downto 0 generate
    active_afe_gen : if afe < AFE_COUNT_G generate
      gen_lane : for lane in 8 downto 0 generate
      begin
        dout(afe)(lane)(15 downto 1) <= (others => afe_p(afe)(lane));
        dout(afe)(lane)(0)            <= afe_n(afe)(lane);
      end generate gen_lane;
    end generate active_afe_gen;

    inactive_afe_gen : if afe >= AFE_COUNT_G generate
      dout(afe) <= (others => (others => '0'));
    end generate inactive_afe_gen;
  end generate gen_afe;
end architecture rtl;
