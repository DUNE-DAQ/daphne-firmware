-- Behavioral test model derived from daphne_mezz_xc_sim at36073b1.
-- Equal-width, common/independent-clock, single-cycle read subset only. This model is
-- independent of synthesis mapping; vendor XPM simulation is also required.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity xpm_memory_sdpram is
  generic (
    ADDR_WIDTH_A            : integer := 6;
    ADDR_WIDTH_B            : integer := 6;
    AUTO_SLEEP_TIME         : integer := 0;
    BYTE_WRITE_WIDTH_A      : integer := 32;
    CASCADE_HEIGHT          : integer := 0;
    CLOCKING_MODE           : string  := "common_clock";
    ECC_MODE                : string  := "no_ecc";
    MEMORY_INIT_FILE        : string  := "none";
    MEMORY_INIT_PARAM       : string  := "0";
    MEMORY_OPTIMIZATION     : string  := "true";
    MEMORY_PRIMITIVE        : string  := "auto";
    MEMORY_SIZE             : integer := 2048;
    MESSAGE_CONTROL         : integer := 0;
    READ_DATA_WIDTH_B       : integer := 32;
    READ_LATENCY_B          : integer := 1;
    READ_RESET_VALUE_B      : string  := "0";
    RST_MODE_A              : string  := "SYNC";
    RST_MODE_B              : string  := "SYNC";
    SIM_ASSERT_CHK          : integer := 0;
    USE_EMBEDDED_CONSTRAINT : integer := 0;
    USE_MEM_INIT            : integer := 0;
    WAKEUP_TIME             : string  := "disable_sleep";
    WRITE_DATA_WIDTH_A      : integer := 32;
    WRITE_MODE_B            : string  := "no_change"
  );
  port (
    addra           : in  std_logic_vector(ADDR_WIDTH_A - 1 downto 0);
    addrb           : in  std_logic_vector(ADDR_WIDTH_B - 1 downto 0);
    clka            : in  std_logic;
    clkb            : in  std_logic;
    dbiterrb        : out std_logic;
    dina            : in  std_logic_vector(WRITE_DATA_WIDTH_A - 1 downto 0);
    doutb           : out std_logic_vector(READ_DATA_WIDTH_B - 1 downto 0);
    ena             : in  std_logic;
    enb             : in  std_logic;
    injectdbiterra  : in  std_logic;
    injectsbiterra  : in  std_logic;
    regceb          : in  std_logic;
    rstb            : in  std_logic;
    sbiterrb        : out std_logic;
    sleep           : in  std_logic;
    wea             : in  std_logic_vector((WRITE_DATA_WIDTH_A / BYTE_WRITE_WIDTH_A) - 1 downto 0)
  );
end entity xpm_memory_sdpram;

architecture sim of xpm_memory_sdpram is
  constant DEPTH_C : natural := MEMORY_SIZE / WRITE_DATA_WIDTH_A;
  type mem_t is array (0 to DEPTH_C - 1) of std_logic_vector(WRITE_DATA_WIDTH_A - 1 downto 0);
  signal mem_s     : mem_t := (others => (others => '0'));
  signal dout_s    : std_logic_vector(READ_DATA_WIDTH_B - 1 downto 0) := (others => '0');
begin
  assert READ_DATA_WIDTH_B=WRITE_DATA_WIDTH_A and READ_LATENCY_B=1
    report "test model requires equal widths and one read clock" severity failure;
  assert (CLOCKING_MODE="common_clock" or CLOCKING_MODE="independent_clock") and BYTE_WRITE_WIDTH_A=WRITE_DATA_WIDTH_A
    report "test model requires full-word writes" severity failure;
  process (clka)
    variable wr_idx_v : natural range 0 to DEPTH_C - 1;
    variable rd_idx_v : natural range 0 to DEPTH_C - 1;
  begin
    if rising_edge(clka) then
      wr_idx_v := to_integer(unsigned(addra));
      rd_idx_v := to_integer(unsigned(addrb));

      -- Port A writes are independent of port B read enable/reset.
      if sleep='0' and ena='1' and wea /= (wea'range => '0') then
        mem_s(wr_idx_v) <= dina;
      end if;
    end if;
  end process;
  process(clka,clkb)
    variable rd_idx_v : natural range 0 to DEPTH_C-1;
  begin
    if (CLOCKING_MODE="common_clock" and rising_edge(clka)) or
       (CLOCKING_MODE="independent_clock" and rising_edge(clkb)) then
      rd_idx_v:=to_integer(unsigned(addrb));
      if rstb='1' then dout_s<=(others=>'0');
      elsif sleep='0' and enb='1' and regceb='1' then dout_s<=mem_s(rd_idx_v); end if;
    end if;
  end process;

  doutb    <= dout_s;
  dbiterrb <= '0';
  sbiterrb <= '0';
end architecture sim;
