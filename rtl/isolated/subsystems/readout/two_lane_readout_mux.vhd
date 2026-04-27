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
  type state_t is (rst, scan, dump);
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
    signal dout_reg_s       : std_logic_vector(63 downto 0) := (others => '0');
    signal valid_reg_s      : std_logic := '0';
    signal last_reg_s       : std_logic := '0';
  begin
    gen_rd_en : for ch_idx in 0 to CHANNELS_PER_LANE_G - 1 generate
    begin
      rd_en_o(CHANNEL_BASE_C + ch_idx) <= '1'
        when (sel_s = ch_idx and state_s = dump)
        else '0';
    end generate gen_rd_en;

    fifo_dout_mux_s <= dout_i(CHANNEL_BASE_C + sel_s);

    fsm_proc : process (clock_i)
      variable next_sel_v : integer range 0 to CHANNELS_PER_LANE_G - 1;
    begin
      if rising_edge(clock_i) then
        if reset_i = '1' then
          sel_s <= 0;
          state_s <= rst;
          valid_reg_s <= '0';
          last_reg_s <= '0';
          dout_reg_s <= (others => '0');
        else
          valid_reg_s <= '0';
          last_reg_s <= '0';
          next_sel_v := sel_s;

          case state_s is
            when rst =>
              sel_s <= 0;
              state_s <= scan;

            when scan =>
              if ready_i(CHANNEL_BASE_C + sel_s) = '1' then
                state_s <= dump;
              else
                if sel_s = CHANNELS_PER_LANE_G - 1 then
                  next_sel_v := 0;
                else
                  next_sel_v := sel_s + 1;
                end if;
                sel_s <= next_sel_v;
                state_s <= scan;
              end if;

            when dump =>
              dout_reg_s <= fifo_dout_mux_s(63 downto 0);
              valid_reg_s <= '1';
              if fifo_dout_mux_s(71 downto 64) = X"ED" then
                last_reg_s <= '1';
                if sel_s = CHANNELS_PER_LANE_G - 1 then
                  next_sel_v := 0;
                else
                  next_sel_v := sel_s + 1;
                end if;
                sel_s <= next_sel_v;
                state_s <= scan;
              else
                state_s <= dump;
              end if;

            when others =>
              sel_s <= 0;
              state_s <= rst;
          end case;
        end if;
      end if;
    end process fsm_proc;

    dout_o(lane_idx)  <= dout_reg_s;
    valid_o(lane_idx) <= valid_reg_s;
    last_o(lane_idx)  <= last_reg_s;
  end generate gen_lane;
end architecture rtl;
