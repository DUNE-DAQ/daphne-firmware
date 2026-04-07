library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;

entity stuff_axi_smoke_tb is
end stuff_axi_smoke_tb;

architecture tb of stuff_axi_smoke_tb is
    constant clk_period : time := 10 ns;

    signal clk : std_logic := '0';
    signal aresetn : std_logic := '0';
    signal awaddr : std_logic_vector(31 downto 0) := (others => '0');
    signal awprot : std_logic_vector(2 downto 0) := (others => '0');
    signal awvalid : std_logic := '0';
    signal awready : std_logic;
    signal wdata : std_logic_vector(31 downto 0) := (others => '0');
    signal wstrb : std_logic_vector(3 downto 0) := (others => '0');
    signal wvalid : std_logic := '0';
    signal wready : std_logic;
    signal bresp : std_logic_vector(1 downto 0);
    signal bvalid : std_logic;
    signal bready : std_logic := '1';
    signal araddr : std_logic_vector(31 downto 0) := (others => '0');
    signal arprot : std_logic_vector(2 downto 0) := (others => '0');
    signal arvalid : std_logic := '0';
    signal arready : std_logic;
    signal rdata : std_logic_vector(31 downto 0);
    signal rresp : std_logic_vector(1 downto 0);
    signal rvalid : std_logic;
    signal rready : std_logic := '1';

    signal fan_tach : std_logic_vector(1 downto 0) := "11";
    signal fan_ctrl : std_logic;
    signal hvbias_en : std_logic;
    signal mux_en : std_logic_vector(1 downto 0);
    signal mux_a : std_logic_vector(1 downto 0);
    signal stat_led : std_logic_vector(5 downto 0);
    signal version : std_logic_vector(27 downto 0) := x"1234567";
    signal core_chan_enable : std_logic_vector(39 downto 0);
    signal adhoc : std_logic_vector(7 downto 0);
    signal filter_output_selector : std_logic_vector(1 downto 0);
    signal afe_comp_enable : std_logic_vector(39 downto 0);
    signal invert_enable : std_logic_vector(39 downto 0);
    signal st_config : std_logic_vector(13 downto 0);
    signal signal_delay : std_logic_vector(4 downto 0);
    signal reset_st_counters : std_logic;

    procedure axi_write(
        constant addr : in std_logic_vector(31 downto 0);
        constant data : in std_logic_vector(31 downto 0);
        constant strobe : in std_logic_vector(3 downto 0);
        signal awaddr_s : out std_logic_vector(31 downto 0);
        signal awvalid_s : out std_logic;
        signal wdata_s : out std_logic_vector(31 downto 0);
        signal wstrb_s : out std_logic_vector(3 downto 0);
        signal wvalid_s : out std_logic;
        signal bvalid_s : in std_logic;
        signal clk_s : in std_logic
    ) is
    begin
        awaddr_s <= addr;
        awvalid_s <= '1';
        wdata_s <= data;
        wstrb_s <= strobe;
        wvalid_s <= '1';
        wait until rising_edge(clk_s);
        awvalid_s <= '0';
        wvalid_s <= '0';
        wait until bvalid_s = '1';
        wait until rising_edge(clk_s);
    end procedure;

    procedure axi_read(
        constant addr : in std_logic_vector(31 downto 0);
        signal araddr_s : out std_logic_vector(31 downto 0);
        signal arvalid_s : out std_logic;
        signal rdata_s : in std_logic_vector(31 downto 0);
        signal rvalid_s : in std_logic;
        signal clk_s : in std_logic;
        variable data : out std_logic_vector(31 downto 0)
    ) is
    begin
        araddr_s <= addr;
        arvalid_s <= '1';
        wait until rising_edge(clk_s);
        arvalid_s <= '0';
        wait until rvalid_s = '1';
        data := rdata_s;
        wait until rising_edge(clk_s);
    end procedure;
begin
    clk <= not clk after clk_period / 2;

    dut : entity work.stuff
        port map (
            fan_tach => fan_tach,
            fan_ctrl => fan_ctrl,
            hvbias_en => hvbias_en,
            mux_en => mux_en,
            mux_a => mux_a,
            stat_led => stat_led,
            version => version,
            core_chan_enable => core_chan_enable,
            adhoc => adhoc,
            filter_output_selector => filter_output_selector,
            afe_comp_enable => afe_comp_enable,
            invert_enable => invert_enable,
            st_config => st_config,
            signal_delay => signal_delay,
            reset_st_counters => reset_st_counters,
            S_AXI_ACLK => clk,
            S_AXI_ARESETN => aresetn,
            S_AXI_AWADDR => awaddr,
            S_AXI_AWPROT => awprot,
            S_AXI_AWVALID => awvalid,
            S_AXI_AWREADY => awready,
            S_AXI_WDATA => wdata,
            S_AXI_WSTRB => wstrb,
            S_AXI_WVALID => wvalid,
            S_AXI_WREADY => wready,
            S_AXI_BRESP => bresp,
            S_AXI_BVALID => bvalid,
            S_AXI_BREADY => bready,
            S_AXI_ARADDR => araddr,
            S_AXI_ARPROT => arprot,
            S_AXI_ARVALID => arvalid,
            S_AXI_ARREADY => arready,
            S_AXI_RDATA => rdata,
            S_AXI_RRESP => rresp,
            S_AXI_RVALID => rvalid,
            S_AXI_RREADY => rready
        );

    stimulus : process
        variable readback : std_logic_vector(31 downto 0);
    begin
        wait for 3 * clk_period;
        aresetn <= '1';
        wait until rising_edge(clk);

        assert hvbias_en = '0'
            report "High-voltage bias enable did not reset low"
            severity failure;
        assert mux_en = "00"
            report "MUX enable did not reset low"
            severity failure;
        assert mux_a = "00"
            report "MUX address did not reset low"
            severity failure;
        assert stat_led = "000000"
            report "Status LEDs did not reset low"
            severity failure;
        assert core_chan_enable = DEFAULT_core_enable
            report "Core enable mask did not reset to package default"
            severity failure;
        assert adhoc = DEFAULT_st_adhoc_command
            report "Adhoc trigger command did not reset to package default"
            severity failure;
        assert signal_delay = DEFAULT_st_config_command(20 downto 16)
            report "Signal-delay field did not reset to package default"
            severity failure;
        assert st_config = DEFAULT_st_config_command(15 downto 2)
            report "Self-trigger config field did not reset to package default"
            severity failure;
        assert filter_output_selector = DEFAULT_st_config_command(1 downto 0)
            report "Filter output selector did not reset to package default"
            severity failure;
        assert reset_st_counters = '0'
            report "Counter reset flag did not reset low"
            severity failure;
        assert afe_comp_enable = DEFAULT_st_comp_command
            report "AFE compensation mask did not reset to package default"
            severity failure;
        assert invert_enable = DEFAULT_st_invert_command
            report "Invert mask did not reset to package default"
            severity failure;
        axi_read(x"00000000", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"000000FF"
            report "Fan-speed register did not reset to full-speed default"
            severity failure;
        axi_read(x"0000001C", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"01234567"
            report "Version register readback mismatch"
            severity failure;

        axi_write(x"00000000", x"00000055", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_read(x"00000000", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000055"
            report "Fan-speed register readback mismatch after write"
            severity failure;

        axi_write(x"00000018", x"00000015", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert stat_led = "010101"
            report "LED control write did not update the exported signals"
            severity failure;
        axi_read(x"00000018", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000015"
            report "LED register readback mismatch"
            severity failure;

        axi_write(x"0000000C", x"00000001", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert hvbias_en = '1'
            report "High-voltage bias write did not update the exported signal"
            severity failure;

        axi_write(x"00000010", x"00000002", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_write(x"00000014", x"00000003", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert mux_en = "10"
            report "MUX enable write did not update the exported signal"
            severity failure;
        assert mux_a = "11"
            report "MUX address write did not update the exported signal"
            severity failure;

        axi_write(x"00000028", x"000000AA", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert adhoc = x"AA"
            report "Adhoc trigger command write did not update the exported signal"
            severity failure;
        axi_read(x"00000028", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"000000AA"
            report "Adhoc trigger command readback mismatch"
            severity failure;

        axi_write(x"00000020", x"A5A55AA5", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_write(x"00000024", x"0000005A", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert core_chan_enable(31 downto 0) = x"A5A55AA5"
            report "Low channel-enable mask write did not update"
            severity failure;
        assert core_chan_enable(39 downto 32) = x"5A"
            report "High channel-enable mask write did not update"
            severity failure;
        axi_read(x"00000020", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"A5A55AA5"
            report "Low channel-enable mask readback mismatch"
            severity failure;
        axi_read(x"00000024", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"0000005A"
            report "High channel-enable mask readback mismatch"
            severity failure;

        axi_write(x"0000002C", x"00001234", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_write(x"00000030", x"00000012", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_write(x"00000034", x"00000002", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_write(x"00000038", x"00000001", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert st_config = std_logic_vector(to_unsigned(16#1234#, st_config'length))
            report "Self-trigger config write did not update the exported signal"
            severity failure;
        assert signal_delay = "10010"
            report "Signal-delay write did not update the exported signal"
            severity failure;
        assert filter_output_selector = "10"
            report "Filter output selector write did not update the exported signal"
            severity failure;
        assert reset_st_counters = '1'
            report "Reset counters write did not update the exported signal"
            severity failure;
        axi_read(x"0000002C", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00001234"
            report "Self-trigger config readback mismatch"
            severity failure;
        axi_read(x"00000030", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000012"
            report "Signal-delay readback mismatch"
            severity failure;
        axi_read(x"00000034", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000002"
            report "Filter output selector readback mismatch"
            severity failure;
        axi_read(x"00000038", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000001"
            report "Reset counters readback mismatch"
            severity failure;

        axi_write(x"0000003C", x"89ABCDEF", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_write(x"00000040", x"00000012", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_write(x"00000044", x"76543210", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_write(x"00000048", x"000000AB", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert afe_comp_enable(31 downto 0) = x"89ABCDEF"
            report "AFE compensation low mask write did not update"
            severity failure;
        assert afe_comp_enable(39 downto 32) = x"12"
            report "AFE compensation high mask write did not update"
            severity failure;
        assert invert_enable(31 downto 0) = x"76543210"
            report "Invert low mask write did not update"
            severity failure;
        assert invert_enable(39 downto 32) = x"AB"
            report "Invert high mask write did not update"
            severity failure;
        axi_read(x"0000003C", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"89ABCDEF"
            report "AFE compensation low mask readback mismatch"
            severity failure;
        axi_read(x"00000040", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000012"
            report "AFE compensation high mask readback mismatch"
            severity failure;
        axi_read(x"00000044", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"76543210"
            report "Invert low mask readback mismatch"
            severity failure;
        axi_read(x"00000048", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"000000AB"
            report "Invert high mask readback mismatch"
            severity failure;

        axi_write(x"00000018", x"0000003F", "0011", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_read(x"00000018", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000015"
            report "Partial-strobe write unexpectedly modified the LED register"
            severity failure;

        assert false report "stuff_axi_smoke_tb completed successfully" severity note;
        wait;
    end process;
end tb;
