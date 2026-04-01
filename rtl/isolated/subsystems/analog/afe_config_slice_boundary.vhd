library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity afe_config_slice_boundary is
  port (
    resetn_i      : in  std_logic;
    config_valid_i: in  std_logic;
    status_i      : in  afe_config_status_t;
    status_o      : out afe_config_status_t
  );
end entity afe_config_slice_boundary;

architecture rtl of afe_config_slice_boundary is
begin
  qualify_proc : process(all)
    variable status_q : afe_config_status_t;
  begin
    status_q := status_i;
    status_q.ready := resetn_i and
                      config_valid_i and
                      (not status_i.afe_busy) and
                      (not status_i.trim_busy) and
                      (not status_i.offset_busy);
    status_o <= status_q;
  end process qualify_proc;
end architecture rtl;
