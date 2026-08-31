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
  type board_to_pl_afe_map_t is array (0 to 4) of natural range 0 to 4;

  -- The DAPHNE board labels its AFEs in the opposite order from the PL capture
  -- buses after AFE0.  Keep every downstream self-trigger channel in canonical
  -- board order so channel controls, counters, and packet identifiers all refer
  -- to the same physical input.
  constant BOARD_TO_PL_AFE_C : board_to_pl_afe_map_t := (0, 4, 3, 2, 1);
begin
  gen_board_afe : for board_afe_idx in 0 to AFE_COUNT_G - 1 generate
    constant PL_AFE_IDX_C : natural range 0 to 4 := BOARD_TO_PL_AFE_C(board_afe_idx);
    signal trigger_samples_afe_s : sample14_array_t(0 to 7);
  begin
    afe_adapter_inst : entity work.afe_capture_to_trigger_bank
      port map (
        afe_dout_i        => afe_dout_i(PL_AFE_IDX_C),
        trigger_samples_o => trigger_samples_afe_s
      );

    gen_channel : for ch_idx in 0 to 7 generate
    begin
      trigger_samples_o((board_afe_idx * 8) + ch_idx) <= trigger_samples_afe_s(ch_idx);
    end generate gen_channel;
  end generate gen_board_afe;
end architecture rtl;
