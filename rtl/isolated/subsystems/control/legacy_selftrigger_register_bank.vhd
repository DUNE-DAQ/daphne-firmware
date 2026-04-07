library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_selftrigger_register_bank is
  generic (
    CHANNEL_COUNT_G : positive := 40
  );
  port (
    AXI_IN         : in  AXILITE_INREC;
    AXI_OUT        : out AXILITE_OUTREC;
    threshold_xc_o : out slv28_array_t(0 to CHANNEL_COUNT_G - 1);
    record_count_i : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    full_count_i   : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    busy_count_i   : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    tcount_i       : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    pcount_i       : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1)
  );
end entity legacy_selftrigger_register_bank;

architecture rtl of legacy_selftrigger_register_bank is
begin
  selftrigger_register_bank_inst : entity work.selftrigger_register_bank
    generic map (
      CHANNEL_COUNT_G => CHANNEL_COUNT_G
    )
    port map (
      AXI_IN         => AXI_IN,
      AXI_OUT        => AXI_OUT,
      threshold_xc_o => threshold_xc_o,
      record_count_i => record_count_i,
      full_count_i   => full_count_i,
      busy_count_i   => busy_count_i,
      tcount_i       => tcount_i,
      pcount_i       => pcount_i
    );
end architecture rtl;
