library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;

entity afe_capture_slice is
  port (
    afe_p_i           : in  std_logic_vector(8 downto 0);
    afe_n_i           : in  std_logic_vector(8 downto 0);
    clk500_i          : in  std_logic;
    clk125_i          : in  std_logic;
    clock_i           : in  std_logic;
    idelay_load_i     : in  std_logic;
    idelay_tap_i      : in  std_logic_vector(8 downto 0);
    idelay_en_vtc_i   : in  std_logic;
    iserdes_reset_i   : in  std_logic;
    iserdes_bitslip_i : in  std_logic_vector(3 downto 0);
    dout_o            : out array_9x16_type
  );
end entity afe_capture_slice;

architecture rtl of afe_capture_slice is
begin
  gen_lane : for lane in 8 downto 0 generate
    febit3_inst : entity work.febit3
      port map (
        din_p             => afe_p_i(lane),
        din_n             => afe_n_i(lane),
        clock             => clock_i,
        clk500            => clk500_i,
        clk125            => clk125_i,
        idelay_load       => idelay_load_i,
        idelay_cntvaluein => idelay_tap_i,
        idelay_en_vtc     => idelay_en_vtc_i,
        iserdes_reset     => iserdes_reset_i,
        iserdes_bitslip   => iserdes_bitslip_i,
        dout              => dout_o(lane)
      );
  end generate gen_lane;
end architecture rtl;
