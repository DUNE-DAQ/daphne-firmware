library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity k26c_board_spy_capture_plane is
  port (
    clock_i            : in  std_logic;
    reset_i            : in  std_logic;
    frontend_trigger_i : in  std_logic;
    afe_dout_i         : in  array_5x9x16_type;
    timestamp_i        : in  std_logic_vector(63 downto 0);
    adhoc_i            : in  std_logic_vector(7 downto 0);
    ti_trigger_i       : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr_i  : in  std_logic;
    s_axi_aclk         : in  std_logic;
    s_axi_aresetn      : in  std_logic;
    s_axi_awaddr       : in  std_logic_vector(31 downto 0);
    s_axi_awprot       : in  std_logic_vector(2 downto 0);
    s_axi_awvalid      : in  std_logic;
    s_axi_awready      : out std_logic;
    s_axi_wdata        : in  std_logic_vector(31 downto 0);
    s_axi_wstrb        : in  std_logic_vector(3 downto 0);
    s_axi_wvalid       : in  std_logic;
    s_axi_wready       : out std_logic;
    s_axi_bresp        : out std_logic_vector(1 downto 0);
    s_axi_bvalid       : out std_logic;
    s_axi_bready       : in  std_logic;
    s_axi_araddr       : in  std_logic_vector(31 downto 0);
    s_axi_arprot       : in  std_logic_vector(2 downto 0);
    s_axi_arvalid      : in  std_logic;
    s_axi_arready      : out std_logic;
    s_axi_rdata        : out std_logic_vector(31 downto 0);
    s_axi_rresp        : out std_logic_vector(1 downto 0);
    s_axi_rvalid       : out std_logic;
    s_axi_rready       : in  std_logic
  );
end entity k26c_board_spy_capture_plane;

architecture rtl of k26c_board_spy_capture_plane is
  signal spy_trigger_s    : std_logic;
  signal ti_trigger_en_s  : std_logic;
  signal ti_trigger_en0_s : std_logic := '0';
  signal ti_trigger_en1_s : std_logic := '0';
  signal ti_trigger_en2_s : std_logic := '0';
  signal timing_trigger_s : std_logic;
  signal readiness_s      : acquisition_readiness_t :=
    (config_ready => '1', timing_ready => '1', alignment_ready => '1');
begin
  ti_trigger_en_s <= '1' when (ti_trigger_i = adhoc_i and ti_trigger_stbr_i = '1') else '0';

  trigger_sync_proc : process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        ti_trigger_en0_s <= '0';
        ti_trigger_en1_s <= '0';
        ti_trigger_en2_s <= '0';
      else
        ti_trigger_en0_s <= ti_trigger_en_s;
        ti_trigger_en1_s <= ti_trigger_en0_s;
        ti_trigger_en2_s <= ti_trigger_en1_s;
      end if;
    end if;
  end process trigger_sync_proc;

  timing_trigger_s <= ti_trigger_en0_s or ti_trigger_en1_s or ti_trigger_en2_s;
  spy_trigger_s    <= frontend_trigger_i or timing_trigger_s;

  spy_boundary_inst : entity work.spy_buffer_boundary
    port map (
      clk          => clock_i,
      reset        => reset_i,
      readiness_i  => readiness_s,
      spy_enable_o => open
    );

  spybuffers_inst : entity work.spybuffers
    port map (
      clock         => clock_i,
      trig          => spy_trigger_s,
      din           => afe_dout_i,
      timestamp     => timestamp_i,
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
