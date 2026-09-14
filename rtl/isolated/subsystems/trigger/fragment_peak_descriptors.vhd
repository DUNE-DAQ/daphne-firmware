-- Fragment-local descriptors for the fixed-512 continuation format.
-- Raw ADC polarity/baseline are explicit and frozen at start_i. Each slot
-- describes one contiguous excursion strictly above threshold_i, clipped to
-- this fragment. Wire field positions and unused-slot sentinels are legacy.
-- This is a new descriptor algorithm, identified by header bit 50; it does
-- not claim equivalence to the imported filtered peak detector.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.daphne_subsystem_pkg.all;

entity fragment_peak_descriptors is
  port (
    clock_i, reset_i, start_i : in std_logic;
    baseline_i : in std_logic_vector(13 downto 0);
    positive_pulse_i : in std_logic;
    threshold_i : in std_logic_vector(13 downto 0);
    pair_valid_i : in std_logic;
    sample0_i, sample1_i : in std_logic_vector(13 downto 0);
    pair_index_i : in unsigned(7 downto 0);
    trailer_o : out peak_descriptor_trailer_t;
    done_o, overflow_o : out std_logic
  );
end entity;

architecture rtl of fragment_peak_descriptors is
  function empty_trailer return peak_descriptor_trailer_t is
    variable t : peak_descriptor_trailer_t := (others => (others => '1'));
  begin
    for k in 0 to 4 loop
      t(2*k) := x"7FFFFFFF";
    end loop;
    return t;
  end function;
  constant EMPTY_C : peak_descriptor_trailer_t := empty_trailer;
  signal trailer_s : peak_descriptor_trailer_t := EMPTY_C;
  signal baseline_s, threshold_s : unsigned(13 downto 0) := (others => '0');
  signal positive_s, running_s, in_run_s : std_logic := '0';
  signal integral_s : unsigned(22 downto 0) := (others => '0');
  signal peak_s : unsigned(13 downto 0) := (others => '0');
  signal start_s, peak_time_s : unsigned(8 downto 0) := (others => '0');
  signal duration_s : unsigned(9 downto 0) := (others => '0');
  signal slot_s : integer range 0 to 5 := 0;
  signal overflow_s : std_logic := '0';
begin
  trailer_o <= trailer_s;
  overflow_o <= overflow_s;

  process(clock_i)
    -- At most two excursions can close in one input pair (the second only
    -- when sample 511 starts a new excursion). Keep those events separate
    -- from fixed-index slot writes to avoid cascaded variable-index updates
    -- of the complete 384-bit trailer.
    variable close0_valid_v, close1_valid_v : boolean;
    variable close0_slot_v, close1_slot_v : integer range 0 to 4;
    variable close0_data_v, close1_data_v : std_logic_vector(63 downto 0);
    variable close0_start_v, close1_start_v : std_logic_vector(9 downto 0);
    variable close_data_v : std_logic_vector(63 downto 0);
    variable selected_start_v : std_logic_vector(9 downto 0);
    variable integral_v : unsigned(22 downto 0);
    variable peak_v : unsigned(13 downto 0);
    variable start_v, peak_time_v : unsigned(8 downto 0);
    variable duration_v : unsigned(9 downto 0);
    variable slot_v : integer range 0 to 5;
    variable in_run_v, overflow_v : std_logic;
    variable sample_v : unsigned(13 downto 0);
    variable amplitude_v : unsigned(13 downto 0);
    variable index_v : unsigned(8 downto 0);
    variable duration_field_v : unsigned(8 downto 0);
    procedure close_run is
    begin
      if in_run_v = '1' then
        if slot_v < 5 then
          if duration_v > 511 then
            duration_field_v := to_unsigned(511, 9);
          else
            duration_field_v := resize(duration_v, 9);
          end if;
          -- Number_Peaks=1: one contiguous threshold excursion per slot.
          close_data_v := std_logic_vector(duration_field_v) &
                          std_logic_vector(peak_time_v) & std_logic_vector(peak_v) &
                          '1' & std_logic_vector(integral_v) & "1111" & "0001";
          if not close0_valid_v then
            close0_valid_v := true; close0_slot_v := slot_v;
            close0_data_v := close_data_v;
            close0_start_v := '0' & std_logic_vector(start_v);
          else
            close1_valid_v := true; close1_slot_v := slot_v;
            close1_data_v := close_data_v;
            close1_start_v := '0' & std_logic_vector(start_v);
          end if;
          slot_v := slot_v + 1;
        else
          overflow_v := '1';
        end if;
        in_run_v := '0';
      end if;
    end procedure;
  begin
    if rising_edge(clock_i) then
      done_o <= '0';
      if reset_i = '1' or start_i = '1' then
        trailer_s <= EMPTY_C;
        integral_s <= (others => '0');
        peak_s <= (others => '0');
        start_s <= (others => '0');
        peak_time_s <= (others => '0');
        duration_s <= (others => '0');
        slot_s <= 0;
        in_run_s <= '0';
        overflow_s <= '0';
        running_s <= start_i and not reset_i;
        baseline_s <= unsigned(baseline_i);
        threshold_s <= unsigned(threshold_i);
        positive_s <= positive_pulse_i;
      elsif pair_valid_i = '1' and running_s = '1' then
        close0_valid_v := false; close1_valid_v := false;
        close0_slot_v := 0; close1_slot_v := 0;
        close0_data_v := (others=>'0'); close1_data_v := (others=>'0');
        close0_start_v := (others=>'0'); close1_start_v := (others=>'0');
        integral_v := integral_s;
        peak_v := peak_s;
        start_v := start_s;
        peak_time_v := peak_time_s;
        duration_v := duration_s;
        slot_v := slot_s;
        in_run_v := in_run_s;
        overflow_v := overflow_s;
        for k in 0 to 1 loop
          index_v := pair_index_i & '0';
          if k = 0 then
            sample_v := unsigned(sample0_i);
          else
            sample_v := unsigned(sample1_i);
            index_v := index_v + 1;
          end if;
          amplitude_v := (others => '0');
          if positive_s = '1' and sample_v > baseline_s then
            amplitude_v := sample_v - baseline_s;
          elsif positive_s = '0' and sample_v < baseline_s then
            amplitude_v := baseline_s - sample_v;
          end if;
          if amplitude_v > threshold_s then
            if in_run_v = '0' then
              in_run_v := '1';
              integral_v := resize(amplitude_v, 23);
              peak_v := amplitude_v;
              start_v := index_v;
              peak_time_v := (others => '0');
              duration_v := to_unsigned(1, 10);
            else
              -- 512*16383=8388096 fits the existing unsigned23 field.
              integral_v := integral_v + resize(amplitude_v, 23);
              duration_v := duration_v + 1;
              if amplitude_v > peak_v then
                peak_v := amplitude_v;
                peak_time_v := index_v - start_v;
              end if;
            end if;
          else
            close_run;
          end if;
        end loop;
        if pair_index_i = 255 then
          close_run;
          running_s <= '0';
          done_o <= '1';
        end if;
        for slot in 0 to 4 loop
          if (close0_valid_v and close0_slot_v=slot) or
             (close1_valid_v and close1_slot_v=slot) then
            if close0_valid_v and close0_slot_v=slot then
              trailer_s(2*slot) <= close0_data_v(31 downto 0);
              trailer_s(2*slot+1) <= close0_data_v(63 downto 32);
              selected_start_v := close0_start_v;
            else
              trailer_s(2*slot) <= close1_data_v(31 downto 0);
              trailer_s(2*slot+1) <= close1_data_v(63 downto 32);
              selected_start_v := close1_start_v;
            end if;
            case slot is
              when 0 => trailer_s(10)(31 downto 22) <= selected_start_v;
              when 1 => trailer_s(10)(21 downto 12) <= selected_start_v;
              when 2 => trailer_s(10)(11 downto 2) <= selected_start_v;
              when 3 => trailer_s(11)(31 downto 22) <= selected_start_v;
              when others => trailer_s(11)(21 downto 12) <= selected_start_v;
            end case;
          end if;
        end loop;
        integral_s <= integral_v;
        peak_s <= peak_v;
        start_s <= start_v;
        peak_time_s <= peak_time_v;
        duration_s <= duration_v;
        slot_s <= slot_v;
        in_run_s <= in_run_v;
        overflow_s <= overflow_v;
      end if;
    end if;
  end process;
end architecture;
