library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity afe_config_slice_smoke_tb is
end entity afe_config_slice_smoke_tb;

architecture tb of afe_config_slice_smoke_tb is
  constant clk_period : time := 10 ns;

  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal cmd : afe_config_command_t := AFE_CONFIG_COMMAND_NULL;
  signal status : afe_config_status_t;

  signal afe_miso : std_logic := '0';
  signal afe_sclk : std_logic;
  signal afe_sen : std_logic;
  signal afe_mosi : std_logic;
  signal trim_sclk : std_logic;
  signal trim_mosi : std_logic;
  signal trim_ldac_n : std_logic;
  signal trim_sync_n : std_logic;
  signal offset_sclk : std_logic;
  signal offset_mosi : std_logic;
  signal offset_ldac_n : std_logic;
  signal offset_sync_n : std_logic;
begin
  clk <= not clk after clk_period / 2;

  dut : entity work.afe_config_slice
    port map (
      clock_i         => clk,
      reset_i         => reset,
      cmd_i           => cmd,
      status_o        => status,
      afe_miso_i      => afe_miso,
      afe_sclk_o      => afe_sclk,
      afe_sen_o       => afe_sen,
      afe_mosi_o      => afe_mosi,
      trim_sclk_o     => trim_sclk,
      trim_mosi_o     => trim_mosi,
      trim_ldac_n_o   => trim_ldac_n,
      trim_sync_n_o   => trim_sync_n,
      offset_sclk_o   => offset_sclk,
      offset_mosi_o   => offset_mosi,
      offset_ldac_n_o => offset_ldac_n,
      offset_sync_n_o => offset_sync_n
    );

  stimulus : process
    variable afe_busy_seen : boolean := false;
    variable trim_busy_seen : boolean := false;
    variable offset_busy_seen : boolean := false;
  begin
    wait for 3 * clk_period;
    reset <= '0';
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    assert status.ready = '1'
      report "config slice did not become ready after reset"
      severity failure;
    assert status.afe_busy = '0' and status.trim_busy = '0' and status.offset_busy = '0'
      report "config slice unexpectedly busy after reset"
      severity failure;

    cmd.afe_write_data <= x"A5F00D";
    cmd.afe_write_valid <= '1';
    wait until rising_edge(clk);
    cmd.afe_write_valid <= '0';

    for i in 0 to 260 loop
      if status.afe_busy = '1' then
        afe_busy_seen := true;
      end if;
      wait until rising_edge(clk);
    end loop;

    assert afe_busy_seen
      report "AFE SPI transaction never asserted busy"
      severity failure;
    assert status.ready = '1'
      report "config slice did not return to ready after AFE transaction"
      severity failure;
    assert afe_sen = '1'
      report "AFE chip select did not return idle high"
      severity failure;

    cmd.trim_write_data <= x"12345678";
    cmd.trim_write_valid <= '1';
    wait until rising_edge(clk);
    cmd.trim_write_valid <= '0';

    for i in 0 to 800 loop
      if status.trim_busy = '1' then
        trim_busy_seen := true;
      end if;
      wait until rising_edge(clk);
    end loop;

    assert trim_busy_seen
      report "trim DAC transaction never asserted busy"
      severity failure;
    assert status.ready = '1'
      report "config slice did not return to ready after trim transaction"
      severity failure;
    assert trim_ldac_n = '1' and trim_sync_n = '1'
      report "trim DAC control lines did not return idle high"
      severity failure;

    cmd.offset_write_data <= x"89ABCDEF";
    cmd.offset_write_valid <= '1';
    wait until rising_edge(clk);
    cmd.offset_write_valid <= '0';

    for i in 0 to 800 loop
      if status.offset_busy = '1' then
        offset_busy_seen := true;
      end if;
      wait until rising_edge(clk);
    end loop;

    assert offset_busy_seen
      report "offset DAC transaction never asserted busy"
      severity failure;
    assert status.ready = '1'
      report "config slice did not return to ready after offset transaction"
      severity failure;
    assert offset_ldac_n = '1' and offset_sync_n = '1'
      report "offset DAC control lines did not return idle high"
      severity failure;

    wait;
  end process stimulus;
end architecture tb;
