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
    idelay_load_i              : in  std_logic_vector(4 downto 0);
    idelay_load_clk125_o       : out std_logic_vector(4 downto 0);
    software_trig_axi_i        : in  std_logic;
    external_trig_axi_i        : in  std_logic;
    spy_trigger_source_axi_i   : in  std_logic_vector(1 downto 0);
    spy_trigger_inhibit_axi_i  : in  std_logic;
    software_trig_o            : out std_logic;
    external_trig_o            : out std_logic;
    spy_trigger_source_o       : out std_logic_vector(1 downto 0);
    spy_trigger_inhibit_o      : out std_logic;
    trig_o                     : out std_logic
  );
end entity frontend_common;

architecture rtl of frontend_common is
  signal clock_out_temp       : std_logic;
  signal idelayctrl_reset_500_meta : std_logic := '0';
  signal idelayctrl_reset_500_sync : std_logic := '0';
  signal idelay_load_clk125_meta   : std_logic_vector(4 downto 0) := (others => '0');
  signal idelay_load_clk125_sync   : std_logic_vector(4 downto 0) := (others => '0');
  signal software_trig_meta        : std_logic := '0';
  signal software_trig_reg         : std_logic := '0';
  signal external_trig_meta        : std_logic := '0';
  signal external_trig_reg         : std_logic := '0';
  signal spy_trigger_control_meta  : std_logic_vector(2 downto 0) := "011";
  signal spy_trigger_control_sync  : std_logic_vector(2 downto 0) := "011";
  signal spy_trigger_control_prev  : std_logic_vector(2 downto 0) := "011";
  signal spy_trigger_control_reg   : std_logic_vector(2 downto 0) := "011";

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of idelayctrl_reset_500_meta : signal is "TRUE";
  attribute ASYNC_REG of idelayctrl_reset_500_sync : signal is "TRUE";
  attribute ASYNC_REG of idelay_load_clk125_meta   : signal is "TRUE";
  attribute ASYNC_REG of idelay_load_clk125_sync   : signal is "TRUE";
  attribute ASYNC_REG of software_trig_meta        : signal is "TRUE";
  attribute ASYNC_REG of software_trig_reg         : signal is "TRUE";
  attribute ASYNC_REG of external_trig_meta        : signal is "TRUE";
  attribute ASYNC_REG of external_trig_reg         : signal is "TRUE";
  attribute ASYNC_REG of spy_trigger_control_meta  : signal is "TRUE";
  attribute ASYNC_REG of spy_trigger_control_sync  : signal is "TRUE";
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
      software_trig_meta <= software_trig_axi_i;
      software_trig_reg  <= software_trig_meta;
      external_trig_meta <= external_trig_axi_i;
      external_trig_reg  <= external_trig_meta;

      -- Synchronize the persistent control word as a bundled value and only
      -- publish it after two identical destination-domain samples. This keeps
      -- selector and inhibit changes coherent at the spy-trigger boundary.
      spy_trigger_control_meta <= spy_trigger_inhibit_axi_i & spy_trigger_source_axi_i;
      spy_trigger_control_sync <= spy_trigger_control_meta;
      spy_trigger_control_prev <= spy_trigger_control_sync;
      if spy_trigger_control_sync = spy_trigger_control_prev then
        spy_trigger_control_reg <= spy_trigger_control_sync;
      end if;
    end if;
  end process clock_resync_proc;

  idelayctrl_inst : IDELAYCTRL
    generic map (
      SIM_DEVICE => "ULTRASCALE_PLUS"
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
  software_trig_o       <= software_trig_reg;
  external_trig_o       <= external_trig_reg;
  spy_trigger_source_o  <= spy_trigger_control_reg(1 downto 0);
  spy_trigger_inhibit_o <= spy_trigger_control_reg(2);
  trig_o                <= software_trig_reg or external_trig_reg;
end architecture rtl;
