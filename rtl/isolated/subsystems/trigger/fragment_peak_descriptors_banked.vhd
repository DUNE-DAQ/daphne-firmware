-- One original ADC sample/clock, with indexed reads of the completed frame.
-- Payload RAM is deliberately not reset. Valid bits supply absent-slot values.
-- The completed bank remains readable while the next frame fills the other bank.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fragment_peak_descriptors_banked is
  -- The grouped 312.5 MHz reader registers its selected sample, then its
  -- amplitude. Native ADC-clocked users retain the original completion cycle.
  generic (PIPELINE_INPUT_G : boolean := false);
  port (
    clock_i, reset_i, start_i : in std_logic;
    baseline_i : in std_logic_vector(13 downto 0);
    positive_pulse_i : in std_logic;
    threshold_i : in std_logic_vector(13 downto 0);
    sample_valid_i : in std_logic;
    sample_i : in std_logic_vector(13 downto 0);
    sample_index_i : in unsigned(8 downto 0);
    -- 0..4: descriptor high/low words; 5: offset words 11/10.
    -- 6..7 return the absent-descriptor sentinel.
    read_index_i : in unsigned(2 downto 0);
    read_word_o : out std_logic_vector(63 downto 0);
    done_o, overflow_o : out std_logic
  );
end;

architecture rtl of fragment_peak_descriptors_banked is
  constant EMPTY_DESCRIPTOR_C : std_logic_vector(63 downto 0) := x"FFFFFFFF7FFFFFFF";
  type descriptor_memory_t is array (0 to 15) of std_logic_vector(63 downto 0);
  signal descriptor_memory_s : descriptor_memory_t;
  attribute ram_style : string;
  attribute ram_style of descriptor_memory_s : signal is "distributed";
  type valid_banks_t is array (0 to 1) of std_logic_vector(4 downto 0);
  type offsets_t is array (0 to 4) of unsigned(8 downto 0);
  type offset_banks_t is array (0 to 1) of offsets_t;
  signal valid_s : valid_banks_t := (others=>(others=>'0'));
  signal offsets_s : offset_banks_t := (others=>(others=>(others=>'1')));
  signal working_bank_s, completed_bank_s : natural range 0 to 1 := 0;
  signal baseline_s, threshold_s, peak_s : unsigned(13 downto 0) := (others=>'0');
  signal positive_s, running_s, in_run_s : std_logic := '0';
  signal sample_start_s, sample_valid_s : std_logic := '0';
  signal sample_index_s : unsigned(8 downto 0) := (others=>'0');
  signal sample_threshold_s : unsigned(13 downto 0) := (others=>'0');
  signal integral_s : unsigned(22 downto 0) := (others=>'0');
  signal amplitude_s : unsigned(13 downto 0) := (others=>'0');
  signal integral_sum_s : unsigned(22 downto 0);
  function integral_dsp_mode(pipelined : boolean) return string is
  begin
    -- At 312.5 MHz the short fabric adder avoids the DSP feedback/control path.
    -- Keep the native ADC-clocked implementation's established DSP mapping.
    if pipelined then return "no"; else return "yes"; end if;
  end function;
  attribute use_dsp : string;
  attribute use_dsp of integral_sum_s : signal is integral_dsp_mode(PIPELINE_INPUT_G);
  signal start_s, peak_time_s : unsigned(8 downto 0) := (others=>'0');
  signal duration_s : unsigned(9 downto 0) := (others=>'0');
  signal slot_s : natural range 0 to 5 := 0;
  signal working_overflow_s, completed_overflow_s : std_logic := '0';
begin
  overflow_o <= completed_overflow_s;
  -- Configuration is captured at the input boundary, independently of the
  -- processing latency. A restart/sample0 uses the arriving configuration.
  process(clock_i)
  begin
    if rising_edge(clock_i) then
      if reset_i='0' and start_i='1' then
        baseline_s<=unsigned(baseline_i); positive_s<=positive_pulse_i;
      end if;
    end if;
  end process;

  native_input : if not PIPELINE_INPUT_G generate
    sample_start_s<=start_i; sample_valid_s<=sample_valid_i;
    sample_index_s<=sample_index_i; sample_threshold_s<=unsigned(threshold_i);
    process(all)
      variable baseline : unsigned(13 downto 0);
      variable positive : std_logic;
    begin
      baseline:=baseline_s; positive:=positive_s;
      if start_i='1' then baseline:=unsigned(baseline_i); positive:=positive_pulse_i; end if;
      amplitude_s<=(others=>'0');
      if positive='1' and unsigned(sample_i)>baseline then amplitude_s<=unsigned(sample_i)-baseline;
      elsif positive='0' and unsigned(sample_i)<baseline then amplitude_s<=baseline-unsigned(sample_i); end if;
    end process;
  end generate;

  grouped_input : if PIPELINE_INPUT_G generate
    signal raw_sample_s, raw_baseline_s, raw_threshold_s : unsigned(13 downto 0) := (others=>'0');
    signal raw_positive_s, raw_start_s, raw_valid_s : std_logic := '0';
    signal raw_index_s : unsigned(8 downto 0) := (others=>'0');
  begin
    -- First isolate the BRAM output and channel mux. Then isolate polarity /
    -- baseline subtraction from the descriptor accumulator and peak logic.
    -- Every sample carries its start, valid, index and threshold through both
    -- stages, including bubbles and adjacent frames with different settings.
    process(clock_i)
    begin
      if rising_edge(clock_i) then
        if reset_i='1' then
          raw_start_s<='0'; raw_valid_s<='0';
          sample_start_s<='0'; sample_valid_s<='0';
        else
          raw_sample_s<=unsigned(sample_i); raw_index_s<=sample_index_i;
          raw_start_s<=start_i; raw_valid_s<=sample_valid_i;
          raw_threshold_s<=unsigned(threshold_i);
          raw_baseline_s<=baseline_s; raw_positive_s<=positive_s;
          if start_i='1' then
            raw_baseline_s<=unsigned(baseline_i); raw_positive_s<=positive_pulse_i;
          end if;
          amplitude_s<=(others=>'0');
          if raw_positive_s='1' and raw_sample_s>raw_baseline_s then
            amplitude_s<=raw_sample_s-raw_baseline_s;
          elsif raw_positive_s='0' and raw_sample_s<raw_baseline_s then
            amplitude_s<=raw_baseline_s-raw_sample_s;
          end if;
          sample_start_s<=raw_start_s; sample_valid_s<=raw_valid_s;
          sample_index_s<=raw_index_s; sample_threshold_s<=raw_threshold_s;
        end if;
      end if;
    end process;
  end generate;
  integral_sum_s <= integral_s+resize(amplitude_s,23);

  process(all)
    variable index : natural range 0 to 7;
    variable offsets : std_logic_vector(63 downto 0);
  begin
    index := to_integer(read_index_i);
    offsets := (others=>'1');
    offsets(31 downto 22) := not valid_s(completed_bank_s)(0) & std_logic_vector(offsets_s(completed_bank_s)(0));
    offsets(21 downto 12) := not valid_s(completed_bank_s)(1) & std_logic_vector(offsets_s(completed_bank_s)(1));
    offsets(11 downto 2) := not valid_s(completed_bank_s)(2) & std_logic_vector(offsets_s(completed_bank_s)(2));
    offsets(63 downto 54) := not valid_s(completed_bank_s)(3) & std_logic_vector(offsets_s(completed_bank_s)(3));
    offsets(53 downto 44) := not valid_s(completed_bank_s)(4) & std_logic_vector(offsets_s(completed_bank_s)(4));
    read_word_o <= EMPTY_DESCRIPTOR_C;
    if index < 5 then
      if valid_s(completed_bank_s)(index)='1' then
        read_word_o <= descriptor_memory_s(completed_bank_s*8+index);
      end if;
    elsif index=5 then
      read_word_o <= offsets;
    end if;
  end process;

  process(clock_i)
    variable threshold, amplitude, peak : unsigned(13 downto 0);
    variable integral : unsigned(22 downto 0);
    variable run_start, peak_time, duration_field : unsigned(8 downto 0);
    variable duration : unsigned(9 downto 0);
    variable in_run, overflow : std_logic;
    variable slot : natural range 0 to 5;
    variable bank : natural range 0 to 1;
  begin
    if rising_edge(clock_i) then
      done_o <= '0';
      if reset_i='1' then
        valid_s <= (others=>(others=>'0'));
        offsets_s <= (others=>(others=>(others=>'1')));
        working_bank_s <= 0; completed_bank_s <= 0;
        running_s <= '0'; in_run_s <= '0'; slot_s <= 0;
        working_overflow_s <= '0'; completed_overflow_s <= '0';
        integral_s <= (others=>'0'); peak_s <= (others=>'0');
        duration_s <= (others=>'0'); start_s <= (others=>'0'); peak_time_s <= (others=>'0');
      else
        threshold := threshold_s;
        integral := integral_s; peak := peak_s; duration := duration_s;
        run_start := start_s; peak_time := peak_time_s; in_run := in_run_s;
        slot := slot_s; bank := working_bank_s; overflow := working_overflow_s;
        if sample_start_s='1' then
          threshold := sample_threshold_s; threshold_s <= threshold;
          -- This toggles banks between frames, and safely restarts an unfinished
          -- frame without disturbing the last completed frame.
          bank := 1-completed_bank_s;
          valid_s(bank) <= (others=>'0');
          offsets_s(bank) <= (others=>(others=>'1'));
          running_s <= '1'; overflow := '0';
          integral := (others=>'0'); peak := (others=>'0'); duration := (others=>'0');
          run_start := (others=>'0'); peak_time := (others=>'0'); in_run := '0'; slot := 0;
        end if;
        if sample_valid_s='1' and (running_s='1' or sample_start_s='1') then
          amplitude := amplitude_s;
          if amplitude>threshold then
            if in_run='0' then
              integral := resize(amplitude,23); peak := amplitude; duration := to_unsigned(1,10);
              run_start := sample_index_s; peak_time := (others=>'0'); in_run := '1';
            else
              integral := integral_sum_s; duration := duration+1;
              if amplitude>peak then peak := amplitude; peak_time := sample_index_s-run_start; end if;
            end if;
          end if;
          -- At most one excursion closes per sample, so RAM has one write port.
          if in_run='1' and (amplitude<=threshold or sample_index_s=511) then
            if slot<5 then
              if duration>511 then duration_field := to_unsigned(511,9);
              else duration_field := resize(duration,9); end if;
              descriptor_memory_s(bank*8+slot) <=
                std_logic_vector(duration_field) & std_logic_vector(peak_time) & std_logic_vector(peak) &
                '1' & std_logic_vector(integral) & "11110001";
              -- Fixed slots keep the small resettable metadata separate from
              -- the single indexed, unreset RAM payload write above.
              for k in 0 to 4 loop
                if slot=k then
                  valid_s(bank)(k) <= '1'; offsets_s(bank)(k) <= run_start;
                end if;
              end loop;
              slot := slot+1;
            else overflow := '1'; end if;
            in_run := '0';
          end if;
          if sample_index_s=511 then
            running_s <= '0'; done_o <= '1';
            completed_bank_s <= bank; completed_overflow_s <= overflow;
          end if;
        end if;
        working_bank_s <= bank; working_overflow_s <= overflow;
        integral_s <= integral; peak_s <= peak; duration_s <= duration;
        start_s <= run_start; peak_time_s <= peak_time; in_run_s <= in_run; slot_s <= slot;
      end if;
    end if;
  end process;
end;
