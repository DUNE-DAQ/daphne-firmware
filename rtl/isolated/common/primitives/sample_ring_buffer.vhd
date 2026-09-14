library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library xpm;
use xpm.vcomponents.all;

-- Two parity banks provide consecutive samples at any starting alignment.
-- 2048 x 14 logical samples map to two 1024 x 14 RAMB18 banks.
entity sample_ring_buffer is
  generic (DATA_WIDTH_G : positive := 14; DEPTH_G : positive := 2048; ADDR_WIDTH_G : positive := 11);
  port (
    clock_i : in std_logic; wr_en_i : in std_logic;
    wr_addr_i : in unsigned(ADDR_WIDTH_G-1 downto 0);
    din_i : in std_logic_vector(DATA_WIDTH_G-1 downto 0);
    rd_addr_i : in unsigned(ADDR_WIDTH_G-1 downto 0);
    dout_o : out std_logic_vector(DATA_WIDTH_G-1 downto 0);
    dout_next_o : out std_logic_vector(DATA_WIDTH_G-1 downto 0)
  );
end entity;
architecture rtl of sample_ring_buffer is
  type data_array_t is array(0 to 1) of std_logic_vector(DATA_WIDTH_G-1 downto 0);
  signal bank_data_s : data_array_t;
  signal read_odd_s : std_logic := '0';
begin
  assert DEPTH_G = 2**ADDR_WIDTH_G severity failure;
  process(clock_i) begin
    if rising_edge(clock_i) then read_odd_s <= rd_addr_i(0); end if;
  end process;
  gen_bank : for bank in 0 to 1 generate
    signal wr_en_s : std_logic_vector(0 downto 0);
    signal rd_addr_s : unsigned(ADDR_WIDTH_G-2 downto 0);
  begin
    wr_en_s(0) <= wr_en_i when to_integer(wr_addr_i(0 downto 0)) = bank else '0';
    rd_addr_s <= rd_addr_i(ADDR_WIDTH_G-1 downto 1) + 1 when bank = 0 and rd_addr_i(0) = '1'
                 else rd_addr_i(ADDR_WIDTH_G-1 downto 1);
    ram_inst : xpm_memory_sdpram
      generic map (
        ADDR_WIDTH_A => ADDR_WIDTH_G-1, ADDR_WIDTH_B => ADDR_WIDTH_G-1,
        AUTO_SLEEP_TIME => 0, BYTE_WRITE_WIDTH_A => DATA_WIDTH_G, CASCADE_HEIGHT => 0,
        CLOCKING_MODE => "common_clock", ECC_MODE => "no_ecc", MEMORY_INIT_FILE => "none",
        MEMORY_INIT_PARAM => "0", MEMORY_OPTIMIZATION => "true", MEMORY_PRIMITIVE => "block",
        MEMORY_SIZE => DATA_WIDTH_G*DEPTH_G/2, MESSAGE_CONTROL => 0,
        READ_DATA_WIDTH_B => DATA_WIDTH_G, READ_LATENCY_B => 1, READ_RESET_VALUE_B => "0",
        RST_MODE_A => "SYNC", RST_MODE_B => "SYNC", SIM_ASSERT_CHK => 0,
        USE_EMBEDDED_CONSTRAINT => 0, USE_MEM_INIT => 0, WAKEUP_TIME => "disable_sleep",
        WRITE_DATA_WIDTH_A => DATA_WIDTH_G, WRITE_MODE_B => "read_first")
      port map (
        addra => std_logic_vector(wr_addr_i(ADDR_WIDTH_G-1 downto 1)), addrb => std_logic_vector(rd_addr_s),
        clka => clock_i, clkb => clock_i, dbiterrb => open, dina => din_i, doutb => bank_data_s(bank),
        ena => '1', enb => '1', injectdbiterra => '0', injectsbiterra => '0', regceb => '1',
        rstb => '0', sbiterrb => open, sleep => '0', wea => wr_en_s);
  end generate;
  dout_o <= bank_data_s(0) when read_odd_s = '0' else bank_data_s(1);
  dout_next_o <= bank_data_s(1) when read_odd_s = '0' else bank_data_s(0);
end architecture;
