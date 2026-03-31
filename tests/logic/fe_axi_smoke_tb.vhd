library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;

entity fe_axi_smoke_tb is
end fe_axi_smoke_tb;

architecture tb of fe_axi_smoke_tb is
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

    signal trig_in : std_logic := '0';
    signal idelayctrl_ready : std_logic := '0';
    signal idelay_tap : array_5x9_type;
    signal idelay_load : std_logic_vector(4 downto 0);
    signal iserdes_bitslip : array_5x4_type;
    signal iserdes_reset : std_logic;
    signal idelayctrl_reset : std_logic;
    signal idelay_en_vtc : std_logic;
    signal trig : std_logic;

    constant all_zeros_9 : std_logic_vector(8 downto 0) := (others => '0');
    constant all_zeros_4 : std_logic_vector(3 downto 0) := (others => '0');
    constant tap2_value : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(16#155#, 9));
    constant bitslip4_value : std_logic_vector(3 downto 0) := "1010";

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

    dut: entity work.fe_axi
        port map (
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
            S_AXI_RREADY => rready,
            trig_IN => trig_in,
            idelayctrl_ready => idelayctrl_ready,
            idelay_tap => idelay_tap,
            idelay_load => idelay_load,
            iserdes_bitslip => iserdes_bitslip,
            iserdes_reset => iserdes_reset,
            idelayctrl_reset => idelayctrl_reset,
            idelay_en_vtc => idelay_en_vtc,
            trig => trig
        );

    stimulus: process
        variable readback : std_logic_vector(31 downto 0);
        variable trigger_seen : boolean;
    begin
        wait for 3 * clk_period;
        aresetn <= '1';
        wait until rising_edge(clk);

        assert idelay_en_vtc = '0'
            report "Control register bit 2 did not reset low"
            severity failure;
        assert iserdes_reset = '0'
            report "Control register bit 1 did not reset low"
            severity failure;
        assert idelayctrl_reset = '0'
            report "Control register bit 0 did not reset low"
            severity failure;
        assert idelay_tap(2) = all_zeros_9
            report "IDELAY tap register 2 did not reset low"
            severity failure;
        assert iserdes_bitslip(4) = all_zeros_4
            report "ISERDES bitslip register 4 did not reset low"
            severity failure;
        assert trig = '0'
            report "Trigger output should be low after reset"
            severity failure;
        assert idelay_load = "00000"
            report "IDELAY load pulse should be low after reset"
            severity failure;

        idelayctrl_ready <= '1';
        axi_read(x"00000004", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000001"
            report "Status register did not mirror idelayctrl_ready"
            severity failure;

        axi_write(x"00000000", x"00000007", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert idelay_en_vtc = '1'
            report "Control register write did not set idelay_en_vtc"
            severity failure;
        assert iserdes_reset = '1'
            report "Control register write did not set iserdes_reset"
            severity failure;
        assert idelayctrl_reset = '1'
            report "Control register write did not set idelayctrl_reset"
            severity failure;
        axi_read(x"00000000", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000007"
            report "Control register readback mismatch"
            severity failure;

        axi_write(x"00000000", x"00000000", "0011", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        axi_read(x"00000000", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback = x"00000007"
            report "Partial-strobe control write unexpectedly modified the register"
            severity failure;

        axi_write(x"00000014", x"00000155", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert idelay_tap(2) = tap2_value
            report "Tap register 2 write did not update the exported value"
            severity failure;
        assert idelay_load(2) = '1'
            report "Tap register 2 write did not generate an IDELAY load pulse"
            severity failure;
        wait until rising_edge(clk);
        assert idelay_load(2) = '1'
            report "IDELAY load pulse did not stretch to a second cycle"
            severity failure;
        wait until rising_edge(clk);
        assert idelay_load(2) = '0'
            report "IDELAY load pulse did not self-clear"
            severity failure;

        axi_write(x"00000030", x"0000000A", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        assert iserdes_bitslip(4) = bitslip4_value
            report "Bitslip register 4 write did not update the exported value"
            severity failure;
        axi_read(x"00000030", araddr, arvalid, rdata, rvalid, clk, readback);
        assert readback(3 downto 0) = bitslip4_value
            report "Bitslip register 4 readback mismatch"
            severity failure;

        axi_write(x"00000008", x"0000BABA", "1111", awaddr, awvalid, wdata, wstrb, wvalid, bvalid, clk);
        trigger_seen := false;
        for i in 0 to 7 loop
            if trig = '1' then
                trigger_seen := true;
            end if;
            wait until rising_edge(clk);
        end loop;
        assert trigger_seen
            report "Frontend trigger register write did not generate a pulse"
            severity failure;
        assert trig = '0'
            report "Frontend trigger pulse did not self-clear"
            severity failure;

        assert false report "fe_axi_smoke_tb completed successfully" severity note;
        wait;
    end process;
end tb;
