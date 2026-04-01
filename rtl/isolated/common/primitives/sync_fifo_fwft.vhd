library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

architecture rtl of sync_fifo_fwft is
  type mem_t is array (0 to DEPTH_G - 1) of std_logic_vector(DATA_WIDTH_G - 1 downto 0);

  function inc_ptr(ptr : natural) return natural is
  begin
    if ptr = DEPTH_G - 1 then
      return 0;
    end if;
    return ptr + 1;
  end function inc_ptr;

  signal mem_s    : mem_t := (others => (others => '0'));
  signal rd_ptr_s : natural range 0 to DEPTH_G - 1 := 0;
  signal wr_ptr_s : natural range 0 to DEPTH_G - 1 := 0;
  signal count_s  : natural range 0 to DEPTH_G := 0;
begin
  fifo_proc : process(clock_i)
    variable rd_fire_v : boolean;
    variable wr_fire_v : boolean;
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        rd_ptr_s <= 0;
        wr_ptr_s <= 0;
        count_s  <= 0;
      else
        rd_fire_v := (rd_en_i = '1' and count_s > 0);
        wr_fire_v := (wr_en_i = '1' and sleep_i = '0' and (count_s < DEPTH_G or rd_fire_v));

        if wr_fire_v then
          mem_s(wr_ptr_s) <= din_i;
          wr_ptr_s <= inc_ptr(wr_ptr_s);
        end if;

        if rd_fire_v then
          rd_ptr_s <= inc_ptr(rd_ptr_s);
        end if;

        if wr_fire_v and not rd_fire_v then
          count_s <= count_s + 1;
        elsif rd_fire_v and not wr_fire_v then
          count_s <= count_s - 1;
        end if;
      end if;
    end if;
  end process fifo_proc;

  dout_o <= mem_s(rd_ptr_s) when count_s > 0 else (others => '0');
  prog_empty_o <= '1' when count_s <= PROG_EMPTY_THRESH_G else '0';
  prog_full_o <= '1' when count_s >= PROG_FULL_THRESH_G else '0';
  wr_data_count_o <= std_logic_vector(to_unsigned(count_s, COUNT_WIDTH_G));
end architecture rtl;
