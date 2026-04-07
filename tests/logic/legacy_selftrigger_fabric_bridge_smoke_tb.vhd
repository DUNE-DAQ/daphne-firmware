library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_selftrigger_fabric_bridge_smoke_tb is
end entity legacy_selftrigger_fabric_bridge_smoke_tb;

architecture tb of legacy_selftrigger_fabric_bridge_smoke_tb is
  constant AFE_COUNT_C     : positive := 1;
  constant CHANNEL_COUNT_C : positive := AFE_COUNT_C * 8;

  signal clock_s                  : std_logic := '0';
  signal reset_s                  : std_logic := '1';
  signal frontend_dout_s          : array_5x9x16_type := (others => (others => (others => '0')));
  signal core_chan_enable_s       : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := (others => '0');
  signal afe_comp_enable_s        : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := (others => '0');
  signal invert_enable_s          : std_logic_vector(CHANNEL_COUNT_C - 1 downto 0) := (others => '0');
  signal threshold_xc_s           : slv28_array_t(0 to CHANNEL_COUNT_C - 1);
  signal adhoc_s                  : std_logic_vector(7 downto 0) := (others => '0');
  signal filter_output_selector_s : std_logic_vector(1 downto 0) := (others => '0');
  signal ti_trigger_s             : std_logic_vector(7 downto 0) := (others => '0');
  signal ti_trigger_stbr_s        : std_logic := '0';
  signal descriptor_config_s      : std_logic_vector(13 downto 0) := (others => '0');
  signal signal_delay_s           : std_logic_vector(4 downto 0) := (others => '0');
  signal reset_st_counters_s      : std_logic := '0';
  signal force_trigger_s          : std_logic := '0';
  signal timestamp_s              : std_logic_vector(63 downto 0) := (others => '0');
  signal version_s                : std_logic_vector(3 downto 0) := (others => '0');
  signal rd_en_s                  : std_logic_array_t(0 to CHANNEL_COUNT_C - 1) := (others => '0');
  signal trigger_result_s         : trigger_xcorr_result_array_t(0 to CHANNEL_COUNT_C - 1);
  signal descriptor_result_s      : peak_descriptor_result_array_t(0 to CHANNEL_COUNT_C - 1);
  signal record_count_s           : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal full_count_s             : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal busy_count_s             : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal trigger_count_s          : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal packet_count_s           : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal delayed_sample_s         : sample14_array_t(0 to CHANNEL_COUNT_C - 1);
  signal ready_s                  : std_logic_array_t(0 to CHANNEL_COUNT_C - 1);
  signal dout_s                   : slv72_array_t(0 to CHANNEL_COUNT_C - 1);
begin
  clock_s <= not clock_s after 8 ns;

  dut : entity work.legacy_selftrigger_fabric_bridge
    generic map (
      AFE_COUNT_G => AFE_COUNT_C
    )
    port map (
      clock_i                  => clock_s,
      reset_i                  => reset_s,
      frontend_dout_i          => frontend_dout_s,
      core_chan_enable_i       => core_chan_enable_s,
      afe_comp_enable_i        => afe_comp_enable_s,
      invert_enable_i          => invert_enable_s,
      threshold_xc_i           => threshold_xc_s,
      adhoc_i                  => adhoc_s,
      filter_output_selector_i => filter_output_selector_s,
      ti_trigger_i             => ti_trigger_s,
      ti_trigger_stbr_i        => ti_trigger_stbr_s,
      descriptor_config_i      => descriptor_config_s,
      signal_delay_i           => signal_delay_s,
      reset_st_counters_i      => reset_st_counters_s,
      force_trigger_i          => force_trigger_s,
      timestamp_i              => timestamp_s,
      version_i                => version_s,
      rd_en_i                  => rd_en_s,
      trigger_result_o         => trigger_result_s,
      descriptor_result_o      => descriptor_result_s,
      record_count_o           => record_count_s,
      full_count_o             => full_count_s,
      busy_count_o             => busy_count_s,
      trigger_count_o          => trigger_count_s,
      packet_count_o           => packet_count_s,
      delayed_sample_o         => delayed_sample_s,
      ready_o                  => ready_s,
      dout_o                   => dout_s
    );

  stimulus : process
  begin
    for idx in 0 to CHANNEL_COUNT_C - 1 loop
      threshold_xc_s(idx) <= (others => '1');
      frontend_dout_s(0)(idx) <= std_logic_vector(to_unsigned(idx, 16));
    end loop;

    wait for 40 ns;
    reset_s <= '0';
    wait for 160 ns;
    assert true report "legacy selftrigger fabric bridge smoke completed" severity note;
    stop;
    wait;
  end process;
end architecture tb;
