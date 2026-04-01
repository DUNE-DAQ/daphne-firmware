library ieee;
use ieee.std_logic_1164.all;

entity fixed_delay_line is
  generic (
    WIDTH_G : positive := 14;
    DELAY_G : positive := 288
  );
  port (
    clock_i : in  std_logic;
    din_i   : in  std_logic_vector(WIDTH_G - 1 downto 0);
    dout_o  : out std_logic_vector(WIDTH_G - 1 downto 0)
  );
end entity fixed_delay_line;

architecture rtl of fixed_delay_line is
  type delay_array_t is array (0 to DELAY_G - 1) of std_logic_vector(WIDTH_G - 1 downto 0);
  signal delay_s : delay_array_t := (others => (others => '0'));
begin
  delay_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      delay_s(0) <= din_i;
      for idx in 1 to DELAY_G - 1 loop
        delay_s(idx) <= delay_s(idx - 1);
      end loop;
    end if;
  end process delay_proc;

  dout_o <= delay_s(DELAY_G - 1);
end architecture rtl;
