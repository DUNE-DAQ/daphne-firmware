library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity frontend_boundary is
  port (
    clk_axi       : in  std_logic;
    resetn_axi    : in  std_logic;
    prereq_i      : in  frontend_prereq_t;
    align_ctrl_i  : in  frontend_alignment_control_t;
    align_stat_i  : in  frontend_alignment_status_t;
    align_stat_o  : out frontend_alignment_status_t
  );
end entity frontend_boundary;

architecture rtl of frontend_boundary is
begin
  -- Neutral boundary for frontend alignment validity. The imported
  -- implementation stays untouched; this wrapper only qualifies the observed
  -- status with the documented configuration/timing/reset prerequisites.
  qualify_proc : process(all)
    variable align_stat_q : frontend_alignment_status_t;
  begin
    align_stat_q := align_stat_i;
    align_stat_q.alignment_valid := resetn_axi and
                                    prereq_i.config_ready and
                                    prereq_i.timing_ready and
                                    align_stat_i.idelayctrl_ready and
                                    align_stat_i.format_ok and
                                    align_stat_i.training_ok and
                                    (not align_ctrl_i.idelayctrl_reset) and
                                    (not align_ctrl_i.iserdes_reset);
    align_stat_o <= align_stat_q;
  end process qualify_proc;
end architecture rtl;
