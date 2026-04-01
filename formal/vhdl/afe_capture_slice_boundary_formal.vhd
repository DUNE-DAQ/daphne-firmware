library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity afe_capture_slice_boundary_formal is
  port (
    resetn_i            : in std_logic;
    prereq_i            : in frontend_prereq_t;
    idelayctrl_ready_i  : in std_logic;
    align_ctrl_i        : in afe_alignment_control_t;
    align_stat_i        : in afe_alignment_status_t
  );
end entity afe_capture_slice_boundary_formal;

architecture formal of afe_capture_slice_boundary_formal is
  signal align_stat_o : afe_alignment_status_t;
begin
  dut : entity work.afe_capture_slice_boundary
    port map (
      resetn_i            => resetn_i,
      prereq_i            => prereq_i,
      idelayctrl_ready_i  => idelayctrl_ready_i,
      align_ctrl_i        => align_ctrl_i,
      align_stat_i        => align_stat_i,
      align_stat_o        => align_stat_o
    );

  assert align_stat_o.format_ok = align_stat_i.format_ok
    report "per-AFE boundary must pass through format_ok"
    severity failure;

  assert align_stat_o.training_ok = align_stat_i.training_ok
    report "per-AFE boundary must pass through training_ok"
    severity failure;

  assert align_stat_o.alignment_valid = (
    resetn_i and
    prereq_i.config_ready and
    prereq_i.timing_ready and
    idelayctrl_ready_i and
    align_stat_i.format_ok and
    align_stat_i.training_ok and
    (not align_ctrl_i.idelay_load)
  )
    report "per-AFE alignment_valid must match the qualified readiness conjunction"
    severity failure;

  assert (resetn_i = '1') or (align_stat_o.alignment_valid = '0')
    report "per-AFE alignment_valid must stay low while reset is asserted"
    severity failure;

  assert (prereq_i.config_ready = '1') or (align_stat_o.alignment_valid = '0')
    report "per-AFE alignment_valid must stay low until analog configuration is ready"
    severity failure;

  assert (prereq_i.timing_ready = '1') or (align_stat_o.alignment_valid = '0')
    report "per-AFE alignment_valid must stay low until timing is ready"
    severity failure;

  assert (idelayctrl_ready_i = '1') or (align_stat_o.alignment_valid = '0')
    report "per-AFE alignment_valid must stay low until IDELAYCTRL is ready"
    severity failure;

  assert (align_ctrl_i.idelay_load = '0') or (align_stat_o.alignment_valid = '0')
    report "per-AFE alignment_valid must stay low while a new delay tap is loading"
    severity failure;
end architecture formal;
