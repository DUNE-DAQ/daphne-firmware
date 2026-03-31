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
  signal timing_stat_a : timing_status_t;
  signal timing_stat_b : timing_status_t;
  signal timestamp_a   : std_logic_vector(63 downto 0);
  signal timestamp_b   : std_logic_vector(63 downto 0);
  signal sync_a        : std_logic_vector(7 downto 0);
  signal sync_b        : std_logic_vector(7 downto 0);
  signal sync_stb_a    : std_logic;
  signal sync_stb_b    : std_logic;
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

  assert timing_stat_a = TIMING_STATUS_NULL
    report "neutral timing subsystem must expose the null timing status record"
    severity failure;

  assert timing_stat_b = TIMING_STATUS_NULL
    report "timing status must remain neutral for arbitrary control inputs"
    severity failure;

  assert timestamp_a = (timestamp_a'range => '0')
    report "neutral timing subsystem must drive timestamp_o low"
    severity failure;

  assert timestamp_b = (timestamp_b'range => '0')
    report "timestamp output must remain input-independent while the boundary is neutral"
    severity failure;

  assert sync_a = (sync_a'range => '0')
    report "neutral timing subsystem must drive sync_o low"
    severity failure;

  assert sync_b = (sync_b'range => '0')
    report "sync output must remain input-independent while the boundary is neutral"
    severity failure;

  assert sync_stb_a = '0'
    report "neutral timing subsystem must keep sync_stb_o low"
    severity failure;

  assert sync_stb_b = '0'
    report "sync_stb_o must remain input-independent while the boundary is neutral"
    severity failure;

  assert timing_stat_a = timing_stat_b
    report "timing status must not depend on ignored timing control inputs"
    severity failure;

  assert timestamp_a = timestamp_b
    report "timestamp output must not depend on ignored timing control inputs"
    severity failure;

  assert sync_a = sync_b
    report "sync output must not depend on ignored timing control inputs"
    severity failure;

  assert sync_stb_a = sync_stb_b
    report "sync_strobe output must not depend on ignored timing control inputs"
    severity failure;
end architecture formal;
