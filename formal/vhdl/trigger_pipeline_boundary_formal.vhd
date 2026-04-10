library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity trigger_pipeline_boundary_formal is
  port (
    clk            : in std_logic;
    reset          : in std_logic;
    readiness      : in acquisition_readiness_t;
    descriptor_rdy : in std_logic
  );
end entity trigger_pipeline_boundary_formal;

architecture formal of trigger_pipeline_boundary_formal is
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
    (not reset) and
    readiness.config_ready and
    readiness.timing_ready and
    readiness.alignment_ready
  )
    report "trigger_enable_o must match the readiness conjunction"
    severity failure;

  assert descriptor = TRIGGER_DESCRIPTOR_NULL
    report "boundary wrapper must not synthesize a descriptor"
    severity failure;

  assert (reset = '0') or (trigger_enable = '0')
    report "trigger_enable_o must stay low while reset is asserted"
    severity failure;

  assert (readiness.config_ready = '1') or (trigger_enable = '0')
    report "trigger_enable_o must stay low until configuration is ready"
    severity failure;

  assert (readiness.timing_ready = '1') or (trigger_enable = '0')
    report "trigger_enable_o must stay low until timing is ready"
    severity failure;

  assert (readiness.alignment_ready = '1') or (trigger_enable = '0')
    report "trigger_enable_o must stay low until alignment is ready"
    severity failure;

  assert (
    (reset = '1') or
    (readiness.config_ready = '0') or
    (readiness.timing_ready = '0') or
    (readiness.alignment_ready = '0') or
    (trigger_enable = '1')
  )
    report "trigger_enable_o must rise once every documented readiness qualifier is satisfied"
    severity failure;
end architecture formal;
