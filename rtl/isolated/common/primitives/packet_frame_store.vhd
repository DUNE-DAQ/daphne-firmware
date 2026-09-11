library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library xpm;
use xpm.vcomponents.all;

-- One URAM per channel. Thirty-two reserved 128-word slots hold 120-word
-- records; payload can be written before its header without publication.
-- The caller supplies a one-word look-ahead address for the FWFT reader.
entity packet_frame_store is
  port (
    clock_i : in std_logic;
    wr_en_i : in std_logic;
    wr_addr_i : in unsigned(11 downto 0);
    din_i : in std_logic_vector(71 downto 0);
    rd_addr_i : in unsigned(11 downto 0);
    dout_o : out std_logic_vector(71 downto 0)
  );
end entity;
architecture rtl of packet_frame_store is
  signal wr_en_s : std_logic_vector(0 downto 0);
begin
  wr_en_s(0) <= wr_en_i;
  ram_inst : xpm_memory_sdpram
    generic map (
      ADDR_WIDTH_A => 12, ADDR_WIDTH_B => 12, AUTO_SLEEP_TIME => 0,
      BYTE_WRITE_WIDTH_A => 72, CASCADE_HEIGHT => 0, CLOCKING_MODE => "common_clock",
      ECC_MODE => "no_ecc", MEMORY_INIT_FILE => "none", MEMORY_INIT_PARAM => "0",
      MEMORY_OPTIMIZATION => "true", MEMORY_PRIMITIVE => "ultra", MEMORY_SIZE => 4096*72,
      MESSAGE_CONTROL => 0, READ_DATA_WIDTH_B => 72, READ_LATENCY_B => 1,
      READ_RESET_VALUE_B => "0", RST_MODE_A => "SYNC", RST_MODE_B => "SYNC",
      SIM_ASSERT_CHK => 0, USE_EMBEDDED_CONSTRAINT => 0, USE_MEM_INIT => 0,
      WAKEUP_TIME => "disable_sleep", WRITE_DATA_WIDTH_A => 72, WRITE_MODE_B => "read_first")
    port map (
      addra => std_logic_vector(wr_addr_i), addrb => std_logic_vector(rd_addr_i),
      clka => clock_i, clkb => clock_i, dbiterrb => open, dina => din_i, doutb => dout_o,
      ena => '1', enb => '1', injectdbiterra => '0', injectsbiterra => '0', regceb => '1',
      rstb => '0', sbiterrb => open, sleep => '0', wea => wr_en_s);
end architecture;
