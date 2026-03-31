library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity frontend_boundary_formal is
  port (
    clk_axi      : in std_logic;
    resetn_axi   : in std_logic;
    prereq       : in frontend_prereq_t;
    align_ctrl   : in frontend_alignment_control_t;
    align_stat_i : in frontend_alignment_status_t
  );
end entity frontend_boundary_formal;

architecture formal of frontend_boundary_formal is
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
    resetn_axi and
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

  assert (resetn_axi = '1') or (align_stat_o.alignment_valid = '0')
    report "alignment_valid must stay low while frontend reset is asserted"
    severity failure;

  assert (prereq.config_ready = '1') or (align_stat_o.alignment_valid = '0')
    report "alignment_valid must stay low until analog configuration is ready"
    severity failure;

  assert (prereq.timing_ready = '1') or (align_stat_o.alignment_valid = '0')
    report "alignment_valid must stay low until timing is ready"
    severity failure;

  assert (align_stat_i.idelayctrl_ready = '1') or (align_stat_o.alignment_valid = '0')
    report "alignment_valid must stay low until IDELAYCTRL is ready"
    severity failure;

  assert (align_stat_i.format_ok = '1') or (align_stat_o.alignment_valid = '0')
    report "alignment_valid must stay low while the sample format check fails"
    severity failure;

  assert (align_stat_i.training_ok = '1') or (align_stat_o.alignment_valid = '0')
    report "alignment_valid must stay low while the training-pattern check fails"
    severity failure;

  assert (align_ctrl.idelayctrl_reset = '0') or (align_stat_o.alignment_valid = '0')
    report "alignment_valid must stay low while IDELAYCTRL reset is asserted"
    severity failure;

  assert (align_ctrl.iserdes_reset = '0') or (align_stat_o.alignment_valid = '0')
    report "alignment_valid must stay low while ISERDES reset is asserted"
    severity failure;
end architecture formal;
