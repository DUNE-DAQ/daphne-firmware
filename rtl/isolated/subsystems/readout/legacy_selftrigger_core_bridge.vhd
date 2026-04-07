library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_selftrigger_core_bridge is
  port(
      clock: in std_logic;
      reset: in std_logic;
      reset_st_counters: in std_logic;
      version: in std_logic_vector(3 downto 0);
      filter_output_selector: in std_logic_vector(1 downto 0);
      afe_comp_enable: in std_logic_vector(39 downto 0);
      invert_enable: in std_logic_vector(39 downto 0);
      st_config: in std_logic_vector(13 downto 0);
      signal_delay: in std_logic_vector(4 downto 0);
      timestamp: in std_logic_vector(63 downto 0);
      forcetrig: in std_logic;
      enable: in std_logic_vector(39 downto 0);
      st_trigger_signal: out std_logic_vector(39 downto 0);
      adhoc: in std_logic_vector(7 downto 0);
      ti_trigger: in std_logic_vector(7 downto 0);
      ti_trigger_stbr: in std_logic;
      din: in array_5x9x16_type;
      dout: out array_2x64_type;
      afe_dat_filtered: out array_40x14_type;
      valid: out std_logic_vector(1 downto 0);
      last:  out std_logic_vector(1 downto 0);
      AXI_IN: in AXILITE_INREC;
      AXI_OUT: out AXILITE_OUTREC
  );
end legacy_selftrigger_core_bridge;

architecture rtl of legacy_selftrigger_core_bridge is
  signal threshold_xc: slv28_array_t(0 to 39);
  signal TCount: slv64_array_t(0 to 39);
  signal PCount: slv64_array_t(0 to 39);
  signal record_count: slv64_array_t(0 to 39);
  signal full_count: slv64_array_t(0 to 39);
  signal busy_count: slv64_array_t(0 to 39);
  signal trigger_result: trigger_xcorr_result_array_t(0 to 39);
  signal ready: std_logic_array_t(0 to 39);
  signal rd_en: std_logic_array_t(0 to 39);
  signal fabric_dout: slv72_array_t(0 to 39);
begin
  gen_legacy_monitor_outputs : for idx in 0 to 39 generate
  begin
    st_trigger_signal(idx) <= trigger_result(idx).trigger_pulse;
    afe_dat_filtered(idx)  <= trigger_result(idx).monitor_sample;
  end generate gen_legacy_monitor_outputs;

  legacy_selftrigger_fabric_bridge_inst : entity work.legacy_selftrigger_fabric_bridge
    port map (
      clock_i => clock,
      reset_i => reset,
      frontend_dout_i => din,
      core_chan_enable_i => enable,
      afe_comp_enable_i => afe_comp_enable,
      invert_enable_i => invert_enable,
      threshold_xc_i => threshold_xc,
      adhoc_i => adhoc,
      filter_output_selector_i => filter_output_selector,
      ti_trigger_i => ti_trigger,
      ti_trigger_stbr_i => ti_trigger_stbr,
      descriptor_config_i => st_config,
      signal_delay_i => signal_delay,
      reset_st_counters_i => reset_st_counters,
      force_trigger_i => forcetrig,
      timestamp_i => timestamp,
      version_i => version,
      rd_en_i => rd_en,
      trigger_result_o => trigger_result,
      descriptor_result_o => open,
      record_count_o => record_count,
      full_count_o => full_count,
      busy_count_o => busy_count,
      trigger_count_o => TCount,
      packet_count_o => PCount,
      delayed_sample_o => open,
      ready_o => ready,
      dout_o => fabric_dout
    );

  legacy_two_lane_readout_mux_inst : entity work.legacy_two_lane_readout_mux
    port map (
      clock_i => clock,
      reset_i => reset,
      ready_i => ready,
      dout_i => fabric_dout,
      rd_en_o => rd_en,
      dout_o => dout,
      valid_o => valid,
      last_o => last
    );

  legacy_selftrigger_register_bank_inst : entity work.legacy_selftrigger_register_bank
    port map (
      AXI_IN => AXI_IN,
      AXI_OUT => AXI_OUT,
      threshold_xc_o => threshold_xc,
      record_count_i => record_count,
      full_count_i => full_count,
      busy_count_i => busy_count,
      tcount_i => TCount,
      pcount_i => PCount
    );
end rtl;
