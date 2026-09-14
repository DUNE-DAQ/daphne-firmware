-- Behavioral pipeline model only; it cannot model metastability or placement.
library ieee;
use ieee.std_logic_1164.all;
entity xpm_cdc_array_single is
  generic(DEST_SYNC_FF:integer:=4; INIT_SYNC_FF:integer:=0; SIM_ASSERT_CHK:integer:=0;
    SRC_INPUT_REG:integer:=1; WIDTH:integer:=2);
  port(src_clk:in std_logic; src_in:in std_logic_vector(WIDTH-1 downto 0);
    dest_clk:in std_logic; dest_out:out std_logic_vector(WIDTH-1 downto 0));
end entity;
architecture sim of xpm_cdc_array_single is
  type stages_t is array(0 to DEST_SYNC_FF-1) of std_logic_vector(WIDTH-1 downto 0);
  signal stages : stages_t := (others=>(others=>'0'));
  signal source_reg : std_logic_vector(WIDTH-1 downto 0) := (others=>'0');
begin
  process(src_clk) begin
    if rising_edge(src_clk) then source_reg <= src_in; end if;
  end process;
  process(dest_clk) begin
    if rising_edge(dest_clk) then
      if SRC_INPUT_REG=1 then stages(0)<=source_reg;
      else stages(0)<=src_in; end if;
      for i in 1 to DEST_SYNC_FF-1 loop stages(i)<=stages(i-1); end loop;
    end if;
  end process;
  dest_out <= stages(DEST_SYNC_FF-1);
end architecture;
