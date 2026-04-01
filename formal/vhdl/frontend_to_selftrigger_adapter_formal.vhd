library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity frontend_to_selftrigger_adapter_formal is
  port (
    afe_dout_i : in array_5x9x16_type
  );
end entity frontend_to_selftrigger_adapter_formal;

architecture formal of frontend_to_selftrigger_adapter_formal is
  signal trigger_samples_o : sample14_array_t(0 to 39);
begin
  dut : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => 5
    )
    port map (
      afe_dout_i        => afe_dout_i,
      trigger_samples_o => trigger_samples_o
    );

  gen_afe : for afe_idx in 0 to 4 generate
    gen_channel : for ch_idx in 0 to 7 generate
    begin
      assert trigger_samples_o((afe_idx * 8) + ch_idx) =
             afe_dout_i(afe_idx)(ch_idx)(15 downto 2)
        report "frontend-to-selftrigger adapter must preserve channel order and truncate to 14 bits"
        severity failure;
    end generate gen_channel;
  end generate gen_afe;

  assert trigger_samples_o(0) = afe_dout_i(0)(0)(15 downto 2)
    report "adapter channel 0 must map from AFE0 channel 0"
    severity failure;

  assert trigger_samples_o(39) = afe_dout_i(4)(7)(15 downto 2)
    report "adapter channel 39 must map from AFE4 channel 7"
    severity failure;

  assert trigger_samples_o(16) = afe_dout_i(2)(0)(15 downto 2)
    report "adapter must keep the flattened channel order contiguous across AFEs"
    severity failure;

  assert trigger_samples_o(23) = afe_dout_i(2)(7)(15 downto 2)
    report "adapter must stop at the eighth data channel for each AFE"
    severity failure;
end architecture formal;
