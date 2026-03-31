library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity hermes_boundary_formal is
  port (
    clk          : in std_logic;
    reset        : in std_logic;
    descriptor_a : in trigger_descriptor_t;
    descriptor_b : in trigger_descriptor_t
  );
end entity hermes_boundary_formal;

architecture formal of hermes_boundary_formal is
  signal descriptor_taken_a : std_logic;
  signal descriptor_taken_b : std_logic;
  signal hermes_stat_a      : hermes_boundary_status_t;
  signal hermes_stat_b      : hermes_boundary_status_t;
begin
  dut_a : entity work.hermes_boundary
    port map (
      clk                => clk,
      reset              => reset,
      descriptor_i       => descriptor_a,
      descriptor_taken_o => descriptor_taken_a,
      hermes_stat_o      => hermes_stat_a
    );

  dut_b : entity work.hermes_boundary
    port map (
      clk                => clk,
      reset              => reset,
      descriptor_i       => descriptor_b,
      descriptor_taken_o => descriptor_taken_b,
      hermes_stat_o      => hermes_stat_b
    );

  assert descriptor_taken_a = '0'
    report "neutral Hermes boundary must not consume descriptors"
    severity failure;

  assert descriptor_taken_b = '0'
    report "descriptor consumption must remain independent of descriptor payloads"
    severity failure;

  assert hermes_stat_a = HERMES_BOUNDARY_STATUS_NULL
    report "neutral Hermes boundary must expose the null status record"
    severity failure;

  assert hermes_stat_b = HERMES_BOUNDARY_STATUS_NULL
    report "Hermes boundary status must remain neutral for arbitrary descriptors"
    severity failure;

  assert descriptor_taken_a = descriptor_taken_b
    report "descriptor-taken behavior must be input-independent while the boundary is neutral"
    severity failure;

  assert hermes_stat_a = hermes_stat_b
    report "Hermes boundary status must not depend on descriptor payloads"
    severity failure;
end architecture formal;
