library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity configurable_delay_line_formal is
  port (
    clock_i : in std_logic;
    din_i   : in std_logic_vector(0 downto 0);
    delay_i : in std_logic_vector(1 downto 0)
  );
end entity configurable_delay_line_formal;

architecture formal of configurable_delay_line_formal is
  constant MAX_DELAY_C : natural := 4;
  signal dout_s  : std_logic_vector(0 downto 0);
  signal delay_s : std_logic_vector(4 downto 0);

  type history_t is array (0 to MAX_DELAY_C - 1) of std_logic_vector(0 downto 0);
  signal history_s : history_t := (others => (others => '0'));
begin
  delay_s(4 downto 2) <= (others => '0');
  delay_s(1 downto 0) <= delay_i;

  dut : entity work.configurable_delay_line
    generic map (
      WIDTH_G     => 1,
      MAX_DELAY_G => MAX_DELAY_C
    )
    port map (
      clock_i => clock_i,
      din_i   => din_i,
      delay_i => delay_s,
      dout_o  => dout_s
    );

  model_proc : process(clock_i)
    variable delay_v : natural;
  begin
    if rising_edge(clock_i) then
      history_s(0) <= din_i;
      for idx in 1 to MAX_DELAY_C - 1 loop
        history_s(idx) <= history_s(idx - 1);
      end loop;

      delay_v := to_integer(unsigned(delay_s));
      if delay_v = 0 then
        assert dout_s = din_i
          report "configurable_delay_line with zero delay must return the live input"
          severity failure;
      else
        assert dout_s = history_s(delay_v - 1)
          report "configurable_delay_line output does not match the selected delayed history"
          severity failure;
      end if;
    end if;
  end process model_proc;
end architecture formal;
