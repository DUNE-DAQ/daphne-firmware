library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity legacy_trigger_control_adapter is
  generic (
    CHANNEL_COUNT_G : positive := 40
  );
  port (
    core_chan_enable_i         : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    afe_comp_enable_i          : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    invert_enable_i            : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    threshold_xc_i             : in  slv28_array_t(0 to CHANNEL_COUNT_G - 1);
    adhoc_i                    : in  std_logic_vector(7 downto 0);
    filter_output_selector_i   : in  std_logic_vector(1 downto 0);
    ti_trigger_i               : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr_i          : in  std_logic;
    descriptor_config_i        : in  std_logic_vector(13 downto 0);
    signal_delay_i             : in  std_logic_vector(4 downto 0);
    reset_st_counters_i        : in  std_logic;
    trigger_control_o          : out trigger_xcorr_control_array_t(0 to CHANNEL_COUNT_G - 1);
    descriptor_config_o        : out std_logic_vector(13 downto 0);
    signal_delay_o             : out std_logic_vector(4 downto 0);
    reset_st_counters_o        : out std_logic
  );
end entity legacy_trigger_control_adapter;

architecture rtl of legacy_trigger_control_adapter is
begin
  trigger_control_adapter_inst : entity work.trigger_control_adapter
    generic map (
      CHANNEL_COUNT_G => CHANNEL_COUNT_G
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
