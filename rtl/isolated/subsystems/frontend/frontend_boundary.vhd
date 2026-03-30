library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity frontend_boundary is
  port (
    clk_axi      : in  std_logic;
    resetn_axi   : in  std_logic;
    align_ctrl_i : in  frontend_alignment_control_t;
    align_stat_o : out frontend_alignment_status_t
  );
end entity frontend_boundary;

architecture rtl of frontend_boundary is
begin
  -- Future neutral boundary for frontend alignment and sample-format
  -- assumptions. The current imported implementation stays untouched; this
  -- shell exists to capture the contract before rewiring any logic.
  align_stat_o <= FRONTEND_ALIGNMENT_STATUS_NULL;
end architecture rtl;
