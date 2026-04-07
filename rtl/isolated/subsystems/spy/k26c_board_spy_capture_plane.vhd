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
  signal spy_trigger_s : std_logic;
begin
  spy_trigger_plane_inst : entity work.k26c_board_spy_trigger_plane
    port map (
      clock_i            => clock_i,
      reset_i            => reset_i,
      frontend_trigger_i => frontend_trigger_i,
      adhoc_i            => adhoc_i,
      ti_trigger_i       => ti_trigger_i,
      ti_trigger_stbr_i  => ti_trigger_stbr_i,
      spy_trigger_o      => spy_trigger_s
    );

  spy_buffer_plane_inst : entity work.k26c_board_spy_buffer_plane
    port map (
      clock_i       => clock_i,
      reset_i       => reset_i,
      spy_trigger_i => spy_trigger_s,
      afe_dout_i    => afe_dout_i,
      timestamp_i   => timestamp_i,
      s_axi_aclk    => s_axi_aclk,
      s_axi_aresetn => s_axi_aresetn,
      s_axi_awaddr  => s_axi_awaddr,
      s_axi_awprot  => s_axi_awprot,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => s_axi_wstrb,
      s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,
      s_axi_bresp   => s_axi_bresp,
      s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,
      s_axi_araddr  => s_axi_araddr,
      s_axi_arprot  => s_axi_arprot,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata   => s_axi_rdata,
      s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,
      s_axi_rready  => s_axi_rready
    );
end architecture rtl;
