library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_two_lane_readout_mux_smoke_tb is
end entity legacy_two_lane_readout_mux_smoke_tb;

architecture tb of legacy_two_lane_readout_mux_smoke_tb is
  constant CHANNEL_COUNT_C     : positive := 40;
  constant LANE_COUNT_C        : positive := 2;
  constant CHANNELS_PER_LANE_C : positive := 20;

  signal clock_s : std_logic := '0';
  signal reset_s : std_logic := '1';
  signal ready_s : std_logic_array_t(0 to CHANNEL_COUNT_C - 1) := (others => '0');
  signal rd_en_s : std_logic_array_t(0 to CHANNEL_COUNT_C - 1);
  signal dout_s  : slv72_array_t(0 to CHANNEL_COUNT_C - 1) := (others => (others => '0'));
  signal data_s  : array_2x64_type;
  signal valid_s : std_logic_vector(LANE_COUNT_C - 1 downto 0);
  signal last_s  : std_logic_vector(LANE_COUNT_C - 1 downto 0);
begin
  clock_s <= not clock_s after 8 ns;

  dut : entity work.legacy_two_lane_readout_mux
    generic map (
      CHANNEL_COUNT_G     => CHANNEL_COUNT_C,
      LANE_COUNT_G        => LANE_COUNT_C,
      CHANNELS_PER_LANE_G => CHANNELS_PER_LANE_C
    )
    port map (
      clock_i => clock_s,
      reset_i => reset_s,
      ready_i => ready_s,
      dout_i  => dout_s,
      rd_en_o => rd_en_s,
      dout_o  => data_s,
      valid_o => valid_s,
      last_o  => last_s
    );

  stimulus : process
  begin
    dout_s(0)  <= X"ED0123456789ABCDEF";
    dout_s(20) <= X"EDFEDCBA9876543210";

    wait for 40 ns;
    reset_s <= '0';
    ready_s(0) <= '1';
    ready_s(20) <= '1';

    wait until rd_en_s(0) = '1';
    assert rd_en_s(0) = '1'
      report "lane 0 did not assert the expected read enable"
      severity failure;
    wait until rising_edge(clock_s) and valid_s(0) = '1';
    assert data_s(0) = X"0123456789ABCDEF"
      report "lane 0 did not emit the expected record payload"
      severity failure;

    wait until rising_edge(clock_s) and last_s(0) = '1';

    wait until rd_en_s(20) = '1';
    assert rd_en_s(20) = '1'
      report "lane 1 did not assert the expected read enable"
      severity failure;
    wait until rising_edge(clock_s) and valid_s(1) = '1';
    assert data_s(1) = X"FEDCBA9876543210"
      report "lane 1 did not emit the expected record payload"
      severity failure;

    wait until rising_edge(clock_s) and last_s(1) = '1';
    assert true report "legacy two lane readout mux smoke completed" severity note;
    stop;
    wait;
  end process;
end architecture tb;
