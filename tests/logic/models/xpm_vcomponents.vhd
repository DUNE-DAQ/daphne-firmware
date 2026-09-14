library ieee;
use ieee.std_logic_1164.all;

package vcomponents is
  component xpm_memory_sdpram is
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
  end component;
component xpm_cdc_array_single is
  generic(DEST_SYNC_FF:integer:=4; INIT_SYNC_FF:integer:=0; SIM_ASSERT_CHK:integer:=0;
    SRC_INPUT_REG:integer:=1; WIDTH:integer:=2);
  port(src_clk:in std_logic; src_in:in std_logic_vector(WIDTH-1 downto 0);
    dest_clk:in std_logic; dest_out:out std_logic_vector(WIDTH-1 downto 0));
end component;
component xpm_cdc_handshake is
  generic(DEST_EXT_HSK:integer:=1; DEST_SYNC_FF:integer:=2; INIT_SYNC_FF:integer:=1;
    SIM_ASSERT_CHK:integer:=1; SRC_SYNC_FF:integer:=2; WIDTH:integer:=1);
  port(src_clk:in std_logic; src_in:in std_logic_vector(WIDTH-1 downto 0);
    src_send:in std_logic; src_rcv:out std_logic; dest_clk:in std_logic;
    dest_out:out std_logic_vector(WIDTH-1 downto 0); dest_req:out std_logic; dest_ack:in std_logic);
end component;
component xpm_fifo_async is
  generic(CDC_SYNC_STAGES:integer:=2; DOUT_RESET_VALUE:string:="0"; ECC_MODE:string:="no_ecc";
    FIFO_MEMORY_TYPE:string:="block"; FIFO_READ_LATENCY:integer:=0; FIFO_WRITE_DEPTH:integer:=512;
    FULL_RESET_VALUE:integer:=0; PROG_EMPTY_THRESH:integer:=10; PROG_FULL_THRESH:integer:=385;
    RD_DATA_COUNT_WIDTH:integer:=10; READ_DATA_WIDTH:integer:=88; READ_MODE:string:="fwft";
    RELATED_CLOCKS:integer:=0; SIM_ASSERT_CHK:integer:=1; USE_ADV_FEATURES:string:="0004";
    WAKEUP_TIME:integer:=0; WRITE_DATA_WIDTH:integer:=88; WR_DATA_COUNT_WIDTH:integer:=10);
  port(rst,wr_clk,wr_en:in std_logic; din:in std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
    full,wr_ack,overflow,prog_full:out std_logic; wr_data_count:out std_logic_vector(WR_DATA_COUNT_WIDTH-1 downto 0);
    almost_full,wr_rst_busy:out std_logic; rd_clk,rd_en:in std_logic;
    dout:out std_logic_vector(READ_DATA_WIDTH-1 downto 0);
    empty,underflow,prog_empty:out std_logic; rd_data_count:out std_logic_vector(RD_DATA_COUNT_WIDTH-1 downto 0);
    almost_empty,data_valid,rd_rst_busy:out std_logic;
    sleep,injectsbiterr,injectdbiterr:in std_logic; sbiterr,dbiterr:out std_logic);
end component;
end package vcomponents;

package body vcomponents is
end package body vcomponents;
