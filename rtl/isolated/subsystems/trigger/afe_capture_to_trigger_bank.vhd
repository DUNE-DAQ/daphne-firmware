library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity afe_capture_to_trigger_bank is
  generic (
    CHANNELS_PER_AFE_G : positive := 8
  );
  port (
    afe_dout_i        : in  array_9x16_type;
    trigger_samples_o : out sample14_array_t(0 to CHANNELS_PER_AFE_G - 1)
  );
end entity afe_capture_to_trigger_bank;

architecture rtl of afe_capture_to_trigger_bank is
begin
  gen_channel : for ch_idx in 0 to CHANNELS_PER_AFE_G - 1 generate
  begin
    -- Match the legacy selftrig_core contract: discard the frame lane (8)
    -- and truncate 16-bit frontend samples down to the 14-bit trigger path.
    trigger_samples_o(ch_idx) <= afe_dout_i(ch_idx)(15 downto 2);
  end generate gen_channel;
end architecture rtl;
