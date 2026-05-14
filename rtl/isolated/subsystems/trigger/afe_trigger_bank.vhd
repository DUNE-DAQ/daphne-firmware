library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity afe_trigger_bank is
  generic (
    CHANNEL_COUNT_G             : positive := 8;
    ENABLE_AFE_COMPENSATOR_G    : boolean := true;
    ENABLE_INVERT_CONTROL_G     : boolean := true;
    FIXED_CFD_G                 : boolean := false;
    USE_COMPACT_DESCRIPTOR_G    : boolean := false;
    TRIGGER_LATENCY_G           : natural := 64
  );
  port (
    clock_i               : in  std_logic;
    reset_i               : in  std_logic;
    timestamp_i           : in  std_logic_vector(63 downto 0);
    din_i                 : in  sample14_array_t(0 to CHANNEL_COUNT_G - 1);
    trigger_control_i     : in  trigger_xcorr_control_array_t(0 to CHANNEL_COUNT_G - 1);
    descriptor_control_i  : in  peak_descriptor_control_array_t(0 to CHANNEL_COUNT_G - 1);
    trigger_result_o      : out trigger_xcorr_result_array_t(0 to CHANNEL_COUNT_G - 1);
    descriptor_result_o   : out peak_descriptor_result_array_t(0 to CHANNEL_COUNT_G - 1);
    descriptor_trailer_o  : out peak_descriptor_trailer_bank_t(0 to CHANNEL_COUNT_G - 1)
  );
end entity afe_trigger_bank;

architecture rtl of afe_trigger_bank is
  signal trigger_result_s     : trigger_xcorr_result_array_t(0 to CHANNEL_COUNT_G - 1);
  signal descriptor_result_s  : peak_descriptor_result_array_t(0 to CHANNEL_COUNT_G - 1);
  signal descriptor_trailer_s : peak_descriptor_trailer_bank_t(0 to CHANNEL_COUNT_G - 1);
begin
  gen_channel : for idx in 0 to CHANNEL_COUNT_G - 1 generate
    trigger_inst : entity work.self_trigger_xcorr_channel
      generic map (
        ENABLE_AFE_COMPENSATOR_G => ENABLE_AFE_COMPENSATOR_G,
        ENABLE_INVERT_CONTROL_G  => ENABLE_INVERT_CONTROL_G,
        FIXED_CFD_G              => FIXED_CFD_G,
        TRIGGER_LATENCY_G        => TRIGGER_LATENCY_G
      )
      port map (
        clock_i     => clock_i,
        reset_i     => reset_i,
        din_i       => din_i(idx),
        timestamp_i => timestamp_i,
        control_i   => trigger_control_i(idx),
        result_o    => trigger_result_s(idx)
      );

    descriptor_inst : entity work.peak_descriptor_channel
      generic map (
        USE_COMPACT_DESCRIPTOR_G => USE_COMPACT_DESCRIPTOR_G
      )
      port map (
        clock_i   => clock_i,
        reset_i   => reset_i,
        trigger_i => trigger_result_s(idx),
        control_i => descriptor_control_i(idx),
        result_o  => descriptor_result_s(idx),
        trailer_o => descriptor_trailer_s(idx)
      );
  end generate gen_channel;

  trigger_result_o     <= trigger_result_s;
  descriptor_result_o  <= descriptor_result_s;
  descriptor_trailer_o <= descriptor_trailer_s;
end architecture rtl;
