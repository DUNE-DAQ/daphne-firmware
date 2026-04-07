library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_selftrigger_inputs_bridge is
  generic (
    AFE_COUNT_G : positive range 1 to 5 := 5
  );
  port (
    afe_dout_i                : in  array_5x9x16_type;
    core_chan_enable_i        : in  std_logic_vector((AFE_COUNT_G * 8) - 1 downto 0);
    afe_comp_enable_i         : in  std_logic_vector((AFE_COUNT_G * 8) - 1 downto 0);
    invert_enable_i           : in  std_logic_vector((AFE_COUNT_G * 8) - 1 downto 0);
    threshold_xc_i            : in  slv28_array_t(0 to (AFE_COUNT_G * 8) - 1);
    adhoc_i                   : in  std_logic_vector(7 downto 0);
    filter_output_selector_i  : in  std_logic_vector(1 downto 0);
    ti_trigger_i              : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr_i         : in  std_logic;
    descriptor_config_i       : in  std_logic_vector(13 downto 0);
    signal_delay_i            : in  std_logic_vector(4 downto 0);
    reset_st_counters_i       : in  std_logic;
    trigger_samples_o         : out sample14_array_t(0 to (AFE_COUNT_G * 8) - 1);
    trigger_control_o         : out trigger_xcorr_control_array_t(0 to (AFE_COUNT_G * 8) - 1);
    descriptor_config_o       : out std_logic_vector(13 downto 0);
    signal_delay_o            : out std_logic_vector(4 downto 0);
    reset_st_counters_o       : out std_logic
  );
end entity legacy_selftrigger_inputs_bridge;

architecture rtl of legacy_selftrigger_inputs_bridge is
begin
  frontend_adapter_inst : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => AFE_COUNT_G
    )
    port map (
      afe_dout_i        => afe_dout_i,
      trigger_samples_o => trigger_samples_o
    );

  control_adapter_inst : entity work.trigger_control_adapter
    generic map (
      CHANNEL_COUNT_G => AFE_COUNT_G * 8
    )
    port map (
      core_chan_enable_i       => core_chan_enable_i,
      afe_comp_enable_i        => afe_comp_enable_i,
      invert_enable_i          => invert_enable_i,
      threshold_xc_i           => threshold_xc_i,
      adhoc_i                  => adhoc_i,
      filter_output_selector_i => filter_output_selector_i,
      ti_trigger_i             => ti_trigger_i,
      ti_trigger_stbr_i        => ti_trigger_stbr_i,
      descriptor_config_i      => descriptor_config_i,
      signal_delay_i           => signal_delay_i,
      reset_st_counters_i      => reset_st_counters_i,
      trigger_control_o        => trigger_control_o,
      descriptor_config_o      => descriptor_config_o,
      signal_delay_o           => signal_delay_o,
      reset_st_counters_o      => reset_st_counters_o
    );
end architecture rtl;
