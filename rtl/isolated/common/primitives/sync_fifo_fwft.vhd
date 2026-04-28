library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity sync_fifo_fwft is
  generic (
    DATA_WIDTH_G        : positive := 72;
    DEPTH_G             : positive := 4096;
    COUNT_WIDTH_G       : positive := 13;
    MEMORY_TYPE_G       : string   := "ultra";
    PROG_EMPTY_THRESH_G : natural  := 220;
    PROG_FULL_THRESH_G  : natural  := 200
  );
  port (
    clock_i         : in  std_logic;
    reset_i         : in  std_logic;
    sleep_i         : in  std_logic;
    wr_en_i         : in  std_logic;
    din_i           : in  std_logic_vector(DATA_WIDTH_G - 1 downto 0);
    rd_en_i         : in  std_logic;
    dout_o          : out std_logic_vector(DATA_WIDTH_G - 1 downto 0);
    prog_empty_o    : out std_logic;
    prog_full_o     : out std_logic;
    wr_data_count_o : out std_logic_vector(COUNT_WIDTH_G - 1 downto 0)
  );
end entity sync_fifo_fwft;

architecture rtl of sync_fifo_fwft is
  signal ignored_almost_empty_s : std_logic;
  signal ignored_almost_full_s  : std_logic;
  signal ignored_data_valid_s   : std_logic;
  signal ignored_dbiterr_s      : std_logic;
  signal ignored_empty_s        : std_logic;
  signal ignored_full_s         : std_logic;
  signal ignored_overflow_s     : std_logic;
  signal ignored_rd_busy_s      : std_logic;
  signal ignored_sbiterr_s      : std_logic;
  signal ignored_underflow_s    : std_logic;
  signal ignored_wr_ack_s       : std_logic;
  signal ignored_wr_busy_s      : std_logic;
begin
  -- Use the native XPM FIFO so the implementation path can choose the intended
  -- memory class explicitly. The coal-tail512 branch uses the same primitive as
  -- the legacy path, but with a much smaller per-channel staging depth and a
  -- narrower contract around it instead of relying on a deep local reservoir.
  xpm_fifo_sync_inst : xpm_fifo_sync
    generic map (
      CASCADE_HEIGHT      => 0,
      DOUT_RESET_VALUE    => "0",
      ECC_MODE            => "no_ecc",
      EN_SIM_ASSERT_ERR   => "warning",
      FIFO_MEMORY_TYPE    => MEMORY_TYPE_G,
      FIFO_READ_LATENCY   => 0,
      FIFO_WRITE_DEPTH    => DEPTH_G,
      FULL_RESET_VALUE    => 0,
      PROG_EMPTY_THRESH   => PROG_EMPTY_THRESH_G,
      PROG_FULL_THRESH    => PROG_FULL_THRESH_G,
      RD_DATA_COUNT_WIDTH => COUNT_WIDTH_G,
      READ_DATA_WIDTH     => DATA_WIDTH_G,
      READ_MODE           => "fwft",
      SIM_ASSERT_CHK      => 0,
      USE_ADV_FEATURES    => "0202",
      WAKEUP_TIME         => 0,
      WRITE_DATA_WIDTH    => DATA_WIDTH_G,
      WR_DATA_COUNT_WIDTH => COUNT_WIDTH_G
    )
    port map (
      almost_empty  => ignored_almost_empty_s,
      almost_full   => ignored_almost_full_s,
      data_valid    => ignored_data_valid_s,
      dbiterr       => ignored_dbiterr_s,
      dout          => dout_o,
      empty         => ignored_empty_s,
      full          => ignored_full_s,
      overflow      => ignored_overflow_s,
      prog_empty    => prog_empty_o,
      prog_full     => prog_full_o,
      rd_data_count => open,
      rd_rst_busy   => ignored_rd_busy_s,
      sbiterr       => ignored_sbiterr_s,
      underflow     => ignored_underflow_s,
      wr_ack        => ignored_wr_ack_s,
      wr_data_count => wr_data_count_o,
      wr_rst_busy   => ignored_wr_busy_s,
      din           => din_i,
      injectdbiterr => '0',
      injectsbiterr => '0',
      rd_en         => rd_en_i,
      rst           => reset_i,
      sleep         => sleep_i,
      wr_clk        => clock_i,
      wr_en         => wr_en_i
    );
end architecture rtl;
