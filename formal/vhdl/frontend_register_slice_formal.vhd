library ieee;
use ieee.std_logic_1164.all;

entity frontend_register_slice_formal is
  port (
    clock_i          : in std_logic;
    resetn_i         : in std_logic;
    advance_i        : in std_logic;
    tap_write_i      : in std_logic;
    tap_value_i      : in std_logic_vector(8 downto 0);
    bitslip_write_i  : in std_logic;
    bitslip_value_i  : in std_logic_vector(3 downto 0)
  );
end entity frontend_register_slice_formal;

architecture formal of frontend_register_slice_formal is
  signal idelay_tap_s       : std_logic_vector(8 downto 0);
  signal idelay_load_s      : std_logic;
  signal iserdes_bitslip_s  : std_logic_vector(3 downto 0);

  signal model_tap_s        : std_logic_vector(8 downto 0) := (others => '0');
  signal model_bitslip_s    : std_logic_vector(3 downto 0) := (others => '0');
  signal model_load0_s      : std_logic := '0';
  signal model_load1_s      : std_logic := '0';
  signal model_load2_s      : std_logic := '0';
begin
  dut : entity work.frontend_register_slice
    port map (
      clk_i             => clock_i,
      resetn_i          => resetn_i,
      advance_i         => advance_i,
      tap_write_i       => tap_write_i,
      tap_value_i       => tap_value_i,
      bitslip_write_i   => bitslip_write_i,
      bitslip_value_i   => bitslip_value_i,
      idelay_tap_o      => idelay_tap_s,
      idelay_load_o     => idelay_load_s,
      iserdes_bitslip_o => iserdes_bitslip_s
    );

  model_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      if resetn_i = '0' then
        model_tap_s     <= (others => '0');
        model_bitslip_s <= (others => '0');
        model_load0_s   <= '0';
        model_load1_s   <= '0';
        model_load2_s   <= '0';
      elsif advance_i = '1' then
        model_load2_s <= model_load1_s or model_load0_s;
        model_load1_s <= model_load0_s;
        model_load0_s <= '0';
      else
        if tap_write_i = '1' then
          model_tap_s   <= tap_value_i;
          model_load0_s <= '1';
        end if;

        if bitslip_write_i = '1' then
          model_bitslip_s <= bitslip_value_i;
        end if;
      end if;
    end if;
  end process model_proc;

  assert idelay_tap_s = model_tap_s
    report "frontend_register_slice tap state diverged from the reference model"
    severity failure;

  assert iserdes_bitslip_s = model_bitslip_s
    report "frontend_register_slice bitslip state diverged from the reference model"
    severity failure;

  assert idelay_load_s = model_load2_s
    report "frontend_register_slice load pulse diverged from the reference model"
    severity failure;
end architecture formal;
