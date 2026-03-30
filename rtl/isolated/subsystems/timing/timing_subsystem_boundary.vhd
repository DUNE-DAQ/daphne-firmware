library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity timing_subsystem_boundary is
  port (
    clk_axi      : in  std_logic;
    resetn_axi   : in  std_logic;
    timing_ctrl_i : in  timing_control_t;
    timing_stat_o : out timing_status_t;
    timestamp_o   : out std_logic_vector(63 downto 0);
    sync_o        : out std_logic_vector(7 downto 0);
    sync_stb_o    : out std_logic
  );
end entity timing_subsystem_boundary;

architecture rtl of timing_subsystem_boundary is
begin
  -- Future home for the cleaned DAPHNE-facing timing adapter:
  -- existing timing concepts and register ABI stay intact, while internal
  -- status/control propagation becomes explicit and typed.
  timing_stat_o <= TIMING_STATUS_NULL;
  timestamp_o   <= (others => '0');
  sync_o        <= (others => '0');
  sync_stb_o    <= '0';
end architecture rtl;
