library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity spy_buffer_boundary_formal is
  port (
    clk       : in std_logic;
    reset     : in std_logic;
    readiness : in acquisition_readiness_t
  );
end entity spy_buffer_boundary_formal;

architecture formal of spy_buffer_boundary_formal is
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
    (not reset) and
    readiness.config_ready and
    readiness.timing_ready and
    readiness.alignment_ready
  )
    report "spy_enable_o must match the readiness conjunction"
    severity failure;

  assert (reset = '0') or (spy_enable = '0')
    report "spy_enable_o must stay low while reset is asserted"
    severity failure;

  assert (readiness.config_ready = '1') or (spy_enable = '0')
    report "spy_enable_o must stay low until configuration is ready"
    severity failure;

  assert (readiness.timing_ready = '1') or (spy_enable = '0')
    report "spy_enable_o must stay low until timing is ready"
    severity failure;

  assert (readiness.alignment_ready = '1') or (spy_enable = '0')
    report "spy_enable_o must stay low until alignment is ready"
    severity failure;

  assert (
    (reset = '1') or
    (readiness.config_ready = '0') or
    (readiness.timing_ready = '0') or
    (readiness.alignment_ready = '0') or
    (spy_enable = '1')
  )
    report "spy_enable_o must rise once every documented readiness qualifier is satisfied"
    severity failure;
end architecture formal;
