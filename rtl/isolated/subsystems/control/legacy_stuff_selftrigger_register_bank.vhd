library ieee;
use ieee.std_logic_1164.all;

use work.daphne_package.all;

entity legacy_stuff_selftrigger_register_bank is
  port (
    clk                      : in  std_logic;
    resetn                   : in  std_logic;
    reg_wren_i               : in  std_logic;
    reg_addr_i               : in  std_logic_vector(6 downto 0);
    reg_wdata_i              : in  std_logic_vector(31 downto 0);
    reg_raddr_i              : in  std_logic_vector(6 downto 0);
    reg_rdata_o              : out std_logic_vector(31 downto 0);
    reg_rhit_o               : out std_logic;
    core_chan_enable_o       : out std_logic_vector(39 downto 0);
    adhoc_o                  : out std_logic_vector(7 downto 0);
    filter_output_selector_o : out std_logic_vector(1 downto 0);
    afe_comp_enable_o        : out std_logic_vector(39 downto 0);
    invert_enable_o          : out std_logic_vector(39 downto 0);
    st_config_o              : out std_logic_vector(13 downto 0);
    signal_delay_o           : out std_logic_vector(4 downto 0);
    reset_st_counters_o      : out std_logic
  );
end entity legacy_stuff_selftrigger_register_bank;

architecture rtl of legacy_stuff_selftrigger_register_bank is
  constant CORE_EN_LO_OFFSET : std_logic_vector(6 downto 0) := "0100000";
  constant CORE_EN_HI_OFFSET : std_logic_vector(6 downto 0) := "0100100";
  constant ST_ADHOC_OFFSET : std_logic_vector(6 downto 0) := "0101000";
  constant ST_CONFIG_OFFSET : std_logic_vector(6 downto 0) := "0101100";
  constant ST_DELAY_OFFSET : std_logic_vector(6 downto 0) := "0110000";
  constant ST_FILTER_OUTPUT_SEL_OFFSET : std_logic_vector(6 downto 0) := "0110100";
  constant ST_RESET_COUNTERS_OFFSET : std_logic_vector(6 downto 0) := "0111000";
  constant ST_AFE_COMP_ENABLE_LO_OFFSET : std_logic_vector(6 downto 0) := "0111100";
  constant ST_AFE_COMP_ENABLE_HI_OFFSET : std_logic_vector(6 downto 0) := "1000000";
  constant ST_INVERT_ENABLE_LO_OFFSET : std_logic_vector(6 downto 0) := "1000100";
  constant ST_INVERT_ENABLE_HI_OFFSET : std_logic_vector(6 downto 0) := "1001000";

  signal core_enable_reg : std_logic_vector(39 downto 0) := DEFAULT_core_enable;
  signal adhoc_reg : std_logic_vector(7 downto 0) := DEFAULT_st_adhoc_command;
  signal reset_st_counters_reg : std_logic := '0';
  signal signal_delay_reg : std_logic_vector(4 downto 0) := DEFAULT_st_config_command(20 downto 16);
  signal st_config_reg : std_logic_vector(13 downto 0) := DEFAULT_st_config_command(15 downto 2);
  signal filter_output_selector_reg : std_logic_vector(1 downto 0) := DEFAULT_st_config_command(1 downto 0);
  signal afe_comp_enable_reg : std_logic_vector(39 downto 0) := DEFAULT_st_comp_command;
  signal invert_enable_reg : std_logic_vector(39 downto 0) := DEFAULT_st_invert_command;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if resetn = '0' then
        core_enable_reg <= DEFAULT_core_enable;
        adhoc_reg <= DEFAULT_st_adhoc_command;
        signal_delay_reg <= DEFAULT_st_config_command(20 downto 16);
        st_config_reg <= DEFAULT_st_config_command(15 downto 2);
        filter_output_selector_reg <= DEFAULT_st_config_command(1 downto 0);
        reset_st_counters_reg <= '0';
        afe_comp_enable_reg <= DEFAULT_st_comp_command;
        invert_enable_reg <= DEFAULT_st_invert_command;
      elsif reg_wren_i = '1' then
        case reg_addr_i is
          when CORE_EN_LO_OFFSET =>
            core_enable_reg(31 downto 0) <= reg_wdata_i(31 downto 0);
          when CORE_EN_HI_OFFSET =>
            core_enable_reg(39 downto 32) <= reg_wdata_i(7 downto 0);
          when ST_ADHOC_OFFSET =>
            adhoc_reg <= reg_wdata_i(7 downto 0);
          when ST_CONFIG_OFFSET =>
            st_config_reg <= reg_wdata_i(13 downto 0);
          when ST_DELAY_OFFSET =>
            signal_delay_reg <= reg_wdata_i(4 downto 0);
          when ST_FILTER_OUTPUT_SEL_OFFSET =>
            filter_output_selector_reg <= reg_wdata_i(1 downto 0);
          when ST_RESET_COUNTERS_OFFSET =>
            reset_st_counters_reg <= reg_wdata_i(0);
          when ST_AFE_COMP_ENABLE_LO_OFFSET =>
            afe_comp_enable_reg(31 downto 0) <= reg_wdata_i(31 downto 0);
          when ST_AFE_COMP_ENABLE_HI_OFFSET =>
            afe_comp_enable_reg(39 downto 32) <= reg_wdata_i(7 downto 0);
          when ST_INVERT_ENABLE_LO_OFFSET =>
            invert_enable_reg(31 downto 0) <= reg_wdata_i(31 downto 0);
          when ST_INVERT_ENABLE_HI_OFFSET =>
            invert_enable_reg(39 downto 32) <= reg_wdata_i(7 downto 0);
          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  process (all)
  begin
    reg_rhit_o <= '1';
    case reg_raddr_i is
      when CORE_EN_LO_OFFSET =>
        reg_rdata_o <= core_enable_reg(31 downto 0);
      when CORE_EN_HI_OFFSET =>
        reg_rdata_o <= X"000000" & core_enable_reg(39 downto 32);
      when ST_ADHOC_OFFSET =>
        reg_rdata_o <= X"000000" & adhoc_reg;
      when ST_CONFIG_OFFSET =>
        reg_rdata_o <= X"0000" & "00" & st_config_reg;
      when ST_DELAY_OFFSET =>
        reg_rdata_o <= X"000000" & "000" & signal_delay_reg;
      when ST_FILTER_OUTPUT_SEL_OFFSET =>
        reg_rdata_o <= X"0000000" & "00" & filter_output_selector_reg;
      when ST_RESET_COUNTERS_OFFSET =>
        reg_rdata_o <= X"0000000" & "000" & reset_st_counters_reg;
      when ST_AFE_COMP_ENABLE_LO_OFFSET =>
        reg_rdata_o <= afe_comp_enable_reg(31 downto 0);
      when ST_AFE_COMP_ENABLE_HI_OFFSET =>
        reg_rdata_o <= X"000000" & afe_comp_enable_reg(39 downto 32);
      when ST_INVERT_ENABLE_LO_OFFSET =>
        reg_rdata_o <= invert_enable_reg(31 downto 0);
      when ST_INVERT_ENABLE_HI_OFFSET =>
        reg_rdata_o <= X"000000" & invert_enable_reg(39 downto 32);
      when others =>
        reg_rhit_o <= '0';
        reg_rdata_o <= (others => '0');
    end case;
  end process;

  core_chan_enable_o <= core_enable_reg;
  adhoc_o <= adhoc_reg;
  reset_st_counters_o <= reset_st_counters_reg;
  filter_output_selector_o <= filter_output_selector_reg;
  afe_comp_enable_o <= afe_comp_enable_reg;
  invert_enable_o <= invert_enable_reg;
  st_config_o <= st_config_reg;
  signal_delay_o <= signal_delay_reg;
end architecture rtl;
