library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;

entity frontend_register_bank is
  port (
    clk_i               : in  std_logic;
    resetn_i            : in  std_logic;
    advance_i           : in  std_logic;
    tap_write_i         : in  std_logic_vector(4 downto 0);
    tap_value_i         : in  array_5x9_type;
    bitslip_write_i     : in  std_logic_vector(4 downto 0);
    bitslip_value_i     : in  array_5x4_type;
    idelay_tap_o        : out array_5x9_type;
    idelay_load_o       : out std_logic_vector(4 downto 0);
    iserdes_bitslip_o   : out array_5x4_type
  );
end entity frontend_register_bank;

architecture rtl of frontend_register_bank is
begin
  gen_afe_regs : for afe in 0 to 4 generate
    reg_slice_inst : entity work.frontend_register_slice
      port map (
        clk_i             => clk_i,
        resetn_i          => resetn_i,
        advance_i         => advance_i,
        tap_write_i       => tap_write_i(afe),
        tap_value_i       => tap_value_i(afe),
        bitslip_write_i   => bitslip_write_i(afe),
        bitslip_value_i   => bitslip_value_i(afe),
        idelay_tap_o      => idelay_tap_o(afe),
        idelay_load_o     => idelay_load_o(afe),
        iserdes_bitslip_o => iserdes_bitslip_o(afe)
      );
  end generate gen_afe_regs;
end architecture rtl;
