library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity configurable_delay_line is
  generic (
    WIDTH_G     : positive := 28;
    MAX_DELAY_G : positive := 32
  );
  port (
    clock_i : in  std_logic;
    din_i   : in  std_logic_vector(WIDTH_G - 1 downto 0);
    delay_i : in  std_logic_vector(4 downto 0);
    dout_o  : out std_logic_vector(WIDTH_G - 1 downto 0)
  );
end entity configurable_delay_line;

architecture rtl of configurable_delay_line is
  type delay_array_t is array (0 to MAX_DELAY_G - 1) of std_logic_vector(WIDTH_G - 1 downto 0);
  signal delay_s : delay_array_t := (others => (others => '0'));
begin
  delay_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      delay_s(0) <= din_i;
      for idx in 1 to MAX_DELAY_G - 1 loop
        delay_s(idx) <= delay_s(idx - 1);
      end loop;
    end if;
  end process delay_proc;

  select_proc : process(delay_i, din_i, delay_s)
    variable delay_v : natural;
  begin
    delay_v := to_integer(unsigned(delay_i));
    if delay_v = 0 then
      dout_o <= din_i;
    elsif delay_v < MAX_DELAY_G then
      dout_o <= delay_s(delay_v - 1);
    else
      dout_o <= delay_s(MAX_DELAY_G - 1);
    end if;
  end process select_proc;
end architecture rtl;
