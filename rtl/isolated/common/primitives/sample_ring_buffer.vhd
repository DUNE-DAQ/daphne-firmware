library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sample_ring_buffer is
  generic (
    DATA_WIDTH_G : positive := 14;
    DEPTH_G      : positive := 4096;
    ADDR_WIDTH_G : positive := 12
  );
  port (
    clock_i   : in  std_logic;
    wr_en_i   : in  std_logic;
    wr_addr_i : in  unsigned(ADDR_WIDTH_G - 1 downto 0);
    din_i     : in  std_logic_vector(DATA_WIDTH_G - 1 downto 0);
    rd_addr_i : in  unsigned(ADDR_WIDTH_G - 1 downto 0);
    dout_o    : out std_logic_vector(DATA_WIDTH_G - 1 downto 0)
  );
end entity sample_ring_buffer;

architecture rtl of sample_ring_buffer is
  type ram_t is array (0 to DEPTH_G - 1) of std_logic_vector(DATA_WIDTH_G - 1 downto 0);
  signal ram_s  : ram_t := (others => (others => '0'));
  signal dout_s : std_logic_vector(DATA_WIDTH_G - 1 downto 0) := (others => '0');

  attribute ram_style : string;
  attribute ram_style of ram_s : signal is "block";
begin
  process(clock_i)
  begin
    if rising_edge(clock_i) then
      if wr_en_i = '1' then
        ram_s(to_integer(wr_addr_i)) <= din_i;
      end if;

      dout_s <= ram_s(to_integer(rd_addr_i));
    end if;
  end process;

  dout_o <= dout_s;
end architecture rtl;
