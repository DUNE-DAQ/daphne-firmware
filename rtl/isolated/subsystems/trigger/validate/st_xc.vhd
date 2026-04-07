library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity st_xc is
  port (
    reset      : in  std_logic;
    clock      : in  std_logic;
    enable     : in  std_logic;
    din        : in  std_logic_vector(13 downto 0);
    threshold  : in  std_logic_vector(27 downto 0);
    triggered  : out std_logic;
    xcorr_calc : out signed(27 downto 0)
  );
end entity st_xc;

architecture validate_stub of st_xc is
  signal xcorr_calc_s : signed(27 downto 0) := (others => '0');
  signal triggered_s  : std_logic := '0';
begin
  process (clock)
    variable sample_v : signed(27 downto 0);
  begin
    if rising_edge(clock) then
      if reset = '1' then
        xcorr_calc_s <= (others => '0');
        triggered_s  <= '0';
      elsif enable = '1' then
        sample_v := resize(signed(din), 28);
        xcorr_calc_s <= sample_v;
        if sample_v > signed(threshold) then
          triggered_s <= '1';
        else
          triggered_s <= '0';
        end if;
      else
        triggered_s <= '0';
      end if;
    end if;
  end process;

  xcorr_calc <= xcorr_calc_s;
  triggered  <= triggered_s;
end architecture validate_stub;
