-- peak_descriptor_compact.vhd
-- Repo-owned compact peak-descriptor path for the grouped 512-sample readout.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_subsystem_pkg.all;

entity peak_descriptor_compact is
  generic (
    FRAME_SAMPLE_COUNT_G    : positive := 512;
    PRETRIGGER_SAMPLES_G    : natural  := 64;
    TRAILER_READY_MARGIN_G   : natural  := 8;
    MIN_TIME_OVER_BASELINE_G : natural  := 20
  );
  port (
    clock_i   : in  std_logic;
    reset_i   : in  std_logic;
    trigger_i : in  trigger_xcorr_result_t;
    control_i : in  peak_descriptor_control_t;
    result_o  : out peak_descriptor_result_t;
    trailer_o : out peak_descriptor_trailer_t
  );
end entity peak_descriptor_compact;

architecture rtl of peak_descriptor_compact is
  constant SLOPE_SHORT_DELAY_C : positive := 16;
  constant SLOPE_LONG_DELAY_C  : positive := 20;
  constant FRAME_POST_SAMPLES_C : natural :=
    FRAME_SAMPLE_COUNT_G - PRETRIGGER_SAMPLES_G;
  constant TRAILER_READY_COUNT_C : natural :=
    FRAME_POST_SAMPLES_C - TRAILER_READY_MARGIN_G;
  constant TIME_OVER_MAX_C : unsigned(8 downto 0) := (others => '1');
  constant SLOPE_MIN_C : signed(14 downto 0) := to_signed(-8192, 15);
  constant SLOPE_MAX_C : signed(14 downto 0) := to_signed(8191, 15);

  type sample_delay_array_t is array (natural range <>) of signed(13 downto 0);

  signal sample_delay_s       : sample_delay_array_t(0 to SLOPE_LONG_DELAY_C - 1) :=
    (others => (others => '0'));
  signal collecting_s         : std_logic := '0';
  signal sample_count_s       : natural range 0 to FRAME_SAMPLE_COUNT_G := 0;
  signal time_over_s          : unsigned(8 downto 0) := (others => '0');
  signal time_peak_s          : unsigned(8 downto 0) := (others => '0');
  signal time_start_s         : unsigned(9 downto 0) :=
    to_unsigned(PRETRIGGER_SAMPLES_G, 10);
  signal adc_peak_s           : unsigned(13 downto 0) := (others => '0');
  signal adc_integral_s       : unsigned(22 downto 0) := (others => '0');
  signal number_peaks_s       : unsigned(3 downto 0) := (others => '0');
  signal amplitude_s          : signed(14 downto 0) := (others => '0');
  signal slope_current_s      : signed(13 downto 0) := (others => '0');
  signal slope_threshold_s    : signed(6 downto 0) := (others => '0');
  signal peak_allowed_s       : std_logic := '1';
  signal peak_current_s       : std_logic := '0';
  signal data_available_s     : std_logic := '0';
  signal trailer_available_s  : std_logic := '0';
  signal self_trigger_s       : std_logic := '0';
  signal info_previous_s      : std_logic := '0';
  signal trailer_words_s      : peak_descriptor_trailer_t :=
    (others => (others => '0'));

  function descriptor_word0(
    integral_i : unsigned(22 downto 0);
    peaks_i    : unsigned(3 downto 0)
  ) return std_logic_vector is
  begin
    return '1' & std_logic_vector(integral_i) & "1111" & std_logic_vector(peaks_i);
  end function;

  function descriptor_word1(
    time_over_i : unsigned(8 downto 0);
    time_peak_i : unsigned(8 downto 0);
    peak_i      : unsigned(13 downto 0)
  ) return std_logic_vector is
  begin
    return std_logic_vector(time_over_i) &
           std_logic_vector(time_peak_i) &
           std_logic_vector(peak_i);
  end function;

  function sentinel_trailer return peak_descriptor_trailer_t is
    variable result_v : peak_descriptor_trailer_t := (others => (others => '1'));
  begin
    result_v(0) := X"7FFFFFFF";
    result_v(2) := X"7FFFFFFF";
    result_v(4) := X"7FFFFFFF";
    result_v(6) := X"7FFFFFFF";
    result_v(8) := X"7FFFFFFF";
    return result_v;
  end function;
begin
  assert PRETRIGGER_SAMPLES_G < FRAME_SAMPLE_COUNT_G
    report "peak_descriptor_compact requires PRETRIGGER_SAMPLES_G < FRAME_SAMPLE_COUNT_G"
    severity failure;

  assert TRAILER_READY_MARGIN_G < FRAME_POST_SAMPLES_C
    report "peak_descriptor_compact requires TRAILER_READY_MARGIN_G < post-trigger frame samples"
    severity failure;

  main_proc : process(clock_i)
    variable sample_v            : signed(13 downto 0);
    variable amplitude_v         : signed(14 downto 0);
    variable slope_ref_v         : signed(13 downto 0);
    variable slope15_v           : signed(14 downto 0);
    variable slope14_v           : signed(13 downto 0);
    variable threshold14_v       : signed(13 downto 0);
    variable threshold_release_v : signed(13 downto 0);
    variable magnitude15_v       : unsigned(14 downto 0);
    variable magnitude14_v       : unsigned(13 downto 0);
    variable integral24_v        : unsigned(23 downto 0);
    variable peak_current_v      : std_logic;
    variable finish_v            : std_logic;
    variable next_time_over_v    : unsigned(8 downto 0);
    variable next_time_peak_v    : unsigned(8 downto 0);
    variable next_adc_peak_v     : unsigned(13 downto 0);
    variable next_integral_v     : unsigned(22 downto 0);
    variable next_peaks_v        : unsigned(3 downto 0);
    variable trailer_v           : peak_descriptor_trailer_t;
  begin
    if rising_edge(clock_i) then
      sample_v      := signed(trigger_i.descriptor_sample);
      amplitude_v   := resize(sample_v, amplitude_v'length);
      threshold14_v := resize(slope_threshold_s, threshold14_v'length);
      threshold_release_v := threshold14_v + to_signed(5, threshold14_v'length);

      if control_i.config(6) = '0' then
        slope_ref_v := sample_delay_s(SLOPE_SHORT_DELAY_C - 1);
      else
        slope_ref_v := sample_delay_s(SLOPE_LONG_DELAY_C - 1);
      end if;
      slope15_v := resize(sample_delay_s(0), slope15_v'length) -
                   resize(slope_ref_v, slope15_v'length);
      if slope15_v < SLOPE_MIN_C then
        slope14_v := to_signed(-8192, slope14_v'length);
      elsif slope15_v > SLOPE_MAX_C then
        slope14_v := to_signed(8191, slope14_v'length);
      else
        slope14_v := resize(slope15_v, slope14_v'length);
      end if;

      peak_current_v := '0';
      if peak_allowed_s = '1' and slope14_v <= threshold14_v then
        peak_current_v := '1';
      end if;

      data_available_s    <= '0';
      trailer_available_s <= '0';
      self_trigger_s      <= trigger_i.trigger_pulse;
      slope_threshold_s   <= signed(control_i.config(13 downto 7));
      amplitude_s         <= amplitude_v;
      slope_current_s     <= slope14_v;
      peak_current_s      <= peak_current_v;

      sample_delay_s(0) <= sample_v;
      for idx in 1 to SLOPE_LONG_DELAY_C - 1 loop
        sample_delay_s(idx) <= sample_delay_s(idx - 1);
      end loop;

      if reset_i = '1' then
        collecting_s        <= '0';
        sample_delay_s      <= (others => (others => '0'));
        sample_count_s      <= 0;
        time_over_s         <= (others => '0');
        time_peak_s         <= (others => '0');
        time_start_s        <= to_unsigned(PRETRIGGER_SAMPLES_G, time_start_s'length);
        adc_peak_s          <= (others => '0');
        adc_integral_s      <= (others => '0');
        number_peaks_s      <= (others => '0');
        peak_allowed_s      <= '1';
        peak_current_s      <= '0';
        data_available_s    <= '0';
        trailer_available_s <= '0';
        self_trigger_s      <= '0';
        info_previous_s     <= '0';
        trailer_words_s     <= sentinel_trailer;
      else
        if peak_current_v = '1' then
          peak_allowed_s <= '0';
        elsif slope14_v > threshold_release_v then
          peak_allowed_s <= '1';
        end if;

        if trigger_i.trigger_pulse = '1' and trigger_i.enabled = '1' and
           control_i.frame_match = '0' then
          info_previous_s <= '1';
        elsif collecting_s = '0' then
          info_previous_s <= '0';
        end if;

        if trigger_i.trigger_pulse = '1' and trigger_i.enabled = '1' and
           control_i.frame_match = '1' and collecting_s = '0' then
          collecting_s   <= '1';
          sample_count_s <= 0;
          time_over_s    <= to_unsigned(1, time_over_s'length);
          time_peak_s    <= (others => '0');
          time_start_s   <= to_unsigned(PRETRIGGER_SAMPLES_G, time_start_s'length);
          adc_peak_s     <= (others => '0');
          adc_integral_s <= (others => '0');
          number_peaks_s <= to_unsigned(1, number_peaks_s'length);
          trailer_words_s <= sentinel_trailer;
        elsif collecting_s = '1' then
          next_time_over_v := time_over_s;
          next_time_peak_v := time_peak_s;
          next_adc_peak_v  := adc_peak_s;
          next_integral_v  := adc_integral_s;
          next_peaks_v     := number_peaks_s;

          if next_time_over_v /= TIME_OVER_MAX_C then
            next_time_over_v := next_time_over_v + 1;
          end if;

          if amplitude_v < 0 then
            magnitude15_v := unsigned(-amplitude_v);
            if magnitude15_v(14) = '1' then
              magnitude14_v := (others => '1');
            else
              magnitude14_v := magnitude15_v(13 downto 0);
            end if;

            integral24_v := resize(adc_integral_s, integral24_v'length) +
                            resize(magnitude15_v, integral24_v'length);
            if integral24_v(23) = '1' then
              next_integral_v := (others => '1');
            else
              next_integral_v := integral24_v(22 downto 0);
            end if;

            if magnitude14_v > adc_peak_s then
              next_adc_peak_v := magnitude14_v;
              next_time_peak_v := time_over_s;
            end if;
          end if;

          if peak_current_v = '1' and number_peaks_s /= "1111" then
            next_peaks_v := number_peaks_s + 1;
          end if;

          finish_v := '0';
          if (amplitude_v > 0 and to_integer(time_over_s) > MIN_TIME_OVER_BASELINE_G) or
             sample_count_s >= TRAILER_READY_COUNT_C then
            finish_v := '1';
          end if;

          time_over_s    <= next_time_over_v;
          time_peak_s    <= next_time_peak_v;
          adc_peak_s     <= next_adc_peak_v;
          adc_integral_s <= next_integral_v;
          number_peaks_s <= next_peaks_v;

          if sample_count_s < FRAME_SAMPLE_COUNT_G then
            sample_count_s <= sample_count_s + 1;
          end if;

          if finish_v = '1' then
            trailer_v := sentinel_trailer;
            trailer_v(0) := descriptor_word0(next_integral_v, next_peaks_v);
            trailer_v(1) := descriptor_word1(
              next_time_over_v,
              next_time_peak_v,
              next_adc_peak_v
            );
            trailer_v(10)(31 downto 22) := std_logic_vector(time_start_s);
            trailer_words_s <= trailer_v;
            collecting_s <= '0';
            data_available_s <= '1';
            trailer_available_s <= '1';
          end if;
        end if;
      end if;
    end if;
  end process main_proc;

  result_o <= (
    self_trigger       => self_trigger_s,
    data_available     => data_available_s,
    trailer_available  => trailer_available_s,
    time_peak          => std_logic_vector(time_peak_s),
    time_over_baseline => std_logic_vector(time_over_s),
    time_start         => std_logic_vector(time_start_s),
    adc_peak           => std_logic_vector(adc_peak_s),
    adc_integral       => std_logic_vector(adc_integral_s),
    number_peaks       => std_logic_vector(number_peaks_s),
    amplitude          => std_logic_vector(amplitude_s),
    peak_current       => peak_current_s,
    slope_current      => std_logic_vector(slope_current_s),
    slope_threshold    => std_logic_vector(slope_threshold_s),
    detection          => collecting_s,
    sending            => collecting_s,
    info_previous      => info_previous_s
  );

  trailer_o <= trailer_words_s;
end architecture rtl;
