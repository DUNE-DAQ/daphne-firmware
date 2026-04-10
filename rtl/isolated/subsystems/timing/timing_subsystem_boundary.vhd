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
  constant ENDPOINT_STATE_HELD_RESET_C : std_logic_vector(3 downto 0) := x"1";
  constant ENDPOINT_STATE_WAIT_LOCK_C  : std_logic_vector(3 downto 0) := x"2";
  constant ENDPOINT_STATE_READY_C      : std_logic_vector(3 downto 0) := x"f";

  signal endpoint_clock_selected_s : std_logic;
  signal mmcm0_locked_s            : std_logic;
  signal mmcm1_locked_s            : std_logic;
  signal endpoint_ready_s          : std_logic;
  signal sync_req_s                : std_logic;
begin
  -- Conservative endpoint-selected timing model for the isolated composable
  -- flow: local timing remains neutral, while the endpoint-selected path
  -- exposes explicit lock/ready/timestamp semantics without importing PDTS RTL.
  endpoint_clock_selected_s <= resetn_axi and timing_ctrl_i.use_endpoint_clock;
  mmcm0_locked_s            <= endpoint_clock_selected_s and not timing_ctrl_i.mmcm0_reset;
  mmcm1_locked_s            <= endpoint_clock_selected_s and not timing_ctrl_i.mmcm1_reset;
  endpoint_ready_s          <= mmcm0_locked_s and mmcm1_locked_s and not timing_ctrl_i.endpoint_reset;
  sync_req_s                <= endpoint_ready_s and timing_ctrl_i.endpoint_addr(0);

  timing_stat_o.mmcm0_locked <= mmcm0_locked_s;
  timing_stat_o.mmcm1_locked <= mmcm1_locked_s;
  timing_stat_o.endpoint_ready <= endpoint_ready_s;
  timing_stat_o.endpoint_state <= ENDPOINT_STATE_READY_C
                                  when endpoint_ready_s = '1'
                                  else ENDPOINT_STATE_HELD_RESET_C
                                  when endpoint_clock_selected_s = '1' and timing_ctrl_i.endpoint_reset = '1'
                                  else ENDPOINT_STATE_WAIT_LOCK_C
                                  when endpoint_clock_selected_s = '1'
                                  else (others => '0');
  timing_stat_o.timestamp_valid <= endpoint_ready_s;

  timestamp_o <= timing_ctrl_i.endpoint_addr &
                 timing_ctrl_i.endpoint_addr &
                 timing_ctrl_i.endpoint_addr &
                 timing_ctrl_i.endpoint_addr
                 when endpoint_ready_s = '1'
                 else (others => '0');

  sync_o <= timing_ctrl_i.endpoint_addr(7 downto 0)
            when sync_req_s = '1'
            else (others => '0');
  sync_stb_o <= sync_req_s;
end architecture rtl;
