library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity two_lane_readout_mux is
  generic (
    CHANNEL_COUNT_G : positive := 40;
    LANE_COUNT_G    : positive := 2
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
  type state_array_t is array (0 to LANE_COUNT_G - 1) of state_t;
  type lane_sel_array_t is array (0 to LANE_COUNT_G - 1) of integer range 0 to CHANNEL_COUNT_G - 1;
  type producer_claim_array_t is array (0 to CHANNEL_COUNT_G - 1) of boolean;

  function next_idx(idx : integer) return integer is
  begin
    if idx = CHANNEL_COUNT_G - 1 then
      return 0;
    end if;
    return idx + 1;
  end function;

  signal state_s : state_array_t := (others => rst);
  signal sel_s   : lane_sel_array_t := (others => 0);
begin
  assert LANE_COUNT_G = 2
    report "two_lane_readout_mux currently supports exactly two output lanes"
    severity failure;

  rd_en_proc : process (state_s, sel_s)
    variable rd_en_v : std_logic_array_t(0 to CHANNEL_COUNT_G - 1);
  begin
    rd_en_v := (others => '0');

    for lane_idx in 0 to LANE_COUNT_G - 1 loop
      if state_s(lane_idx) = dump then
        rd_en_v(sel_s(lane_idx)) := '1';
      end if;
    end loop;

    rd_en_o <= rd_en_v;
  end process rd_en_proc;

  fsm_proc : process (clock_i)
    variable state_next_v    : state_array_t;
    variable sel_next_v      : lane_sel_array_t;
    variable claimed_v       : producer_claim_array_t;
    variable found_v         : boolean;
    variable candidate_v     : integer range 0 to CHANNEL_COUNT_G - 1;
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        for lane_idx in 0 to LANE_COUNT_G - 1 loop
          state_s(lane_idx) <= rst;
          sel_s(lane_idx)   <= lane_idx mod CHANNEL_COUNT_G;
        end loop;
      else
        state_next_v := state_s;
        sel_next_v   := sel_s;
        claimed_v    := (others => false);

        for lane_idx in 0 to LANE_COUNT_G - 1 loop
          if state_s(lane_idx) = dump then
            claimed_v(sel_s(lane_idx)) := true;
          end if;
        end loop;

        for lane_idx in 0 to LANE_COUNT_G - 1 loop
          case state_s(lane_idx) is
            when rst =>
              sel_next_v(lane_idx)   := lane_idx mod CHANNEL_COUNT_G;
              state_next_v(lane_idx) := scan;

            when scan =>
              found_v := false;
              candidate_v := sel_s(lane_idx);

              for offset in 0 to CHANNEL_COUNT_G - 1 loop
                candidate_v := (sel_s(lane_idx) + offset) mod CHANNEL_COUNT_G;
                if ready_i(candidate_v) = '1' and not claimed_v(candidate_v) then
                  found_v := true;
                  exit;
                end if;
              end loop;

              if found_v then
                sel_next_v(lane_idx)   := candidate_v;
                state_next_v(lane_idx) := dump;
                claimed_v(candidate_v) := true;
              else
                sel_next_v(lane_idx)   := next_idx(sel_s(lane_idx));
                state_next_v(lane_idx) := scan;
              end if;

            when dump =>
              claimed_v(sel_s(lane_idx)) := true;
              if dout_i(sel_s(lane_idx))(71 downto 64) = X"ED" then
                state_next_v(lane_idx) := pause;
              else
                state_next_v(lane_idx) := dump;
              end if;

            when pause =>
              sel_next_v(lane_idx)   := next_idx(sel_s(lane_idx));
              state_next_v(lane_idx) := scan;

            when others =>
              sel_next_v(lane_idx)   := lane_idx mod CHANNEL_COUNT_G;
              state_next_v(lane_idx) := rst;
          end case;
        end loop;

        state_s <= state_next_v;
        sel_s   <= sel_next_v;
      end if;
    end if;
  end process fsm_proc;

  outreg_proc : process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        for lane_idx in 0 to LANE_COUNT_G - 1 loop
          dout_o(lane_idx)  <= (others => '0');
          valid_o(lane_idx) <= '0';
        end loop;
      else
        for lane_idx in 0 to LANE_COUNT_G - 1 loop
          if state_s(lane_idx) = dump then
            dout_o(lane_idx)  <= dout_i(sel_s(lane_idx))(63 downto 0);
            valid_o(lane_idx) <= '1';
          else
            dout_o(lane_idx)  <= (others => '0');
            valid_o(lane_idx) <= '0';
          end if;
        end loop;
      end if;
    end if;
  end process outreg_proc;

  gen_last : for lane_idx in 0 to LANE_COUNT_G - 1 generate
  begin
    last_o(lane_idx) <= '1' when state_s(lane_idx) = pause else '0';
  end generate gen_last;
end architecture rtl;
