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
  descriptor_config_o <= descriptor_config_i;
  signal_delay_o      <= signal_delay_i;
  reset_st_counters_o <= reset_st_counters_i;

  gen_channels : for idx in 0 to CHANNEL_COUNT_G - 1 generate
  begin
    trigger_control_o(idx).enable                 <= core_chan_enable_i(idx);
    trigger_control_o(idx).afe_comp_enable        <= afe_comp_enable_i(idx);
    trigger_control_o(idx).invert_enable          <= invert_enable_i(idx);
    trigger_control_o(idx).filter_output_selector <= filter_output_selector_i;
    trigger_control_o(idx).threshold_xc           <= threshold_xc_i(idx);
    trigger_control_o(idx).adhoc                  <= adhoc_i;
    trigger_control_o(idx).ti_trigger             <= ti_trigger_i;
    trigger_control_o(idx).ti_trigger_stbr        <= ti_trigger_stbr_i;
  end generate gen_channels;
end architecture rtl;
