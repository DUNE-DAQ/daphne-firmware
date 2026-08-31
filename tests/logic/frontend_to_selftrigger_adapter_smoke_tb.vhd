library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity frontend_to_selftrigger_adapter_smoke_tb is
end entity frontend_to_selftrigger_adapter_smoke_tb;

architecture tb of frontend_to_selftrigger_adapter_smoke_tb is
  type board_to_pl_afe_map_t is array (0 to 4) of natural range 0 to 4;
  constant EXPECTED_BOARD_TO_PL_AFE_C : board_to_pl_afe_map_t := (0, 4, 3, 2, 1);

  signal afe_dout_s        : array_5x9x16_type := (others => (others => (others => '0')));
  signal trigger_samples_s : sample14_array_t(0 to 39);

  function capture_word(pl_afe : natural; lane : natural) return std_logic_vector is
    variable sample_value : natural;
  begin
    sample_value := ((pl_afe * 16) + lane + 1) * 4 + 3;
    return std_logic_vector(to_unsigned(sample_value, 16));
  end function capture_word;

  function expected_sample(pl_afe : natural; lane : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned((pl_afe * 16) + lane + 1, 14));
  end function expected_sample;
begin
  dut : entity work.frontend_to_selftrigger_adapter
    generic map (
      AFE_COUNT_G => 5
    )
    port map (
      afe_dout_i        => afe_dout_s,
      trigger_samples_o => trigger_samples_s
    );

  stimulus : process
  begin
    for pl_afe in 0 to 4 loop
      for lane in 0 to 8 loop
        afe_dout_s(pl_afe)(lane) <= capture_word(pl_afe, lane);
      end loop;
    end loop;

    wait for 1 ns;

    for board_afe in 0 to 4 loop
      for lane in 0 to 7 loop
        assert trigger_samples_s((board_afe * 8) + lane) =
               expected_sample(EXPECTED_BOARD_TO_PL_AFE_C(board_afe), lane)
          report "board AFE " & integer'image(board_afe) &
                 " channel " & integer'image(lane) &
                 " did not map from PL AFE " &
                 integer'image(EXPECTED_BOARD_TO_PL_AFE_C(board_afe))
          severity failure;
      end loop;
    end loop;

    -- Keep one explicit assertion per AFE so the physical permutation remains
    -- visible even if the exhaustive loop above is later refactored.
    assert trigger_samples_s(0) = expected_sample(0, 0)
      report "board AFE0 must sample PL AFE0" severity failure;
    assert trigger_samples_s(8) = expected_sample(4, 0)
      report "board AFE1 must sample PL AFE4" severity failure;
    assert trigger_samples_s(16) = expected_sample(3, 0)
      report "board AFE2 must sample PL AFE3" severity failure;
    assert trigger_samples_s(24) = expected_sample(2, 0)
      report "board AFE3 must sample PL AFE2" severity failure;
    assert trigger_samples_s(32) = expected_sample(1, 0)
      report "board AFE4 must sample PL AFE1" severity failure;

    report "frontend_to_selftrigger_adapter_smoke_tb passed" severity note;
    wait;
  end process stimulus;
end architecture tb;
