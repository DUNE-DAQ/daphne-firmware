-- Monitor one active-low, two-pulse-per-revolution fan tachometer.
--
-- At the default 100 MHz AXI clock, a 23,437,500-cycle measurement window is
-- 234.375 ms. Two tach pulses per revolution therefore gives:
--
--   RPM = pulses * 60 / (2 * 0.234375) = pulses * 128
--
-- The five-bit pulse counter reports up to 3,968 RPM and saturates instead of
-- wrapping. Adjust MEASUREMENT_WINDOW_CYCLES_G if this block is clocked at a
-- frequency other than 100 MHz.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fanmon is
    generic (
        MEASUREMENT_WINDOW_CYCLES_G : positive := 23_437_500;
        DEBOUNCE_MAX_G              : positive := 255
    );
    port (
        clock : in  std_logic;
        reset : in  std_logic;
        tach  : in  std_logic;
        rpm   : out std_logic_vector(11 downto 0)
    );
end entity fanmon;

architecture rtl of fanmon is
    signal window_count_reg : natural range 0 to MEASUREMENT_WINDOW_CYCLES_G - 1 := 0;
    signal window_tick_reg  : std_logic := '0';

    signal tach_meta_reg      : std_logic := '1';
    signal tach_sync_reg      : std_logic := '1';
    signal debounce_count_reg : natural range 0 to DEBOUNCE_MAX_G := DEBOUNCE_MAX_G;
    signal debounced_tach_reg : std_logic := '1';
    signal previous_tach_reg  : std_logic := '1';

    signal pulse_count_reg : unsigned(4 downto 0) := (others => '0');
    signal rpm_reg         : std_logic_vector(11 downto 0) := (others => '0');
begin
    -- Keep the asynchronous tach input out of the counting logic.
    synchronize_tach_proc : process(clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                tach_meta_reg <= '1';
                tach_sync_reg <= '1';
            else
                tach_meta_reg <= tach;
                tach_sync_reg <= tach_meta_reg;
            end if;
        end if;
    end process synchronize_tach_proc;

    -- Change the stable tach value only after the integrator reaches an end.
    debounce_tach_proc : process(clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                debounce_count_reg <= DEBOUNCE_MAX_G;
                debounced_tach_reg <= '1';
            elsif tach_sync_reg = '1' then
                if debounce_count_reg < DEBOUNCE_MAX_G then
                    debounce_count_reg <= debounce_count_reg + 1;
                end if;
                if debounce_count_reg >= DEBOUNCE_MAX_G - 1 then
                    debounced_tach_reg <= '1';
                end if;
            else
                if debounce_count_reg > 0 then
                    debounce_count_reg <= debounce_count_reg - 1;
                end if;
                if debounce_count_reg <= 1 then
                    debounced_tach_reg <= '0';
                end if;
            end if;
        end if;
    end process debounce_tach_proc;

    measurement_window_proc : process(clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                window_count_reg <= 0;
                window_tick_reg <= '0';
            elsif window_count_reg = MEASUREMENT_WINDOW_CYCLES_G - 1 then
                window_count_reg <= 0;
                window_tick_reg <= '1';
            else
                window_count_reg <= window_count_reg + 1;
                window_tick_reg <= '0';
            end if;
        end if;
    end process measurement_window_proc;

    count_pulses_proc : process(clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                previous_tach_reg <= '1';
                pulse_count_reg <= (others => '0');
                rpm_reg <= (others => '0');
            else
                previous_tach_reg <= debounced_tach_reg;

                if window_tick_reg = '1' then
                    rpm_reg <= std_logic_vector(pulse_count_reg) & "0000000";
                    pulse_count_reg <= (others => '0');
                elsif previous_tach_reg = '1' and debounced_tach_reg = '0' then
                    if pulse_count_reg /= "11111" then
                        pulse_count_reg <= pulse_count_reg + 1;
                    end if;
                end if;
            end if;
        end if;
    end process count_pulses_proc;

    rpm <= rpm_reg;
end architecture rtl;
