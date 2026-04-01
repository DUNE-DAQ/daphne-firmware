library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;

entity frontend_capture_bank is
  generic (
    AFE_COUNT_G : positive range 1 to 5 := 5
  );
  port (
    afe_p_i           : in  array_5x9_type;
    afe_n_i           : in  array_5x9_type;
    clk500_i          : in  std_logic;
    clk125_i          : in  std_logic;
    clock_i           : in  std_logic;
    idelay_load_i     : in  std_logic_vector(4 downto 0);
    idelay_tap_i      : in  array_5x9_type;
    idelay_en_vtc_i   : in  std_logic;
    iserdes_reset_i   : in  std_logic;
    iserdes_bitslip_i : in  array_5x4_type;
    dout_o            : out array_5x9x16_type
  );
end entity frontend_capture_bank;

architecture rtl of frontend_capture_bank is
begin
  gen_afe : for afe in 4 downto 0 generate
    active_afe_gen : if afe < AFE_COUNT_G generate
      afe_slice_inst : entity work.afe_capture_slice
        port map (
          afe_p_i           => afe_p_i(afe),
          afe_n_i           => afe_n_i(afe),
          clk500_i          => clk500_i,
          clk125_i          => clk125_i,
          clock_i           => clock_i,
          idelay_load_i     => idelay_load_i(afe),
          idelay_tap_i      => idelay_tap_i(afe),
          idelay_en_vtc_i   => idelay_en_vtc_i,
          iserdes_reset_i   => iserdes_reset_i,
          iserdes_bitslip_i => iserdes_bitslip_i(afe),
          dout_o            => dout_o(afe)
        );
    end generate active_afe_gen;

    inactive_afe_gen : if afe >= AFE_COUNT_G generate
      dout_o(afe) <= (others => (others => '0'));
    end generate inactive_afe_gen;
  end generate gen_afe;
end architecture rtl;
