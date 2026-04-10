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
  signal link_up_expected_a : std_logic;
  signal link_up_expected_b : std_logic;
  signal backpressure_expected_a : std_logic;
  signal backpressure_expected_b : std_logic;
  signal descriptor_taken_expected_a : std_logic;
  signal descriptor_taken_expected_b : std_logic;
  signal transport_busy_expected_a : std_logic;
  signal transport_busy_expected_b : std_logic;
  signal ready_expected_a : std_logic;
  signal ready_expected_b : std_logic;
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

  link_up_expected_a <= not reset;
  link_up_expected_b <= not reset;
  backpressure_expected_a <= link_up_expected_a and descriptor_a.valid and descriptor_a.payload(0);
  backpressure_expected_b <= link_up_expected_b and descriptor_b.valid and descriptor_b.payload(0);
  descriptor_taken_expected_a <= link_up_expected_a and descriptor_a.valid and not descriptor_a.payload(0);
  descriptor_taken_expected_b <= link_up_expected_b and descriptor_b.valid and not descriptor_b.payload(0);
  transport_busy_expected_a <= link_up_expected_a and descriptor_a.valid;
  transport_busy_expected_b <= link_up_expected_b and descriptor_b.valid;
  ready_expected_a <= link_up_expected_a and not backpressure_expected_a;
  ready_expected_b <= link_up_expected_b and not backpressure_expected_b;

  assert descriptor_taken_a = descriptor_taken_expected_a
    report "Hermes boundary must only take descriptors when reset is released and the local backpressure knob is clear"
    severity failure;

  assert descriptor_taken_b = descriptor_taken_expected_b
    report "Hermes descriptor acceptance must follow the same reset-plus-backpressure contract for arbitrary descriptors"
    severity failure;

  assert hermes_stat_a.link_up = link_up_expected_a
    report "Hermes boundary link-up must track local reset release"
    severity failure;

  assert hermes_stat_b.link_up = link_up_expected_b
    report "Hermes boundary link-up must remain reset-qualified for arbitrary descriptors"
    severity failure;

  assert hermes_stat_a.backpressure = backpressure_expected_a
    report "Hermes boundary backpressure must only assert for a valid descriptor with the modeled stall bit set"
    severity failure;

  assert hermes_stat_b.backpressure = backpressure_expected_b
    report "Hermes boundary backpressure must follow the same modeled stall contract for arbitrary descriptors"
    severity failure;

  assert hermes_stat_a.ready = ready_expected_a
    report "Hermes boundary ready must drop only for a modeled backpressure stall while the link is up"
    severity failure;

  assert hermes_stat_b.ready = ready_expected_b
    report "Hermes boundary ready must follow the same modeled accept-or-stall contract for arbitrary descriptors"
    severity failure;

  assert hermes_stat_a.transport_busy = transport_busy_expected_a
    report "Hermes boundary transport_busy must reflect live descriptor presence once reset is released"
    severity failure;

  assert hermes_stat_b.transport_busy = transport_busy_expected_b
    report "Hermes boundary transport_busy must follow the same live-descriptor contract for arbitrary descriptors"
    severity failure;

  assert hermes_stat_a.link_up = hermes_stat_b.link_up
    report "Hermes link-up must stay descriptor-independent once reset is fixed"
    severity failure;
end architecture formal;
