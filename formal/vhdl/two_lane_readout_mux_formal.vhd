library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity two_lane_readout_mux_formal is
  port (
    clk     : in std_logic;
    ready_i : in std_logic_vector(3 downto 0);
    dout0_i : in std_logic_vector(71 downto 0);
    dout1_i : in std_logic_vector(71 downto 0);
    dout2_i : in std_logic_vector(71 downto 0);
    dout3_i : in std_logic_vector(71 downto 0)
  );
end entity two_lane_readout_mux_formal;

architecture formal of two_lane_readout_mux_formal is
  signal reset_s  : std_logic := '1';
  signal step_s   : natural range 0 to 3 := 0;
  signal ready_s  : std_logic_array_t(0 to 3);
  signal dout_s   : slv72_array_t(0 to 3);
  signal rd_en_s  : std_logic_array_t(0 to 3);
  signal prev_rd_en_s : std_logic_array_t(0 to 3) := (others => '0');
  signal prev_dout_s  : slv72_array_t(0 to 3) := (others => (others => '0'));
  signal lane_dout_s  : array_2x64_type;
  signal lane_valid_s : std_logic_vector(1 downto 0);
  signal lane_last_s  : std_logic_vector(1 downto 0);

  function is_ed(word : std_logic_vector(71 downto 0)) return std_logic is
  begin
    if word(71 downto 64) = X"ED" then
      return '1';
    end if;
    return '0';
  end function;
begin
  ready_s(0) <= ready_i(0);
  ready_s(1) <= ready_i(1);
  ready_s(2) <= ready_i(2);
  ready_s(3) <= ready_i(3);

  dout_s(0) <= dout0_i;
  dout_s(1) <= dout1_i;
  dout_s(2) <= dout2_i;
  dout_s(3) <= dout3_i;

  dut : entity work.two_lane_readout_mux
    generic map (
      CHANNEL_COUNT_G     => 4,
      LANE_COUNT_G        => 2,
      CHANNELS_PER_LANE_G => 2
    )
    port map (
      clock_i => clk,
      reset_i => reset_s,
      ready_i => ready_s,
      dout_i  => dout_s,
      rd_en_o => rd_en_s,
      dout_o  => lane_dout_s,
      valid_o => lane_valid_s,
      last_o  => lane_last_s
    );

  drive_proc : process(clk)
  begin
    if rising_edge(clk) then
      if step_s < 3 then
        step_s <= step_s + 1;
      end if;

      if step_s >= 1 then
        reset_s <= '0';
      else
        reset_s <= '1';
      end if;
    end if;
  end process;

  check_proc : process(clk)
  begin
    if rising_edge(clk) then
      if reset_s = '1' then
        assert rd_en_s = (0 to 3 => '0')
          report "rd_en must reset low"
          severity failure;
        assert lane_valid_s = "00"
          report "valid must reset low"
          severity failure;
        assert lane_last_s = "00"
          report "last must reset low"
          severity failure;
        prev_rd_en_s <= (others => '0');
        prev_dout_s  <= (others => (others => '0'));
      else
        assert not (rd_en_s(0) = '1' and rd_en_s(1) = '1')
          report "lane 0 must never read two channels at once"
          severity failure;
        assert not (rd_en_s(2) = '1' and rd_en_s(3) = '1')
          report "lane 1 must never read two channels at once"
          severity failure;

        assert lane_last_s(0) = '0' or lane_valid_s(0) = '1'
          report "lane 0 last implies valid"
          severity failure;
        assert lane_last_s(1) = '0' or lane_valid_s(1) = '1'
          report "lane 1 last implies valid"
          severity failure;

        if lane_valid_s(0) = '1' then
          assert (prev_rd_en_s(0) xor prev_rd_en_s(1)) = '1'
            report "lane 0 valid requires exactly one previously selected channel"
            severity failure;
          if prev_rd_en_s(0) = '1' then
            assert lane_dout_s(0) = prev_dout_s(0)(63 downto 0)
              report "lane 0 data must match channel 0 payload"
              severity failure;
            assert lane_last_s(0) = is_ed(prev_dout_s(0))
              report "lane 0 last must follow channel 0 ED marker"
              severity failure;
          else
            assert lane_dout_s(0) = prev_dout_s(1)(63 downto 0)
              report "lane 0 data must match channel 1 payload"
              severity failure;
            assert lane_last_s(0) = is_ed(prev_dout_s(1))
              report "lane 0 last must follow channel 1 ED marker"
              severity failure;
          end if;
        end if;

        if lane_valid_s(1) = '1' then
          assert (prev_rd_en_s(2) xor prev_rd_en_s(3)) = '1'
            report "lane 1 valid requires exactly one previously selected channel"
            severity failure;
          if prev_rd_en_s(2) = '1' then
            assert lane_dout_s(1) = prev_dout_s(2)(63 downto 0)
              report "lane 1 data must match channel 2 payload"
              severity failure;
            assert lane_last_s(1) = is_ed(prev_dout_s(2))
              report "lane 1 last must follow channel 2 ED marker"
              severity failure;
          else
            assert lane_dout_s(1) = prev_dout_s(3)(63 downto 0)
              report "lane 1 data must match channel 3 payload"
              severity failure;
            assert lane_last_s(1) = is_ed(prev_dout_s(3))
              report "lane 1 last must follow channel 3 ED marker"
              severity failure;
          end if;
        end if;

        prev_rd_en_s <= rd_en_s;
        prev_dout_s  <= dout_s;
      end if;
    end if;
  end process;
end architecture formal;
