library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity analog_control_boundary_formal is
  port (
    clk_axi     : in std_logic;
    resetn_axi  : in std_logic;
    analog_ctrl : in analog_control_t
  );
end entity analog_control_boundary_formal;

architecture formal of analog_control_boundary_formal is
  signal analog_stat : analog_status_t;
begin
  dut : entity work.analog_control_boundary
    port map (
      clk_axi       => clk_axi,
      resetn_axi    => resetn_axi,
      analog_ctrl_i => analog_ctrl,
      analog_stat_o => analog_stat
    );

  assert analog_stat.afe_ready = (
    resetn_axi and
    analog_ctrl.afe_resetn and
    analog_ctrl.afe_config_valid
  )
    report "AFE ready must depend on reset deassertion and valid AFE configuration"
    severity failure;

  assert analog_stat.dac_ready = (
    resetn_axi and
    analog_ctrl.dac_resetn and
    analog_ctrl.dac_config_valid
  )
    report "DAC ready must depend on reset deassertion and valid DAC configuration"
    severity failure;

  assert analog_stat.config_ready = (
    resetn_axi and
    analog_ctrl.afe_resetn and
    analog_ctrl.afe_config_valid and
    analog_ctrl.dac_resetn and
    analog_ctrl.dac_config_valid
  )
    report "config_ready must require both AFE and DAC readiness under reset release"
    severity failure;

  assert (resetn_axi = '1') or (analog_stat = ANALOG_STATUS_NULL)
    report "analog status must reset to the null readiness state"
    severity failure;

  assert (analog_stat.afe_ready = '1') or (analog_stat.config_ready = '0')
    report "config_ready must deassert when AFE readiness is false"
    severity failure;

  assert (analog_stat.dac_ready = '1') or (analog_stat.config_ready = '0')
    report "config_ready must deassert when DAC readiness is false"
    severity failure;
end architecture formal;
