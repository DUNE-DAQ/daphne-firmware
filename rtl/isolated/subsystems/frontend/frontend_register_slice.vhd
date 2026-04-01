library ieee;
use ieee.std_logic_1164.all;

entity frontend_register_slice is
  port (
    clk_i              : in  std_logic;
    resetn_i           : in  std_logic;
    advance_i          : in  std_logic;
    tap_write_i        : in  std_logic;
    tap_value_i        : in  std_logic_vector(8 downto 0);
    bitslip_write_i    : in  std_logic;
    bitslip_value_i    : in  std_logic_vector(3 downto 0);
    idelay_tap_o       : out std_logic_vector(8 downto 0);
    idelay_load_o      : out std_logic;
    iserdes_bitslip_o  : out std_logic_vector(3 downto 0)
  );
end entity frontend_register_slice;

architecture rtl of frontend_register_slice is
  signal idelay_tap_reg       : std_logic_vector(8 downto 0) := (others => '0');
  signal iserdes_bitslip_reg  : std_logic_vector(3 downto 0) := (others => '0');
  signal idelay_load0_reg     : std_logic := '0';
  signal idelay_load1_reg     : std_logic := '0';
  signal idelay_load2_reg     : std_logic := '0';
begin
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if resetn_i = '0' then
        idelay_tap_reg      <= (others => '0');
        iserdes_bitslip_reg <= (others => '0');
        idelay_load0_reg    <= '0';
        idelay_load1_reg    <= '0';
        idelay_load2_reg    <= '0';
      elsif advance_i = '1' then
        idelay_load2_reg <= idelay_load1_reg or idelay_load0_reg;
        idelay_load1_reg <= idelay_load0_reg;
        idelay_load0_reg <= '0';
      else
        if tap_write_i = '1' then
          idelay_tap_reg   <= tap_value_i;
          idelay_load0_reg <= '1';
        end if;

        if bitslip_write_i = '1' then
          iserdes_bitslip_reg <= bitslip_value_i;
        end if;
      end if;
    end if;
  end process;

  idelay_tap_o      <= idelay_tap_reg;
  idelay_load_o     <= idelay_load2_reg;
  iserdes_bitslip_o <= iserdes_bitslip_reg;
end architecture rtl;
