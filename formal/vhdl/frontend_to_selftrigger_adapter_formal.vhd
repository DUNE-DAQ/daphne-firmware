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
  type board_to_pl_afe_map_t is array (0 to 4) of natural range 0 to 4;
  constant EXPECTED_BOARD_TO_PL_AFE_C : board_to_pl_afe_map_t := (0, 4, 3, 2, 1);
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

  gen_board_afe : for board_afe_idx in 0 to 4 generate
    gen_channel : for ch_idx in 0 to 7 generate
    begin
      assert trigger_samples_o((board_afe_idx * 8) + ch_idx) =
             afe_dout_i(EXPECTED_BOARD_TO_PL_AFE_C(board_afe_idx))(ch_idx)(15 downto 2)
        report "frontend-to-selftrigger adapter must map board AFEs to PL capture buses and truncate to 14 bits"
        severity failure;
    end generate gen_channel;
  end generate gen_board_afe;

  assert trigger_samples_o(0) = afe_dout_i(0)(0)(15 downto 2)
    report "board AFE0 must map from PL AFE0"
    severity failure;

  assert trigger_samples_o(8) = afe_dout_i(4)(0)(15 downto 2)
    report "board AFE1 must map from PL AFE4"
    severity failure;

  assert trigger_samples_o(16) = afe_dout_i(3)(0)(15 downto 2)
    report "board AFE2 must map from PL AFE3"
    severity failure;

  assert trigger_samples_o(24) = afe_dout_i(2)(0)(15 downto 2)
    report "board AFE3 must map from PL AFE2"
    severity failure;

  assert trigger_samples_o(32) = afe_dout_i(1)(0)(15 downto 2)
    report "board AFE4 must map from PL AFE1"
    severity failure;

  assert trigger_samples_o(7) = afe_dout_i(0)(7)(15 downto 2)
    report "board AFE0 must preserve its eighth data lane"
    severity failure;

  assert trigger_samples_o(15) = afe_dout_i(4)(7)(15 downto 2)
    report "board AFE1 must preserve its eighth data lane"
    severity failure;

  assert trigger_samples_o(23) = afe_dout_i(3)(7)(15 downto 2)
    report "board AFE2 must preserve its eighth data lane"
    severity failure;

  assert trigger_samples_o(31) = afe_dout_i(2)(7)(15 downto 2)
    report "board AFE3 must preserve its eighth data lane"
    severity failure;

  assert trigger_samples_o(39) = afe_dout_i(1)(7)(15 downto 2)
    report "board AFE4 must preserve its eighth data lane"
    severity failure;
end architecture formal;
