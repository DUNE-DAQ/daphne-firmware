library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity frontend_common is
  port (
    afe_clk_p_o         : out std_logic;
    afe_clk_n_o         : out std_logic;
    clk500_i            : in  std_logic;
    clk125_i            : in  std_logic;
    clock_i             : in  std_logic;
    idelayctrl_reset_i  : in  std_logic;
    idelayctrl_ready_o  : out std_logic;
    idelay_load_i       : in  std_logic_vector(4 downto 0);
    idelay_load_clk125_o: out std_logic_vector(4 downto 0);
    trig_axi_i          : in  std_logic;
    trig_o              : out std_logic
  );
end entity frontend_common;

architecture rtl of frontend_common is
  signal clock_out_temp       : std_logic;
  signal idelayctrl_reset_500_meta : std_logic := '0';
  signal idelayctrl_reset_500_sync : std_logic := '0';
  signal idelay_load_clk125_meta   : std_logic_vector(4 downto 0) := (others => '0');
  signal idelay_load_clk125_sync   : std_logic_vector(4 downto 0) := (others => '0');
  signal trig_meta                 : std_logic := '0';
  signal trig_reg                  : std_logic := '0';

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of idelayctrl_reset_500_meta : signal is "TRUE";
  attribute ASYNC_REG of idelayctrl_reset_500_sync : signal is "TRUE";
  attribute ASYNC_REG of idelay_load_clk125_meta   : signal is "TRUE";
  attribute ASYNC_REG of idelay_load_clk125_sync   : signal is "TRUE";
  attribute ASYNC_REG of trig_meta                 : signal is "TRUE";
  attribute ASYNC_REG of trig_reg                  : signal is "TRUE";
begin
  idelayctrl_resync_proc : process(clk500_i)
  begin
    if rising_edge(clk500_i) then
      idelayctrl_reset_500_meta <= idelayctrl_reset_i;
      idelayctrl_reset_500_sync <= idelayctrl_reset_500_meta;
    end if;
  end process idelayctrl_resync_proc;

  clk125_resync_proc : process(clk125_i)
  begin
    if rising_edge(clk125_i) then
      idelay_load_clk125_meta <= idelay_load_i;
      idelay_load_clk125_sync <= idelay_load_clk125_meta;
    end if;
  end process clk125_resync_proc;

  clock_resync_proc : process(clock_i)
  begin
    if rising_edge(clock_i) then
      trig_meta <= trig_axi_i;
      trig_reg  <= trig_meta;
    end if;
  end process clock_resync_proc;

  idelayctrl_inst : IDELAYCTRL
    generic map (
      SIM_DEVICE => "ULTRASCALE"
    )
    port map (
      REFCLK => clk500_i,
      RST    => idelayctrl_reset_500_sync,
      RDY    => idelayctrl_ready_o
    );

  oddr_inst : ODDRE1
    generic map (
      SIM_DEVICE => "ULTRASCALE_PLUS"
    )
    port map (
      Q  => clock_out_temp,
      C  => clock_i,
      D1 => '1',
      D2 => '0',
      SR => '0'
    );

  obufds_inst : OBUFDS
    generic map (
      IOSTANDARD => "LVDS"
    )
    port map (
      I  => clock_out_temp,
      O  => afe_clk_p_o,
      OB => afe_clk_n_o
    );

  idelay_load_clk125_o <= idelay_load_clk125_sync;
  trig_o               <= trig_reg;
end architecture rtl;
