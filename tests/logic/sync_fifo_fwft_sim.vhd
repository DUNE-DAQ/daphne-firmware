library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simulation-only model for the XPM-backed FIFO used by the record builder.
-- The production target continues to compile sync_fifo_fwft.vhd and infer
-- UltraRAM through Xilinx XPM. This small model keeps the logic smoke test
-- independent of the proprietary XPM simulation library.
entity sync_fifo_fwft is
  generic (
    DATA_WIDTH_G        : positive := 72;
    DEPTH_G             : positive := 4096;
    COUNT_WIDTH_G       : positive := 13;
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

architecture sim of sync_fifo_fwft is
  type memory_t is array (0 to DEPTH_G - 1) of
    std_logic_vector(DATA_WIDTH_G - 1 downto 0);
  signal memory_s  : memory_t := (others => (others => '0'));
  signal rd_addr_s : natural range 0 to DEPTH_G - 1 := 0;
  signal wr_addr_s : natural range 0 to DEPTH_G - 1 := 0;
  signal count_s   : natural range 0 to DEPTH_G := 0;
begin
  fifo_proc : process(clock_i)
    variable write_v : boolean;
    variable read_v  : boolean;
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        rd_addr_s <= 0;
        wr_addr_s <= 0;
        count_s   <= 0;
      elsif sleep_i = '0' then
        write_v := wr_en_i = '1' and count_s < DEPTH_G;
        read_v  := rd_en_i = '1' and count_s > 0;

        if write_v then
          memory_s(wr_addr_s) <= din_i;
          if wr_addr_s = DEPTH_G - 1 then
            wr_addr_s <= 0;
          else
            wr_addr_s <= wr_addr_s + 1;
          end if;
        end if;

        if read_v then
          if rd_addr_s = DEPTH_G - 1 then
            rd_addr_s <= 0;
          else
            rd_addr_s <= rd_addr_s + 1;
          end if;
        end if;

        if write_v and not read_v then
          count_s <= count_s + 1;
        elsif read_v and not write_v then
          count_s <= count_s - 1;
        end if;
      end if;
    end if;
  end process fifo_proc;

  dout_o <= memory_s(rd_addr_s) when count_s > 0 else (others => '0');
  prog_empty_o <= '1' when count_s <= PROG_EMPTY_THRESH_G else '0';
  prog_full_o <= '1' when count_s >= PROG_FULL_THRESH_G else '0';
  wr_data_count_o <= std_logic_vector(to_unsigned(count_s, COUNT_WIDTH_G));
end architecture sim;
