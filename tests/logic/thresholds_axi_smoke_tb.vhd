library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne3_package.all;

entity thresholds_axi_smoke_tb is
end thresholds_axi_smoke_tb;

architecture tb of thresholds_axi_smoke_tb is
    constant clk_period : time := 10 ns;

    signal clk : std_logic := '0';
    signal axi_in : AXILITE_INREC := (
        ACLK => '0',
        ARESETN => '0',
        AWADDR => (others => '0'),
        AWPROT => (others => '0'),
        AWVALID => '0',
        WDATA => (others => '0'),
        WSTRB => (others => '0'),
        WVALID => '0',
        BREADY => '1',
        ARADDR => (others => '0'),
        ARPROT => (others => '0'),
        ARVALID => '0',
        RREADY => '1'
    );
    signal axi_out : AXILITE_OUTREC;
    signal dout : array_40x10_type;

    constant all_ones_10 : std_logic_vector(9 downto 0) := (others => '1');
    constant ch0_value  : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(16#155#, 10));
    constant ch39_value : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(16#02A#, 10));
begin
    clk <= not clk after clk_period / 2;
    axi_in.ACLK <= clk;

    dut: entity work.thresholds
        port map (
            AXI_IN => axi_in,
            AXI_OUT => axi_out,
            dout => dout
        );

    stimulus: process
    begin
        wait for 3 * clk_period;
        axi_in.ARESETN <= '1';
        wait until rising_edge(clk);

        assert dout(0) = all_ones_10
            report "Channel 0 threshold did not reset to all ones"
            severity failure;
        assert dout(39) = all_ones_10
            report "Channel 39 threshold did not reset to all ones"
            severity failure;

        axi_in.AWADDR <= x"00000000";
        axi_in.WDATA <= x"00000155";
        axi_in.WSTRB <= "1111";
        axi_in.AWVALID <= '1';
        axi_in.WVALID <= '1';
        wait until rising_edge(clk);
        axi_in.AWVALID <= '0';
        axi_in.WVALID <= '0';
        wait until axi_out.BVALID = '1';
        wait until rising_edge(clk);

        assert dout(0) = ch0_value
            report "Channel 0 write did not update the mirrored threshold output"
            severity failure;

        axi_in.AWADDR <= x"00000004";
        axi_in.WDATA <= x"00000022";
        axi_in.WSTRB <= "0011";
        axi_in.AWVALID <= '1';
        axi_in.WVALID <= '1';
        wait until rising_edge(clk);
        axi_in.AWVALID <= '0';
        axi_in.WVALID <= '0';
        wait until axi_out.BVALID = '1';
        wait until rising_edge(clk);

        assert dout(1) = all_ones_10
            report "Partial-strobe write unexpectedly modified channel 1"
            severity failure;

        axi_in.AWADDR <= x"0000009C";
        axi_in.WDATA <= x"0000002A";
        axi_in.WSTRB <= "1111";
        axi_in.AWVALID <= '1';
        axi_in.WVALID <= '1';
        wait until rising_edge(clk);
        axi_in.AWVALID <= '0';
        axi_in.WVALID <= '0';
        wait until axi_out.BVALID = '1';
        wait until rising_edge(clk);

        assert dout(39) = ch39_value
            report "Channel 39 write did not update the mirrored threshold output"
            severity failure;

        axi_in.ARADDR <= x"00000000";
        axi_in.ARVALID <= '1';
        wait until rising_edge(clk);
        axi_in.ARVALID <= '0';
        wait until axi_out.RVALID = '1';
        assert axi_out.RDATA(9 downto 0) = ch0_value
            report "Readback mismatch on channel 0"
            severity failure;
        wait until rising_edge(clk);

        axi_in.ARADDR <= x"0000009C";
        axi_in.ARVALID <= '1';
        wait until rising_edge(clk);
        axi_in.ARVALID <= '0';
        wait until axi_out.RVALID = '1';
        assert axi_out.RDATA(9 downto 0) = ch39_value
            report "Readback mismatch on channel 39"
            severity failure;
        wait until rising_edge(clk);

        assert false report "thresholds_axi_smoke_tb completed successfully" severity note;
        wait;
    end process;
end tb;
