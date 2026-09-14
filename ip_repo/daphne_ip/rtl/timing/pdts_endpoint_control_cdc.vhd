-- AXI/local-system-clock boundary, separated from the physical clock generators
-- so reset, address and status transfers can be exercised with stopped clocks.
library ieee;
use ieee.std_logic_1164.all;
library xpm;
use xpm.vcomponents.all;

entity pdts_endpoint_control_cdc is
  port (
    axi_clk_i, axi_resetn_i : in std_logic;
    reset_axi_i : in std_logic;
    addr_axi_i : in std_logic_vector(15 downto 0);
    sys_clk_i : in std_logic;
    reset_sys_o : out std_logic;
    addr_sys_o : out std_logic_vector(15 downto 0);
    addr_valid_sys_o : out std_logic;
    stat_sys_i : in std_logic_vector(3 downto 0);
    stat_axi_o : out std_logic_vector(3 downto 0);
    levels_async_i : in std_logic_vector(2 downto 0);
    levels_axi_o : out std_logic_vector(2 downto 0)
  );
end entity;

architecture rtl of pdts_endpoint_control_cdc is
  signal reset_sys : std_logic;
  signal stat_value : std_logic_vector(3 downto 0);
  signal stat_valid : std_logic;
begin
  -- Reset must release without waiting for an address response: the endpoint
  -- holds its recovered-clock MMCM in reset while sys_rst is asserted.
  reset_cdc : xpm_cdc_async_rst
    generic map (DEST_SYNC_FF=>3, INIT_SYNC_FF=>1, RST_ACTIVE_HIGH=>1)
    port map (src_arst=>reset_axi_i, dest_clk=>sys_clk_i, dest_arst=>reset_sys);
  reset_sys_o <= reset_sys;

  address_cdc : entity work.pdts_cdc_snapshot
    generic map (WIDTH_G=>16)
    port map (src_clk_i=>axi_clk_i, src_data_i=>addr_axi_i,
              dst_clk_i=>sys_clk_i, dst_reset_i=>reset_sys,
              dst_data_o=>addr_sys_o, dst_valid_o=>addr_valid_sys_o, dst_update_o=>open);
  status_cdc : entity work.pdts_cdc_snapshot
    generic map (WIDTH_G=>4)
    port map (src_clk_i=>sys_clk_i, src_data_i=>stat_sys_i,
              dst_clk_i=>axi_clk_i, dst_reset_i=>not axi_resetn_i,
              dst_data_o=>stat_value, dst_valid_o=>stat_valid, dst_update_o=>open);
  stat_axi_o <= stat_value when stat_valid='1' else (others=>'0');

  -- Locks and endpoint-ready are independent observations, not an encoded word.
  levels_cdc : xpm_cdc_array_single
    generic map (DEST_SYNC_FF=>3, INIT_SYNC_FF=>1, SIM_ASSERT_CHK=>1,
                 SRC_INPUT_REG=>0, WIDTH=>3)
    port map (src_clk=>'0', src_in=>levels_async_i, dest_clk=>axi_clk_i,
              dest_out=>levels_axi_o);
end architecture;
