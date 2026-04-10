library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity hermes_boundary is
  port (
    clk               : in  std_logic;
    reset             : in  std_logic;
    descriptor_i      : in  trigger_descriptor_t;
    descriptor_taken_o : out std_logic;
    hermes_stat_o     : out hermes_boundary_status_t
  );
end entity hermes_boundary;

architecture rtl of hermes_boundary is
  signal link_up_s            : std_logic;
  signal backpressure_s       : std_logic;
  signal descriptor_accept_s  : std_logic;
begin
  -- Conservative isolated handoff model for the unchanged Hermes transport
  -- chain: the link comes up once reset is released, and payload(0) acts as a
  -- local backpressure knob so the composable proofs can exercise both accept
  -- and stall paths without importing the full transport RTL.
  link_up_s           <= not reset;
  backpressure_s      <= link_up_s and descriptor_i.valid and descriptor_i.payload(0);
  descriptor_accept_s <= link_up_s and descriptor_i.valid and not descriptor_i.payload(0);

  descriptor_taken_o       <= descriptor_accept_s;
  hermes_stat_o.ready      <= link_up_s and not backpressure_s;
  hermes_stat_o.backpressure <= backpressure_s;
  hermes_stat_o.link_up    <= link_up_s;
  hermes_stat_o.transport_busy <= link_up_s and descriptor_i.valid;
end architecture rtl;
