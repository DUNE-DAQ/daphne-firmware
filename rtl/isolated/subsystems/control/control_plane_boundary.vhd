library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity control_plane_boundary is
  port (
    clk_axi      : in  std_logic;
    resetn_axi   : in  std_logic;
    timing_ctrl_o : out timing_control_t;
    timing_stat_i : in  timing_status_t
  );
end entity control_plane_boundary;

architecture rtl of control_plane_boundary is
begin
  -- This wrapper is intentionally additive and not yet wired into the build.
  -- It marks the future proof-oriented boundary between the PS-visible
  -- register plane and subsystem-local control/state records.
  timing_ctrl_o <= TIMING_CONTROL_NULL;
end architecture rtl;
