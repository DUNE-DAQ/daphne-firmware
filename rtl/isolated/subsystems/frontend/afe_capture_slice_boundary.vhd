library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity afe_capture_slice_boundary is
  port (
    resetn_i            : in  std_logic;
    prereq_i            : in  frontend_prereq_t;
    idelayctrl_ready_i  : in  std_logic;
    align_ctrl_i        : in  afe_alignment_control_t;
    align_stat_i        : in  afe_alignment_status_t;
    align_stat_o        : out afe_alignment_status_t
  );
end entity afe_capture_slice_boundary;

architecture rtl of afe_capture_slice_boundary is
begin
  qualify_proc : process(all)
    variable align_stat_q : afe_alignment_status_t;
  begin
    align_stat_q := align_stat_i;
    align_stat_q.alignment_valid := resetn_i and
                                    prereq_i.config_ready and
                                    prereq_i.timing_ready and
                                    idelayctrl_ready_i and
                                    align_stat_i.format_ok and
                                    align_stat_i.training_ok and
                                    (not align_ctrl_i.idelay_load);
    align_stat_o <= align_stat_q;
  end process qualify_proc;
end architecture rtl;
