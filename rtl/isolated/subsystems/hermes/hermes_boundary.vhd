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
begin
  -- Future home for a neutral handoff wrapper into the unchanged Hermes
  -- transport subsystem. This boundary must not change transport behavior.
  descriptor_taken_o <= '0';
  hermes_stat_o      <= HERMES_BOUNDARY_STATUS_NULL;
end architecture rtl;
