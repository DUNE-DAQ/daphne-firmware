library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity timing_subsystem_boundary_formal is
  port (
    clk_axi       : in std_logic;
    resetn_axi    : in std_logic;
    timing_ctrl_a : in timing_control_t;
    timing_ctrl_b : in timing_control_t
  );
end entity timing_subsystem_boundary_formal;

architecture formal of timing_subsystem_boundary_formal is
  constant ENDPOINT_STATE_HELD_RESET_C : std_logic_vector(3 downto 0) := x"1";
  constant ENDPOINT_STATE_WAIT_LOCK_C  : std_logic_vector(3 downto 0) := x"2";
  constant ENDPOINT_STATE_READY_C      : std_logic_vector(3 downto 0) := x"f";

  signal timing_stat_a : timing_status_t;
  signal timing_stat_b : timing_status_t;
  signal timestamp_a   : std_logic_vector(63 downto 0);
  signal timestamp_b   : std_logic_vector(63 downto 0);
  signal sync_a        : std_logic_vector(7 downto 0);
  signal sync_b        : std_logic_vector(7 downto 0);
  signal sync_stb_a    : std_logic;
  signal sync_stb_b    : std_logic;
  signal endpoint_selected_a : std_logic;
  signal endpoint_selected_b : std_logic;
  signal mmcm0_locked_expected_a : std_logic;
  signal mmcm0_locked_expected_b : std_logic;
  signal mmcm1_locked_expected_a : std_logic;
  signal mmcm1_locked_expected_b : std_logic;
  signal endpoint_ready_expected_a : std_logic;
  signal endpoint_ready_expected_b : std_logic;
  signal endpoint_state_expected_a : std_logic_vector(3 downto 0);
  signal endpoint_state_expected_b : std_logic_vector(3 downto 0);
  signal timestamp_expected_a : std_logic_vector(63 downto 0);
  signal timestamp_expected_b : std_logic_vector(63 downto 0);
  signal sync_expected_a : std_logic_vector(7 downto 0);
  signal sync_expected_b : std_logic_vector(7 downto 0);
  signal sync_stb_expected_a : std_logic;
  signal sync_stb_expected_b : std_logic;
begin
  dut_a : entity work.timing_subsystem_boundary
    port map (
      clk_axi       => clk_axi,
      resetn_axi    => resetn_axi,
      timing_ctrl_i => timing_ctrl_a,
      timing_stat_o => timing_stat_a,
      timestamp_o   => timestamp_a,
      sync_o        => sync_a,
      sync_stb_o    => sync_stb_a
    );

  dut_b : entity work.timing_subsystem_boundary
    port map (
      clk_axi       => clk_axi,
      resetn_axi    => resetn_axi,
      timing_ctrl_i => timing_ctrl_b,
      timing_stat_o => timing_stat_b,
      timestamp_o   => timestamp_b,
      sync_o        => sync_b,
      sync_stb_o    => sync_stb_b
    );

  endpoint_selected_a <= resetn_axi and timing_ctrl_a.use_endpoint_clock;
  endpoint_selected_b <= resetn_axi and timing_ctrl_b.use_endpoint_clock;

  mmcm0_locked_expected_a <= endpoint_selected_a and not timing_ctrl_a.mmcm0_reset;
  mmcm0_locked_expected_b <= endpoint_selected_b and not timing_ctrl_b.mmcm0_reset;
  mmcm1_locked_expected_a <= endpoint_selected_a and not timing_ctrl_a.mmcm1_reset;
  mmcm1_locked_expected_b <= endpoint_selected_b and not timing_ctrl_b.mmcm1_reset;
  endpoint_ready_expected_a <= mmcm0_locked_expected_a and mmcm1_locked_expected_a and not timing_ctrl_a.endpoint_reset;
  endpoint_ready_expected_b <= mmcm0_locked_expected_b and mmcm1_locked_expected_b and not timing_ctrl_b.endpoint_reset;
  endpoint_state_expected_a <= ENDPOINT_STATE_READY_C
                               when endpoint_ready_expected_a = '1'
                               else ENDPOINT_STATE_HELD_RESET_C
                               when endpoint_selected_a = '1' and timing_ctrl_a.endpoint_reset = '1'
                               else ENDPOINT_STATE_WAIT_LOCK_C
                               when endpoint_selected_a = '1'
                               else (others => '0');
  endpoint_state_expected_b <= ENDPOINT_STATE_READY_C
                               when endpoint_ready_expected_b = '1'
                               else ENDPOINT_STATE_HELD_RESET_C
                               when endpoint_selected_b = '1' and timing_ctrl_b.endpoint_reset = '1'
                               else ENDPOINT_STATE_WAIT_LOCK_C
                               when endpoint_selected_b = '1'
                               else (others => '0');
  timestamp_expected_a <= timing_ctrl_a.endpoint_addr &
                          timing_ctrl_a.endpoint_addr &
                          timing_ctrl_a.endpoint_addr &
                          timing_ctrl_a.endpoint_addr
                          when endpoint_ready_expected_a = '1'
                          else (others => '0');
  timestamp_expected_b <= timing_ctrl_b.endpoint_addr &
                          timing_ctrl_b.endpoint_addr &
                          timing_ctrl_b.endpoint_addr &
                          timing_ctrl_b.endpoint_addr
                          when endpoint_ready_expected_b = '1'
                          else (others => '0');
  sync_stb_expected_a <= endpoint_ready_expected_a and timing_ctrl_a.endpoint_addr(0);
  sync_stb_expected_b <= endpoint_ready_expected_b and timing_ctrl_b.endpoint_addr(0);
  sync_expected_a <= timing_ctrl_a.endpoint_addr(7 downto 0)
                     when sync_stb_expected_a = '1'
                     else (others => '0');
  sync_expected_b <= timing_ctrl_b.endpoint_addr(7 downto 0)
                     when sync_stb_expected_b = '1'
                     else (others => '0');

  assert timing_stat_a.mmcm0_locked = mmcm0_locked_expected_a
    report "timing subsystem mmcm0 lock must require endpoint selection, reset release, and local MMCM release"
    severity failure;

  assert timing_stat_b.mmcm0_locked = mmcm0_locked_expected_b
    report "timing subsystem mmcm0 lock must follow the same endpoint-selection contract for any control payload"
    severity failure;

  assert timing_stat_a.mmcm1_locked = mmcm1_locked_expected_a
    report "timing subsystem mmcm1 lock must require endpoint selection, reset release, and local MMCM release"
    severity failure;

  assert timing_stat_b.mmcm1_locked = mmcm1_locked_expected_b
    report "timing subsystem mmcm1 lock must follow the same endpoint-selection contract for any control payload"
    severity failure;

  assert timing_stat_a.endpoint_ready = endpoint_ready_expected_a
    report "timing subsystem endpoint readiness must require both MMCMs plus endpoint reset release"
    severity failure;

  assert timing_stat_b.endpoint_ready = endpoint_ready_expected_b
    report "timing subsystem endpoint readiness must follow the same lock-and-reset contract for any control payload"
    severity failure;

  assert timing_stat_a.endpoint_state = endpoint_state_expected_a
    report "timing subsystem endpoint state must distinguish held-reset, wait-lock, ready, and neutral-local cases"
    severity failure;

  assert timing_stat_b.endpoint_state = endpoint_state_expected_b
    report "timing subsystem endpoint state must follow the same deterministic control-state contract for any control payload"
    severity failure;

  assert timing_stat_a.timestamp_valid = endpoint_ready_expected_a
    report "timing subsystem timestamp_valid must rise only with endpoint readiness"
    severity failure;

  assert timing_stat_b.timestamp_valid = endpoint_ready_expected_b
    report "timing subsystem timestamp_valid must follow the same readiness contract for any control payload"
    severity failure;

  assert timestamp_a = timestamp_expected_a
    report "timing subsystem timestamp must expose the endpoint address image only once endpoint timing is ready"
    severity failure;

  assert timestamp_b = timestamp_expected_b
    report "timing subsystem timestamp must follow the same ready-gated address image contract for any control payload"
    severity failure;

  assert sync_a = sync_expected_a
    report "timing subsystem sync bus must stay zero until the ready-gated sync condition is modeled"
    severity failure;

  assert sync_b = sync_expected_b
    report "timing subsystem sync bus must follow the same ready-gated low-byte contract for any control payload"
    severity failure;

  assert sync_stb_a = sync_stb_expected_a
    report "timing subsystem sync strobe must only assert for ready endpoint timing with an enabled sync pattern"
    severity failure;

  assert sync_stb_b = sync_stb_expected_b
    report "timing subsystem sync strobe must follow the same ready-gated sync contract for any control payload"
    severity failure;
end architecture formal;
