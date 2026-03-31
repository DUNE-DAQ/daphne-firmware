library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity analog_control_boundary is
  port (
    clk_axi       : in  std_logic;
    resetn_axi    : in  std_logic;
    analog_ctrl_i : in  analog_control_t;
    analog_stat_o : out analog_status_t
  );
end entity analog_control_boundary;

architecture rtl of analog_control_boundary is
begin
  -- Neutral boundary for the AFE/DAC configuration path. The imported
  -- implementation remains untouched; this shell exists so the contract can be
  -- isolated from the downstream alignment and trigger logic.
  qualify_proc : process(all)
    variable analog_stat_q : analog_status_t;
  begin
    analog_stat_q := ANALOG_STATUS_NULL;

    if resetn_axi = '1' then
      analog_stat_q.afe_ready := analog_ctrl_i.afe_resetn and
                                 analog_ctrl_i.afe_config_valid;
      analog_stat_q.dac_ready := analog_ctrl_i.dac_resetn and
                                 analog_ctrl_i.dac_config_valid;
      analog_stat_q.config_ready := analog_stat_q.afe_ready and
                                    analog_stat_q.dac_ready;
    end if;

    analog_stat_o <= analog_stat_q;
  end process qualify_proc;
end architecture rtl;
