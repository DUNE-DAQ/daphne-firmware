library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_two_lane_readout_mux is
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
end entity legacy_two_lane_readout_mux;

architecture rtl of legacy_two_lane_readout_mux is
begin
  two_lane_readout_mux_inst : entity work.two_lane_readout_mux
    generic map (
      CHANNEL_COUNT_G     => CHANNEL_COUNT_G,
      LANE_COUNT_G        => LANE_COUNT_G,
      CHANNELS_PER_LANE_G => CHANNELS_PER_LANE_G
    )
    port map (
      clock_i => clock_i,
      reset_i => reset_i,
      ready_i => ready_i,
      dout_i  => dout_i,
      rd_en_o => rd_en_o,
      dout_o  => dout_o,
      valid_o => valid_o,
      last_o  => last_o
    );
end architecture rtl;
