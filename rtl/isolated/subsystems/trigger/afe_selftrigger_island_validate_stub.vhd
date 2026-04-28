library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity afe_selftrigger_island is
  generic (
    CHANNELS_PER_AFE_G : positive := 8;
    CHANNEL_ID_BASE_G  : natural  := 0
  );
  port (
    clock_i             : in  std_logic;
    reset_i             : in  std_logic;
    reset_st_counters_i : in  std_logic;
    timestamp_i         : in  std_logic_vector(63 downto 0);
    version_i           : in  std_logic_vector(3 downto 0);
    signal_delay_i      : in  std_logic_vector(4 downto 0);
    descriptor_config_i : in  std_logic_vector(13 downto 0);
    force_trigger_i     : in  std_logic;
    din_i               : in  sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
    trigger_control_i   : in  trigger_xcorr_control_array_t(0 to CHANNELS_PER_AFE_G - 1);
    trigger_result_o    : out trigger_xcorr_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
    descriptor_result_o : out peak_descriptor_result_array_t(0 to CHANNELS_PER_AFE_G - 1);
    record_count_o      : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    full_count_o        : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    busy_count_o        : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    trigger_count_o     : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    packet_count_o      : out slv64_array_t(0 to CHANNELS_PER_AFE_G - 1);
    delayed_sample_o    : out sample14_array_t(0 to CHANNELS_PER_AFE_G - 1);
    afe_ready_o         : out std_logic;
    afe_rd_en_i         : in  std_logic;
    afe_dout_o          : out std_logic_vector(71 downto 0);
    ready_o             : out std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    rd_en_i             : in  std_logic_array_t(0 to CHANNELS_PER_AFE_G - 1);
    dout_o              : out slv72_array_t(0 to CHANNELS_PER_AFE_G - 1)
  );
end entity afe_selftrigger_island;

architecture validate_stub of afe_selftrigger_island is
begin
  trigger_result_o    <= (others => TRIGGER_XCORR_RESULT_NULL);
  descriptor_result_o <= (others => PEAK_DESCRIPTOR_RESULT_NULL);
  record_count_o      <= (others => (others => '0'));
  full_count_o        <= (others => (others => '0'));
  busy_count_o        <= (others => (others => '0'));
  trigger_count_o     <= (others => (others => '0'));
  packet_count_o      <= (others => (others => '0'));
  delayed_sample_o    <= (others => (others => '0'));
  afe_ready_o         <= '0';
  afe_dout_o          <= (others => '0');
  ready_o             <= (others => '0');
  dout_o              <= (others => (others => '0'));
end architecture validate_stub;
