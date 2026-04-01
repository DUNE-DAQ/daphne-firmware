library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity afe_capture_to_trigger_bank_formal is
  port (
    afe_dout_i : in array_9x16_type
  );
end entity afe_capture_to_trigger_bank_formal;

architecture formal of afe_capture_to_trigger_bank_formal is
  signal trigger_samples_o : sample14_array_t(0 to 7);
begin
  dut : entity work.afe_capture_to_trigger_bank
    port map (
      afe_dout_i        => afe_dout_i,
      trigger_samples_o => trigger_samples_o
    );

  gen_channel : for ch_idx in 0 to 7 generate
  begin
    assert trigger_samples_o(ch_idx) = afe_dout_i(ch_idx)(15 downto 2)
      report "AFE capture adapter must preserve channel order and truncate to 14 bits"
      severity failure;
  end generate gen_channel;

  assert trigger_samples_o(0) = afe_dout_i(0)(15 downto 2)
    report "AFE capture adapter channel 0 must map from lane 0"
    severity failure;

  assert trigger_samples_o(7) = afe_dout_i(7)(15 downto 2)
    report "AFE capture adapter channel 7 must map from lane 7"
    severity failure;
end architecture formal;
