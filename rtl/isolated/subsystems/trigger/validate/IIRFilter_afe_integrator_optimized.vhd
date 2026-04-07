library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IIRFilter_afe_integrator_optimized is
  port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    enable : in  std_logic;
    x      : in  signed(15 downto 0);
    y      : out signed(15 downto 0)
  );
end entity IIRFilter_afe_integrator_optimized;

architecture validate_stub of IIRFilter_afe_integrator_optimized is
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
