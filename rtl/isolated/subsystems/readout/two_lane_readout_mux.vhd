library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity two_lane_readout_mux is
  generic (
    CHANNEL_COUNT_G      : positive := 40;
    LANE_COUNT_G         : positive := 2;
    CHANNELS_PER_LANE_G  : positive := 20
  );
  port (
    clock_i : in  std_logic;
    reset_i : in  std_logic;
    ready_i : in  std_logic_array_t(0 to CHANNEL_COUNT_G - 1);
    dout_i  : in  slv72_array_t(0 to CHANNEL_COUNT_G - 1);
    rd_en_o : out std_logic_array_t(0 to CHANNEL_COUNT_G - 1);
    dout_o  : out array_2x64_type;
    valid_o : out std_logic_vector(LANE_COUNT_G - 1 downto 0);
    last_o  : out std_logic_vector(LANE_COUNT_G - 1 downto 0)
  );
end entity two_lane_readout_mux;

architecture rtl of two_lane_readout_mux is
  type state_t is (rst, scan, dump, pause);
begin
  assert LANE_COUNT_G = 2
    report "two_lane_readout_mux currently supports exactly two output lanes"
    severity failure;

  assert CHANNEL_COUNT_G = (LANE_COUNT_G * CHANNELS_PER_LANE_G)
    report "two_lane_readout_mux requires CHANNEL_COUNT_G = LANE_COUNT_G * CHANNELS_PER_LANE_G"
    severity failure;

  gen_lane : for lane_idx in 0 to LANE_COUNT_G - 1 generate
    constant CHANNEL_BASE_C : natural := lane_idx * CHANNELS_PER_LANE_G;
    signal state_s          : state_t := rst;
    signal sel_s            : integer range 0 to CHANNELS_PER_LANE_G - 1 := 0;
    signal fifo_dout_mux_s  : std_logic_vector(71 downto 0);
  begin
    gen_rd_en : for ch_idx in 0 to CHANNELS_PER_LANE_G - 1 generate
    begin
      rd_en_o(CHANNEL_BASE_C + ch_idx) <= '1'
        when (sel_s = ch_idx and state_s = dump)
        else '0';
    end generate gen_rd_en;

    fifo_dout_mux_s <= dout_i(CHANNEL_BASE_C + sel_s);

    fsm_proc : process (clock_i)
    begin
      if rising_edge(clock_i) then
        if reset_i = '1' then
          sel_s <= 0;
          state_s <= rst;
        else
          case state_s is
            when rst =>
              sel_s <= 0;
              state_s <= scan;

            when scan =>
              if ready_i(CHANNEL_BASE_C + sel_s) = '1' then
                state_s <= dump;
              else
                if sel_s = CHANNELS_PER_LANE_G - 1 then
                  sel_s <= 0;
                else
                  sel_s <= sel_s + 1;
                end if;
                state_s <= scan;
              end if;

            when dump =>
              if fifo_dout_mux_s(71 downto 64) = X"ED" then
                state_s <= pause;
              else
                state_s <= dump;
              end if;

            when pause =>
              if sel_s = CHANNELS_PER_LANE_G - 1 then
                sel_s <= 0;
              else
                sel_s <= sel_s + 1;
              end if;
              state_s <= scan;

            when others =>
              sel_s <= 0;
              state_s <= rst;
          end case;
        end if;
      end if;
    end process fsm_proc;

    outreg_proc : process (clock_i)
    begin
      if rising_edge(clock_i) then
        if reset_i = '1' then
          dout_o(lane_idx)  <= (others => '0');
          valid_o(lane_idx) <= '0';
        elsif state_s = dump then
          dout_o(lane_idx)  <= fifo_dout_mux_s(63 downto 0);
          valid_o(lane_idx) <= '1';
        else
          dout_o(lane_idx)  <= (others => '0');
          valid_o(lane_idx) <= '0';
        end if;
      end if;
    end process outreg_proc;

    last_o(lane_idx) <= '1' when state_s = pause else '0';
  end generate gen_lane;
end architecture rtl;
