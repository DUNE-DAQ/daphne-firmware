library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity trigger_pipeline_boundary_formal is
end entity trigger_pipeline_boundary_formal;

architecture formal of trigger_pipeline_boundary_formal is
  signal clk              : std_logic := '0';
  signal reset            : std_logic := '0';
  signal descriptor_rdy   : std_logic := '0';
  signal readiness        : acquisition_readiness_t := ACQUISITION_READINESS_NULL;
  signal trigger_enable   : std_logic;
  signal descriptor       : trigger_descriptor_t;
begin
  dut : entity work.trigger_pipeline_boundary
    port map (
      clk              => clk,
      reset            => reset,
      readiness_i      => readiness,
      trigger_enable_o => trigger_enable,
      descriptor_o     => descriptor,
      descriptor_rdy   => descriptor_rdy
    );

  -- These assertions define the current proof-carrying contract for the
  -- boundary wrapper: trigger gating is entirely determined by the neutral
  -- readiness contract, and the wrapper itself does not synthesize a
  -- descriptor.
  assert trigger_enable = (
    readiness.config_ready and
    readiness.timing_ready and
    readiness.alignment_ready
  )
    report "trigger_enable_o must match the readiness conjunction"
    severity failure;

  assert descriptor = TRIGGER_DESCRIPTOR_NULL
    report "boundary wrapper must not synthesize a descriptor"
    severity failure;
end architecture formal;
