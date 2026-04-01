library ieee;
use ieee.std_logic_1164.all;

entity fixed_delay_line_formal is
  port (
    clock_i : in std_logic;
    din_i   : in std_logic_vector(0 downto 0)
  );
end entity fixed_delay_line_formal;

architecture formal of fixed_delay_line_formal is
  constant DELAY_C : natural := 3;
  signal dout_s  : std_logic_vector(0 downto 0);

  type history_t is array (0 to DELAY_C - 1) of std_logic_vector(0 downto 0);
  signal history_s : history_t := (others => (others => '0'));
begin
  dut : entity work.fixed_delay_line
    generic map (
      WIDTH_G => 1,
      DELAY_G => DELAY_C
    )
    port map (
      clock_i => clock_i,
      din_i   => din_i,
      dout_o  => dout_s
    );

  model_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      history_s(0) <= din_i;
      for idx in 1 to DELAY_C - 1 loop
        history_s(idx) <= history_s(idx - 1);
      end loop;

      assert dout_s = history_s(DELAY_C - 1)
        report "fixed_delay_line output does not match the delayed history"
        severity failure;
    end if;
  end process model_proc;
end architecture formal;
