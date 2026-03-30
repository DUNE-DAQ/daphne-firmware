library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity spy_buffer_boundary_formal is
end entity spy_buffer_boundary_formal;

architecture formal of spy_buffer_boundary_formal is
  signal clk         : std_logic := '0';
  signal reset       : std_logic := '0';
  signal readiness   : acquisition_readiness_t := ACQUISITION_READINESS_NULL;
  signal spy_enable  : std_logic;
begin
  dut : entity work.spy_buffer_boundary
    port map (
      clk          => clk,
      reset        => reset,
      readiness_i  => readiness,
      spy_enable_o => spy_enable
    );

  assert spy_enable = (
    readiness.config_ready and
    readiness.timing_ready and
    readiness.alignment_ready
  )
    report "spy_enable_o must match the readiness conjunction"
    severity failure;
end architecture formal;
