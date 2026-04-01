library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity peak_descriptor_channel is
  port (
    clock_i   : in  std_logic;
    reset_i   : in  std_logic;
    trigger_i : in  trigger_xcorr_result_t;
    control_i : in  peak_descriptor_control_t;
    result_o  : out peak_descriptor_result_t;
    trailer_o : out peak_descriptor_trailer_t
  );
end entity peak_descriptor_channel;

architecture rtl of peak_descriptor_channel is
  component Self_Trigger_Primitive_Calculation is
    port (
      clock                  : in  std_logic;
      reset                  : in  std_logic;
      din                    : in  std_logic_vector(13 downto 0);
      Config_Param           : in  std_logic_vector(13 downto 0);
      Ext_Self_Trigger       : in  std_logic;
      Match_with_Frame       : in  std_logic;
      Self_trigger           : out std_logic;
      Data_Available         : out std_logic;
      Time_Peak              : out std_logic_vector(8 downto 0);
      Time_Over_Baseline     : out std_logic_vector(8 downto 0);
      Time_Start             : out std_logic_vector(9 downto 0);
      ADC_Peak               : out std_logic_vector(13 downto 0);
      ADC_Integral           : out std_logic_vector(22 downto 0);
      Number_Peaks           : out std_logic_vector(3 downto 0);
      Baseline               : in  std_logic_vector(13 downto 0);
      Amplitude              : out std_logic_vector(14 downto 0);
      Peak_Current           : out std_logic;
      Slope_Current          : out std_logic_vector(13 downto 0);
      Slope_Threshold        : out std_logic_vector(6 downto 0);
      Detection              : out std_logic;
      Sending                : out std_logic;
      Info_Previous          : out std_logic;
      Data_Available_Trailer : out std_logic;
      Trailer_Word_0         : out std_logic_vector(31 downto 0);
      Trailer_Word_1         : out std_logic_vector(31 downto 0);
      Trailer_Word_2         : out std_logic_vector(31 downto 0);
      Trailer_Word_3         : out std_logic_vector(31 downto 0);
      Trailer_Word_4         : out std_logic_vector(31 downto 0);
      Trailer_Word_5         : out std_logic_vector(31 downto 0);
      Trailer_Word_6         : out std_logic_vector(31 downto 0);
      Trailer_Word_7         : out std_logic_vector(31 downto 0);
      Trailer_Word_8         : out std_logic_vector(31 downto 0);
      Trailer_Word_9         : out std_logic_vector(31 downto 0);
      Trailer_Word_10        : out std_logic_vector(31 downto 0);
      Trailer_Word_11        : out std_logic_vector(31 downto 0)
    );
  end component;

  signal self_trigger_s      : std_logic;
  signal data_available_s    : std_logic;
  signal trailer_available_s : std_logic;
  signal time_peak_s         : std_logic_vector(8 downto 0);
  signal time_over_s         : std_logic_vector(8 downto 0);
  signal time_start_s        : std_logic_vector(9 downto 0);
  signal adc_peak_s          : std_logic_vector(13 downto 0);
  signal adc_integral_s      : std_logic_vector(22 downto 0);
  signal number_peaks_s      : std_logic_vector(3 downto 0);
  signal amplitude_s         : std_logic_vector(14 downto 0);
  signal peak_current_s      : std_logic;
  signal slope_current_s     : std_logic_vector(13 downto 0);
  signal slope_threshold_s   : std_logic_vector(6 downto 0);
  signal detection_s         : std_logic;
  signal sending_s           : std_logic;
  signal info_previous_s     : std_logic;
  signal trailer_words_s     : peak_descriptor_trailer_t;
begin
  descriptor_inst : Self_Trigger_Primitive_Calculation
    port map (
      clock                  => clock_i,
      reset                  => reset_i,
      din                    => trigger_i.descriptor_sample,
      Config_Param           => control_i.config,
      Ext_Self_Trigger       => trigger_i.trigger_pulse,
      Match_with_Frame       => control_i.frame_match,
      Self_trigger           => self_trigger_s,
      Data_Available         => data_available_s,
      Time_Peak              => time_peak_s,
      Time_Over_Baseline     => time_over_s,
      Time_Start             => time_start_s,
      ADC_Peak               => adc_peak_s,
      ADC_Integral           => adc_integral_s,
      Number_Peaks           => number_peaks_s,
      Baseline               => trigger_i.baseline,
      Amplitude              => amplitude_s,
      Peak_Current           => peak_current_s,
      Slope_Current          => slope_current_s,
      Slope_Threshold        => slope_threshold_s,
      Detection              => detection_s,
      Sending                => sending_s,
      Info_Previous          => info_previous_s,
      Data_Available_Trailer => trailer_available_s,
      Trailer_Word_0         => trailer_words_s(0),
      Trailer_Word_1         => trailer_words_s(1),
      Trailer_Word_2         => trailer_words_s(2),
      Trailer_Word_3         => trailer_words_s(3),
      Trailer_Word_4         => trailer_words_s(4),
      Trailer_Word_5         => trailer_words_s(5),
      Trailer_Word_6         => trailer_words_s(6),
      Trailer_Word_7         => trailer_words_s(7),
      Trailer_Word_8         => trailer_words_s(8),
      Trailer_Word_9         => trailer_words_s(9),
      Trailer_Word_10        => trailer_words_s(10),
      Trailer_Word_11        => trailer_words_s(11)
    );

  result_o <= (
    self_trigger       => self_trigger_s,
    data_available     => data_available_s,
    trailer_available  => trailer_available_s,
    time_peak          => time_peak_s,
    time_over_baseline => time_over_s,
    time_start         => time_start_s,
    adc_peak           => adc_peak_s,
    adc_integral       => adc_integral_s,
    number_peaks       => number_peaks_s,
    amplitude          => amplitude_s,
    peak_current       => peak_current_s,
    slope_current      => slope_current_s,
    slope_threshold    => slope_threshold_s,
    detection          => detection_s,
    sending            => sending_s,
    info_previous      => info_previous_s
  );

  trailer_o <= trailer_words_s;
end architecture rtl;
