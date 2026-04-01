library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity afe_config_slice_boundary_formal is
  port (
    resetn_i       : in std_logic;
    config_valid_i : in std_logic;
    status_i       : in afe_config_status_t
  );
end entity afe_config_slice_boundary_formal;

architecture formal of afe_config_slice_boundary_formal is
  signal status_o : afe_config_status_t;
begin
  dut : entity work.afe_config_slice_boundary
    port map (
      resetn_i       => resetn_i,
      config_valid_i => config_valid_i,
      status_i       => status_i,
      status_o       => status_o
    );

  assert status_o.afe_readback = status_i.afe_readback
    report "AFE config boundary must pass through readback data"
    severity failure;

  assert status_o.afe_busy = status_i.afe_busy
    report "AFE config boundary must pass through AFE busy"
    severity failure;

  assert status_o.trim_busy = status_i.trim_busy
    report "AFE config boundary must pass through trim busy"
    severity failure;

  assert status_o.offset_busy = status_i.offset_busy
    report "AFE config boundary must pass through offset busy"
    severity failure;

  assert status_o.ready = (
    resetn_i and
    config_valid_i and
    (not status_i.afe_busy) and
    (not status_i.trim_busy) and
    (not status_i.offset_busy)
  )
    report "AFE config boundary ready must match the qualified idle conjunction"
    severity failure;

  assert (resetn_i = '1') or (status_o.ready = '0')
    report "AFE config boundary ready must stay low while reset is asserted"
    severity failure;

  assert (config_valid_i = '1') or (status_o.ready = '0')
    report "AFE config boundary ready must stay low until the slice is declared valid"
    severity failure;
end architecture formal;
