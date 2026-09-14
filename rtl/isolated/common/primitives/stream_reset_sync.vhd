library ieee;
use ieee.std_logic_1164.all;

-- A stream abort must assert even when its clock stops. Release only after
-- STAGES_G destination edges, so queue and transmitter state restart together.
entity stream_reset_sync is
  generic(STAGES_G : positive := 4);
  port(clock_i, reset_i : in std_logic; reset_o : out std_logic);
end entity;
architecture rtl of stream_reset_sync is
  signal reset_pipe_s : std_logic_vector(STAGES_G-1 downto 0) := (others=>'1');
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of reset_pipe_s : signal is "TRUE";
begin
  assert STAGES_G>=2 severity failure;
  process(clock_i,reset_i)
  begin
    if reset_i='1' then reset_pipe_s<=(others=>'1');
    elsif rising_edge(clock_i) then reset_pipe_s<=reset_pipe_s(STAGES_G-2 downto 0)&'0'; end if;
  end process;
  reset_o<=reset_pipe_s(STAGES_G-1);
end architecture;
