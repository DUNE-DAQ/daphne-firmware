library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;

entity legacy_frontend_plane_bridge is
  port (
    afe0_p : in  std_logic_vector(8 downto 0);
    afe0_n : in  std_logic_vector(8 downto 0);
    afe1_p : in  std_logic_vector(8 downto 0);
    afe1_n : in  std_logic_vector(8 downto 0);
    afe2_p : in  std_logic_vector(8 downto 0);
    afe2_n : in  std_logic_vector(8 downto 0);
    afe3_p : in  std_logic_vector(8 downto 0);
    afe3_n : in  std_logic_vector(8 downto 0);
    afe4_p : in  std_logic_vector(8 downto 0);
    afe4_n : in  std_logic_vector(8 downto 0);
    afe_clk_p : out std_logic;
    afe_clk_n : out std_logic;
    clock_i : in  std_logic;
    clk125_i : in  std_logic;
    clk500_i : in  std_logic;
    trig_in_i : in  std_logic;
    frontend_dout_o : out array_5x9x16_type;
    frontend_trigger_o : out std_logic;
    din_debug_o : out std_logic_vector(13 downto 0);
    s_axi_aclk : in  std_logic;
    s_axi_aresetn : in  std_logic;
    s_axi_awaddr : in  std_logic_vector(31 downto 0);
    s_axi_awprot : in  std_logic_vector(2 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata : in  std_logic_vector(31 downto 0);
    s_axi_wstrb : in  std_logic_vector(3 downto 0);
    s_axi_wvalid : in  std_logic;
    s_axi_wready : out std_logic;
    s_axi_bresp : out std_logic_vector(1 downto 0);
    s_axi_bvalid : out std_logic;
    s_axi_bready : in  std_logic;
    s_axi_araddr : in  std_logic_vector(31 downto 0);
    s_axi_arprot : in  std_logic_vector(2 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata : out std_logic_vector(31 downto 0);
    s_axi_rresp : out std_logic_vector(1 downto 0);
    s_axi_rvalid : out std_logic;
    s_axi_rready : in  std_logic
  );
end entity legacy_frontend_plane_bridge;

architecture rtl of legacy_frontend_plane_bridge is
  signal afe_p_array_s : array_5x9_type;
  signal afe_n_array_s : array_5x9_type;
  signal frontend_dout_s : array_5x9x16_type;
  signal din_debug_lanes_s : array_5x8x14_type;
begin
  afe_p_array_s(0)(8 downto 0) <= afe0_p;
  afe_p_array_s(1)(8 downto 0) <= afe1_p;
  afe_p_array_s(2)(8 downto 0) <= afe2_p;
  afe_p_array_s(3)(8 downto 0) <= afe3_p;
  afe_p_array_s(4)(8 downto 0) <= afe4_p;

  afe_n_array_s(0)(8 downto 0) <= afe0_n;
  afe_n_array_s(1)(8 downto 0) <= afe1_n;
  afe_n_array_s(2)(8 downto 0) <= afe2_n;
  afe_n_array_s(3)(8 downto 0) <= afe3_n;
  afe_n_array_s(4)(8 downto 0) <= afe4_n;

  frontend_dout_o <= frontend_dout_s;
  din_debug_o <= din_debug_lanes_s(1)(0);

  gen_debug_lanes : for a in 4 downto 0 generate
    gen_debug_channels : for c in 7 downto 0 generate
      din_debug_lanes_s(a)(c)(13 downto 0) <= frontend_dout_s(a)(c)(15 downto 2);
    end generate gen_debug_channels;
  end generate gen_debug_lanes;

  frontend_island_inst : entity work.frontend_island
    generic map (
      AFE_COUNT_G => 5
    )
    port map (
      afe_p         => afe_p_array_s,
      afe_n         => afe_n_array_s,
      afe_clk_p     => afe_clk_p,
      afe_clk_n     => afe_clk_n,
      clk500        => clk500_i,
      clk125        => clk125_i,
      clock         => clock_i,
      dout          => frontend_dout_s,
      trig          => frontend_trigger_o,
      trig_IN       => trig_in_i,
      S_AXI_ACLK    => s_axi_aclk,
      S_AXI_ARESETN => s_axi_aresetn,
      S_AXI_AWADDR  => s_axi_awaddr,
      S_AXI_AWPROT  => s_axi_awprot,
      S_AXI_AWVALID => s_axi_awvalid,
      S_AXI_AWREADY => s_axi_awready,
      S_AXI_WDATA   => s_axi_wdata,
      S_AXI_WSTRB   => s_axi_wstrb,
      S_AXI_WVALID  => s_axi_wvalid,
      S_AXI_WREADY  => s_axi_wready,
      S_AXI_BRESP   => s_axi_bresp,
      S_AXI_BVALID  => s_axi_bvalid,
      S_AXI_BREADY  => s_axi_bready,
      S_AXI_ARADDR  => s_axi_araddr,
      S_AXI_ARPROT  => s_axi_arprot,
      S_AXI_ARVALID => s_axi_arvalid,
      S_AXI_ARREADY => s_axi_arready,
      S_AXI_RDATA   => s_axi_rdata,
      S_AXI_RRESP   => s_axi_rresp,
      S_AXI_RVALID  => s_axi_rvalid,
      S_AXI_RREADY  => s_axi_rready
    );
end architecture rtl;
