-- Same bit50 fragment descriptors, evaluated at one original ADC sample/clock.
-- start_i may coincide with sample_valid_i for seamless adjacent fragments.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.daphne_subsystem_pkg.all;

entity fragment_peak_descriptors_serial is
  port (
    clock_i, reset_i, start_i : in std_logic;
    baseline_i : in std_logic_vector(13 downto 0);
    positive_pulse_i : in std_logic;
    threshold_i : in std_logic_vector(13 downto 0);
    sample_valid_i : in std_logic;
    sample_i : in std_logic_vector(13 downto 0);
    sample_index_i : in unsigned(8 downto 0);
    trailer_o : out peak_descriptor_trailer_t;
    done_o, overflow_o : out std_logic
  );
end;
architecture rtl of fragment_peak_descriptors_serial is
  function empty_trailer return peak_descriptor_trailer_t is
    variable t : peak_descriptor_trailer_t := (others=>(others=>'1'));
  begin
    for k in 0 to 4 loop t(2*k):=x"7FFFFFFF"; end loop;
    return t;
  end;
  constant EMPTY_C : peak_descriptor_trailer_t := empty_trailer;
  signal trailer_s : peak_descriptor_trailer_t := EMPTY_C;
  signal baseline_s, threshold_s, peak_s : unsigned(13 downto 0) := (others=>'0');
  signal positive_s, running_s, in_run_s : std_logic := '0';
  signal integral_s : unsigned(22 downto 0) := (others=>'0');
  signal start_s, peak_time_s : unsigned(8 downto 0) := (others=>'0');
  signal duration_s : unsigned(9 downto 0) := (others=>'0');
  signal slot_s : natural range 0 to 5 := 0;
  signal overflow_s : std_logic := '0';
begin
  trailer_o<=trailer_s; overflow_o<=overflow_s;
  process(clock_i)
    variable baseline, threshold, amplitude, peak : unsigned(13 downto 0);
    variable integral : unsigned(22 downto 0);
    variable run_start, peak_time, duration_field : unsigned(8 downto 0);
    variable duration : unsigned(9 downto 0);
    variable positive, in_run : std_logic;
    variable slot : natural range 0 to 5;
  begin
    if rising_edge(clock_i) then
      done_o<='0';
      if reset_i='1' then
        trailer_s<=EMPTY_C; running_s<='0'; in_run_s<='0'; slot_s<=0;
        overflow_s<='0'; integral_s<=(others=>'0'); peak_s<=(others=>'0');
        duration_s<=(others=>'0'); start_s<=(others=>'0'); peak_time_s<=(others=>'0');
      else
        baseline:=baseline_s; threshold:=threshold_s; positive:=positive_s;
        integral:=integral_s; peak:=peak_s; duration:=duration_s;
        run_start:=start_s; peak_time:=peak_time_s; in_run:=in_run_s; slot:=slot_s;
        if start_i='1' then
          baseline:=unsigned(baseline_i); threshold:=unsigned(threshold_i); positive:=positive_pulse_i;
          baseline_s<=baseline; threshold_s<=threshold; positive_s<=positive;
          trailer_s<=EMPTY_C; running_s<='1'; overflow_s<='0';
          integral:=(others=>'0'); peak:=(others=>'0'); duration:=(others=>'0');
          run_start:=(others=>'0'); peak_time:=(others=>'0'); in_run:='0'; slot:=0;
        end if;
        if sample_valid_i='1' and (running_s='1' or start_i='1') then
          amplitude:=(others=>'0');
          if positive='1' and unsigned(sample_i)>baseline then amplitude:=unsigned(sample_i)-baseline;
          elsif positive='0' and unsigned(sample_i)<baseline then amplitude:=baseline-unsigned(sample_i); end if;
          if amplitude>threshold then
            if in_run='0' then
              integral:=resize(amplitude,23); peak:=amplitude; duration:=to_unsigned(1,10);
              run_start:=sample_index_i; peak_time:=(others=>'0'); in_run:='1';
            else
              integral:=integral+resize(amplitude,23); duration:=duration+1;
              if amplitude>peak then peak:=amplitude; peak_time:=sample_index_i-run_start; end if;
            end if;
          end if;
          -- There is at most one completed excursion per original sample.
          if in_run='1' and (amplitude<=threshold or sample_index_i=511) then
            if slot<5 then
              if duration>511 then duration_field:=to_unsigned(511,9);
              else duration_field:=resize(duration,9); end if;
              for k in 0 to 4 loop
                if slot=k then
                  trailer_s(2*k)<='1' & std_logic_vector(integral) & "11110001";
                  trailer_s(2*k+1)<=std_logic_vector(duration_field) & std_logic_vector(peak_time) & std_logic_vector(peak);
                  case k is
                    when 0 => trailer_s(10)(31 downto 22)<='0' & std_logic_vector(run_start);
                    when 1 => trailer_s(10)(21 downto 12)<='0' & std_logic_vector(run_start);
                    when 2 => trailer_s(10)(11 downto 2)<='0' & std_logic_vector(run_start);
                    when 3 => trailer_s(11)(31 downto 22)<='0' & std_logic_vector(run_start);
                    when others => trailer_s(11)(21 downto 12)<='0' & std_logic_vector(run_start);
                  end case;
                end if;
              end loop;
              slot:=slot+1;
            else overflow_s<='1'; end if;
            in_run:='0';
          end if;
          if sample_index_i=511 then running_s<='0'; done_o<='1'; end if;
        end if;
        integral_s<=integral; peak_s<=peak; duration_s<=duration;
        start_s<=run_start; peak_time_s<=peak_time; in_run_s<=in_run; slot_s<=slot;
      end if;
    end if;
  end process;
end;
