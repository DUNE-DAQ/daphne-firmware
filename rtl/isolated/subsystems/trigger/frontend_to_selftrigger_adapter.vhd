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
    signal trigger_samples_afe_s : sample14_array_t(0 to 7);
  begin
    afe_adapter_inst : entity work.afe_capture_to_trigger_bank
      port map (
        afe_dout_i        => afe_dout_i(afe_idx),
        trigger_samples_o => trigger_samples_afe_s
      );

    gen_channel : for ch_idx in 0 to 7 generate
    begin
      trigger_samples_o((afe_idx * 8) + ch_idx) <= trigger_samples_afe_s(ch_idx);
    end generate gen_channel;
  end generate gen_afe;
end architecture rtl;
