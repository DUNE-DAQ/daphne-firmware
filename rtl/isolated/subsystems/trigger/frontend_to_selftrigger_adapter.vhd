library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity frontend_to_selftrigger_adapter is
  generic (
    AFE_COUNT_G : positive range 1 to 5 := 5
  );
  port (
    afe_dout_i        : in  array_5x9x16_type;
    trigger_samples_o : out sample14_array_t(0 to (AFE_COUNT_G * 8) - 1)
  );
end entity frontend_to_selftrigger_adapter;

architecture rtl of frontend_to_selftrigger_adapter is
begin
  gen_afe : for afe_idx in 0 to AFE_COUNT_G - 1 generate
    gen_channel : for ch_idx in 0 to 7 generate
    begin
      -- Match the legacy selftrig_core contract: discard the frame lane (8)
      -- and truncate 16-bit frontend samples down to the 14-bit trigger path.
      trigger_samples_o((afe_idx * 8) + ch_idx) <= afe_dout_i(afe_idx)(ch_idx)(15 downto 2);
    end generate gen_channel;
  end generate gen_afe;
end architecture rtl;
