-- tx_mux_timeslice
--
-- Generates timeslice markers for array of tx_mux blocks
--
-- Dave Newbold, 6/10/22

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library ipbus;
use work.ipbus.all;
use work.ipbus_reg_types.all;

use work.tx_mux_decl.all;

entity tx_mux_timeslice is
    port(
        ipb_clk: in std_logic;
        ipb_rst: in std_logic;
        ipb_in: in  ipb_wbus;
        ipb_out: out ipb_rbus;
        dune_base_clk: in std_logic; -- DUNE base clock (62.5MHz)
        dune_base_rst: in std_logic; -- DUNE base clock sync reset (src_clk)
        ts_dune_clk: in std_logic_vector(63 downto 0);
        data_clk: in std_logic;
        samp: out std_logic; -- Sample flag
        mark: out std_logic; -- Timeslice marker
        ts_data_clk: out std_logic_vector(63 downto 0)
    );

end entity tx_mux_timeslice;

architecture rtl of tx_mux_timeslice is

    signal ctrl: ipb_reg_v(0 downto 0);
    signal stat: ipb_reg_v(1 downto 0);
    signal ctrl_sample, s, sd, samp_dune_clk: std_logic;
    signal cdc_dest_logic_rx: std_logic;
    signal t: std_logic_vector(63 downto 0);

begin

-- CSR registers

    csr: entity work.ipbus_ctrlreg_v
		generic map(
			N_CTRL => 1,
			N_STAT => 2
		)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipb_in,
			ipbus_out => ipb_out,
			d => stat,
			q => ctrl
		);

    ctrl_sample <= ctrl(0)(0);
    stat <= (t(63 downto 32), t(31 downto 0));

    sync_en_buf: entity work.tx_syncreg
        generic map(
            N => 1
        )
        port map(
            clks => ipb_clk,
            d(0) => ctrl_sample,
            clk => dune_base_clk,
            q(0) => s
        );

    sd <= s when rising_edge(dune_base_clk);
    samp_dune_clk <= s and not sd;

    t <= ts_dune_clk when samp_dune_clk = '1' and rising_edge(dune_base_clk);

    sync_samp: entity work.tx_syncreg
        generic map(
            N => 1
        )
        port map(
            clks => dune_base_clk,
            d(0) => samp_dune_clk,
            clk  => data_clk,
            q(0) => samp
        );
    
    xpm_cdc_handshake_inst : xpm_cdc_handshake
    generic map (
       DEST_EXT_HSK => 0,   -- DECIMAL; 0=internal handshake, 1=external handshake
       DEST_SYNC_FF => 4,   -- DECIMAL; range: 2-10
       INIT_SYNC_FF => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
       SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
       SRC_SYNC_FF => 2,    -- DECIMAL; range: 2-10
       WIDTH => 64          -- DECIMAL; range: 1-1024
    )
    port map (
       dest_out => ts_data_clk,
       dest_req => open,
       src_rcv => cdc_dest_logic_rx,
       dest_ack => '1',
       dest_clk => data_clk,
       src_clk => dune_base_clk,
       src_in => ts_dune_clk,
       src_send => not cdc_dest_logic_rx
    );
    
    mark <= ts_data_clk(TIMESLICE_RADIX - 1);
    
end architecture rtl;
