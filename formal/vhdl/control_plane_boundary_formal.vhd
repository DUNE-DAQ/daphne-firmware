library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity control_plane_boundary_formal is
  port (
    clk_axi       : in std_logic;
    resetn_axi    : in std_logic;
    timing_stat_a : in timing_status_t;
    timing_stat_b : in timing_status_t
  );
end entity control_plane_boundary_formal;

architecture formal of control_plane_boundary_formal is
  signal timing_ctrl_a : timing_control_t;
  signal timing_ctrl_b : timing_control_t;
begin
  dut_a : entity work.control_plane_boundary
    port map (
      clk_axi       => clk_axi,
      resetn_axi    => resetn_axi,
      timing_ctrl_o => timing_ctrl_a,
      timing_stat_i => timing_stat_a
    );

  dut_b : entity work.control_plane_boundary
    port map (
      clk_axi       => clk_axi,
      resetn_axi    => resetn_axi,
      timing_ctrl_o => timing_ctrl_b,
      timing_stat_i => timing_stat_b
    );

  assert timing_ctrl_a = TIMING_CONTROL_NULL
    report "control-plane boundary must currently drive the null timing control record"
    severity failure;

  assert timing_ctrl_b = TIMING_CONTROL_NULL
    report "control-plane boundary must remain input-independent while it is neutral"
    severity failure;

  assert timing_ctrl_a = timing_ctrl_b
    report "control-plane output must not depend on ignored timing status inputs"
    severity failure;
end architecture formal;
