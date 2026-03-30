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
  analog_stat_o <= ANALOG_STATUS_NULL;
end architecture rtl;
