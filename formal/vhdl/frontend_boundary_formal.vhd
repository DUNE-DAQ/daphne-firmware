library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity frontend_boundary_formal is
end entity frontend_boundary_formal;

architecture formal of frontend_boundary_formal is
  signal clk_axi      : std_logic := '0';
  signal resetn_axi   : std_logic := '1';
  signal prereq       : frontend_prereq_t := FRONTEND_PREREQ_NULL;
  signal align_ctrl   : frontend_alignment_control_t := FRONTEND_ALIGNMENT_CONTROL_NULL;
  signal align_stat_i : frontend_alignment_status_t := FRONTEND_ALIGNMENT_STATUS_NULL;
  signal align_stat_o : frontend_alignment_status_t;
begin
  dut : entity work.frontend_boundary
    port map (
      clk_axi      => clk_axi,
      resetn_axi   => resetn_axi,
      prereq_i     => prereq,
      align_ctrl_i => align_ctrl,
      align_stat_i => align_stat_i,
      align_stat_o => align_stat_o
    );

  assert align_stat_o.idelayctrl_ready = align_stat_i.idelayctrl_ready
    report "frontend boundary must pass through idelayctrl_ready"
    severity failure;

  assert align_stat_o.format_ok = align_stat_i.format_ok
    report "frontend boundary must pass through format_ok"
    severity failure;

  assert align_stat_o.training_ok = align_stat_i.training_ok
    report "frontend boundary must pass through training_ok"
    severity failure;

  assert align_stat_o.alignment_valid = (
    prereq.config_ready and
    prereq.timing_ready and
    align_stat_i.idelayctrl_ready and
    align_stat_i.format_ok and
    align_stat_i.training_ok and
    (not align_ctrl.idelayctrl_reset) and
    (not align_ctrl.iserdes_reset)
  )
    report "alignment_valid must match the qualified readiness conjunction"
    severity failure;
end architecture formal;
