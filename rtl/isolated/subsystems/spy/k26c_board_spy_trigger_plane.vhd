library ieee;
use ieee.std_logic_1164.all;

entity k26c_board_spy_trigger_plane is
  port (
    clock_i            : in  std_logic;
    reset_i            : in  std_logic;
    frontend_trigger_i : in  std_logic;
    adhoc_i            : in  std_logic_vector(7 downto 0);
    ti_trigger_i       : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr_i  : in  std_logic;
    spy_trigger_o      : out std_logic
  );
end entity k26c_board_spy_trigger_plane;

architecture rtl of k26c_board_spy_trigger_plane is
  signal ti_trigger_en_s  : std_logic;
  signal ti_trigger_en0_s : std_logic := '0';
  signal ti_trigger_en1_s : std_logic := '0';
  signal ti_trigger_en2_s : std_logic := '0';
  signal timing_trigger_s : std_logic;
begin
  ti_trigger_en_s <= '1' when (ti_trigger_i = adhoc_i and ti_trigger_stbr_i = '1') else '0';

  trigger_sync_proc : process (clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i = '1' then
        ti_trigger_en0_s <= '0';
        ti_trigger_en1_s <= '0';
        ti_trigger_en2_s <= '0';
      else
        ti_trigger_en0_s <= ti_trigger_en_s;
        ti_trigger_en1_s <= ti_trigger_en0_s;
        ti_trigger_en2_s <= ti_trigger_en1_s;
      end if;
    end if;
  end process trigger_sync_proc;

  timing_trigger_s <= ti_trigger_en0_s or ti_trigger_en1_s or ti_trigger_en2_s;
  spy_trigger_o    <= frontend_trigger_i or timing_trigger_s;
end architecture rtl;
