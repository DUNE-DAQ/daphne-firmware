library ieee;
use ieee.std_logic_1164.all;

entity fanmon_smoke_tb is
end entity fanmon_smoke_tb;

architecture tb of fanmon_smoke_tb is
    constant CLK_PERIOD_C : time := 10 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal tach  : std_logic := '1';
    signal rpm   : std_logic_vector(11 downto 0);

    procedure wait_cycles(
        constant count : in positive;
        signal clk_s    : in std_logic
    ) is
    begin
        for index in 1 to count loop
            wait until rising_edge(clk_s);
        end loop;
    end procedure wait_cycles;
begin
    clk <= not clk after CLK_PERIOD_C / 2;

    dut : entity work.fanmon
        generic map (
            MEASUREMENT_WINDOW_CYCLES_G => 32,
            DEBOUNCE_MAX_G => 2
        )
        port map (
            clock => clk,
            reset => reset,
            tach => tach,
            rpm => rpm
        );

    stimulus : process
    begin
        wait_cycles(3, clk);
        reset <= '0';
        wait_cycles(2, clk);

        -- Two complete active-low tach pulses in one measurement window.
        tach <= '0';
        wait_cycles(5, clk);
        tach <= '1';
        wait_cycles(5, clk);
        tach <= '0';
        wait_cycles(5, clk);
        tach <= '1';
        wait_cycles(18, clk);

        assert rpm = x"100"
            report "Two tach pulses should report 256 RPM"
            severity failure;

        reset <= '1';
        wait_cycles(2, clk);
        assert rpm = x"000"
            report "RPM output did not clear on reset"
            severity failure;

        report "fanmon smoke test passed" severity note;
        wait;
    end process stimulus;
end architecture tb;

