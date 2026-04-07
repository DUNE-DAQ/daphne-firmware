library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity k_low_pass_filter is
  port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    enable : in  std_logic;
    x      : in  signed(15 downto 0);
    y      : out signed(15 downto 0)
  );
end entity k_low_pass_filter;

architecture validate_stub of k_low_pass_filter is
  signal y_s : signed(15 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        y_s <= (others => '0');
      elsif enable = '1' then
        y_s <= x;
      end if;
    end if;
  end process;

  y <= y_s;
end architecture validate_stub;
