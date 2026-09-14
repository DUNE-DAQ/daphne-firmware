library ieee;
use ieee.std_logic_1164.all;
use work.common_stfc_pkg.all;

entity byte_reverse_tb is
end entity;

architecture test of byte_reverse_tb is
begin
  process
    variable mm_tx : std_logic_vector(185 downto 0) := (others => '0');
    variable ascending_word : std_logic_vector(10 to 41) := x"12345678";
  begin
    assert byte_reverse(x"12345678") = x"78563412" severity failure;
    assert byte_reverse(ascending_word) = x"78563412" severity failure;
    -- Exercise the actual nonzero-based Hermes destination-address slices.
    mm_tx(185 downto 138) := x"0123456789AB";
    mm_tx(137 downto 106) := x"C0A80102";
    mm_tx(105 downto 90) := x"1234";
    assert byte_reverse(mm_tx(169 downto 138)) &
           byte_reverse(mm_tx(185 downto 170)) = x"AB8967452301"
      severity failure;
    assert byte_reverse(mm_tx(137 downto 106)) = x"0201A8C0" severity failure;
    assert byte_reverse(mm_tx(105 downto 90)) = x"3412" severity failure;
    report "byte_reverse_tb PASS" severity note;
    wait;
  end process;
end architecture;
