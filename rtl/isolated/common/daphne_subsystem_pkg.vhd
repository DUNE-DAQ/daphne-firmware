library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package daphne_subsystem_pkg is

  type sample14_array_t is array (natural range <>) of std_logic_vector(13 downto 0);
  type std_logic_array_t is array (natural range <>) of std_logic;
  type slv28_array_t is array (natural range <>) of std_logic_vector(27 downto 0);
  type slv11_array_t is array (natural range <>) of std_logic_vector(10 downto 0);
  type slv64_array_t is array (natural range <>) of std_logic_vector(63 downto 0);
  type slv72_array_t is array (natural range <>) of std_logic_vector(71 downto 0);

  type frontend_tap_array_t is array (4 downto 0) of std_logic_vector(8 downto 0);
  type frontend_bitslip_array_t is array (4 downto 0) of std_logic_vector(3 downto 0);

  type frontend_alignment_control_t is record
    idelayctrl_reset : std_logic;
    iserdes_reset    : std_logic;
    idelay_en_vtc    : std_logic;
    idelay_tap       : frontend_tap_array_t;
    iserdes_bitslip  : frontend_bitslip_array_t;
  end record;

  type frontend_alignment_status_t is record
    idelayctrl_ready : std_logic;
    format_ok        : std_logic;
    training_ok      : std_logic;
    alignment_valid  : std_logic;
  end record;

  type afe_alignment_control_t is record
    idelay_load      : std_logic;
    idelay_tap       : std_logic_vector(8 downto 0);
    iserdes_bitslip  : std_logic_vector(3 downto 0);
  end record;

  type afe_alignment_status_t is record
    format_ok       : std_logic;
    training_ok     : std_logic;
    alignment_valid : std_logic;
  end record;

  type afe_alignment_control_array_t is array (4 downto 0) of afe_alignment_control_t;
  type afe_alignment_status_array_t is array (4 downto 0) of afe_alignment_status_t;

  type frontend_prereq_t is record
    config_ready : std_logic;
    timing_ready : std_logic;
  end record;

  type timing_control_t is record
    use_endpoint_clock : std_logic;
    mmcm0_reset        : std_logic;
    mmcm1_reset        : std_logic;
    endpoint_reset     : std_logic;
    endpoint_addr      : std_logic_vector(15 downto 0);
  end record;

  type timing_status_t is record
    mmcm0_locked    : std_logic;
    mmcm1_locked    : std_logic;
    endpoint_ready  : std_logic;
    endpoint_state  : std_logic_vector(3 downto 0);
    timestamp_valid : std_logic;
  end record;

  type analog_control_t is record
    afe_resetn       : std_logic;
    dac_resetn       : std_logic;
    afe_config_valid : std_logic;
    dac_config_valid : std_logic;
  end record;

  type analog_status_t is record
    config_ready : std_logic;
    afe_ready    : std_logic;
    dac_ready    : std_logic;
  end record;

  type afe_config_command_t is record
    afe_write_valid    : std_logic;
    afe_write_data     : std_logic_vector(23 downto 0);
    trim_write_valid   : std_logic;
    trim_write_data    : std_logic_vector(31 downto 0);
    offset_write_valid : std_logic;
    offset_write_data  : std_logic_vector(31 downto 0);
  end record;

  type afe_config_status_t is record
    afe_readback : std_logic_vector(23 downto 0);
    afe_busy     : std_logic;
    trim_busy    : std_logic;
    offset_busy  : std_logic;
    ready        : std_logic;
  end record;

  type afe_config_command_array_t is array (4 downto 0) of afe_config_command_t;
  type afe_config_status_array_t is array (4 downto 0) of afe_config_status_t;
  type afe_config_command_bank_t is array (natural range <>) of afe_config_command_t;
  type afe_config_status_bank_t is array (natural range <>) of afe_config_status_t;

  type acquisition_readiness_t is record
    config_ready    : std_logic;
    timing_ready    : std_logic;
    alignment_ready : std_logic;
  end record;

  type trigger_xcorr_control_t is record
    enable                 : std_logic;
    afe_comp_enable        : std_logic;
    invert_enable          : std_logic;
    filter_output_selector : std_logic_vector(1 downto 0);
    threshold_xc           : std_logic_vector(27 downto 0);
    adhoc                  : std_logic_vector(7 downto 0);
    ti_trigger             : std_logic_vector(7 downto 0);
    ti_trigger_stbr        : std_logic;
  end record;

  type trigger_xcorr_result_t is record
    enabled           : std_logic;
    trigger_pulse     : std_logic;
    baseline          : std_logic_vector(13 downto 0);
    monitor_sample    : std_logic_vector(13 downto 0);
    descriptor_sample : std_logic_vector(13 downto 0);
    trigger_sample    : std_logic_vector(13 downto 0);
    trigger_timestamp : std_logic_vector(63 downto 0);
  end record;

  type peak_descriptor_control_t is record
    config      : std_logic_vector(13 downto 0);
    frame_match : std_logic;
  end record;

  type peak_descriptor_result_t is record
    self_trigger       : std_logic;
    data_available     : std_logic;
    trailer_available  : std_logic;
    time_peak          : std_logic_vector(8 downto 0);
    time_over_baseline : std_logic_vector(8 downto 0);
    time_start         : std_logic_vector(9 downto 0);
    adc_peak           : std_logic_vector(13 downto 0);
    adc_integral       : std_logic_vector(22 downto 0);
    number_peaks       : std_logic_vector(3 downto 0);
    amplitude          : std_logic_vector(14 downto 0);
    peak_current       : std_logic;
    slope_current      : std_logic_vector(13 downto 0);
    slope_threshold    : std_logic_vector(6 downto 0);
    detection          : std_logic;
    sending            : std_logic;
    info_previous      : std_logic;
  end record;

  type peak_descriptor_trailer_t is array (11 downto 0) of std_logic_vector(31 downto 0);

  type trigger_xcorr_control_array_t is array (natural range <>) of trigger_xcorr_control_t;
  type trigger_xcorr_result_array_t is array (natural range <>) of trigger_xcorr_result_t;
  type peak_descriptor_control_array_t is array (natural range <>) of peak_descriptor_control_t;
  type peak_descriptor_result_array_t is array (natural range <>) of peak_descriptor_result_t;
  type peak_descriptor_trailer_bank_t is array (natural range <>) of peak_descriptor_trailer_t;

  type stc3_frame_descriptor_t is record
    valid          : std_logic;
    ch_id          : std_logic_vector(7 downto 0);
    version        : std_logic_vector(3 downto 0);
    start_ptr      : std_logic_vector(10 downto 0);
    sample0_ts     : std_logic_vector(63 downto 0);
    baseline       : std_logic_vector(13 downto 0);
    trigger_sample : std_logic_vector(13 downto 0);
    threshold_lsb  : std_logic_vector(13 downto 0);
  end record;

  type stc3_frame_descriptor_array_t is array (natural range <>) of stc3_frame_descriptor_t;

  type trigger_descriptor_t is record
    valid      : std_logic;
    channel_id : std_logic_vector(7 downto 0);
    version_id : std_logic_vector(3 downto 0);
    payload    : std_logic_vector(63 downto 0);
  end record;

  type hermes_boundary_status_t is record
    ready          : std_logic;
    backpressure   : std_logic;
    link_up        : std_logic;
    transport_busy : std_logic;
  end record;

  constant TIMING_CONTROL_NULL : timing_control_t := (
    use_endpoint_clock => '0',
    mmcm0_reset        => '0',
    mmcm1_reset        => '0',
    endpoint_reset     => '0',
    endpoint_addr      => (others => '0')
  );

  constant FRONTEND_ALIGNMENT_CONTROL_NULL : frontend_alignment_control_t := (
    idelayctrl_reset => '0',
    iserdes_reset    => '0',
    idelay_en_vtc    => '0',
    idelay_tap       => (others => (others => '0')),
    iserdes_bitslip  => (others => (others => '0'))
  );

  constant FRONTEND_ALIGNMENT_STATUS_NULL : frontend_alignment_status_t := (
    idelayctrl_ready => '0',
    format_ok        => '0',
    training_ok      => '0',
    alignment_valid  => '0'
  );

  constant AFE_ALIGNMENT_CONTROL_NULL : afe_alignment_control_t := (
    idelay_load     => '0',
    idelay_tap      => (others => '0'),
    iserdes_bitslip => (others => '0')
  );

  constant AFE_ALIGNMENT_STATUS_NULL : afe_alignment_status_t := (
    format_ok       => '0',
    training_ok     => '0',
    alignment_valid => '0'
  );

  constant FRONTEND_PREREQ_NULL : frontend_prereq_t := (
    config_ready => '0',
    timing_ready => '0'
  );

  constant TIMING_STATUS_NULL : timing_status_t := (
    mmcm0_locked    => '0',
    mmcm1_locked    => '0',
    endpoint_ready  => '0',
    endpoint_state  => (others => '0'),
    timestamp_valid => '0'
  );

  constant ANALOG_CONTROL_NULL : analog_control_t := (
    afe_resetn       => '0',
    dac_resetn       => '0',
    afe_config_valid => '0',
    dac_config_valid => '0'
  );

  constant ANALOG_STATUS_NULL : analog_status_t := (
    config_ready => '0',
    afe_ready    => '0',
    dac_ready    => '0'
  );

  constant AFE_CONFIG_COMMAND_NULL : afe_config_command_t := (
    afe_write_valid    => '0',
    afe_write_data     => (others => '0'),
    trim_write_valid   => '0',
    trim_write_data    => (others => '0'),
    offset_write_valid => '0',
    offset_write_data  => (others => '0')
  );

  constant AFE_CONFIG_STATUS_NULL : afe_config_status_t := (
    afe_readback => (others => '0'),
    afe_busy     => '0',
    trim_busy    => '0',
    offset_busy  => '0',
    ready        => '0'
  );

  constant ACQUISITION_READINESS_NULL : acquisition_readiness_t := (
    config_ready    => '0',
    timing_ready    => '0',
    alignment_ready => '0'
  );

  constant TRIGGER_XCORR_CONTROL_NULL : trigger_xcorr_control_t := (
    enable                 => '0',
    afe_comp_enable        => '0',
    invert_enable          => '0',
    filter_output_selector => (others => '0'),
    threshold_xc           => (others => '0'),
    adhoc                  => (others => '0'),
    ti_trigger             => (others => '0'),
    ti_trigger_stbr        => '0'
  );

  constant TRIGGER_XCORR_RESULT_NULL : trigger_xcorr_result_t := (
    enabled           => '0',
    trigger_pulse     => '0',
    baseline          => (others => '0'),
    monitor_sample    => (others => '0'),
    descriptor_sample => (others => '0'),
    trigger_sample    => (others => '0'),
    trigger_timestamp => (others => '0')
  );

  constant PEAK_DESCRIPTOR_CONTROL_NULL : peak_descriptor_control_t := (
    config      => (others => '0'),
    frame_match => '0'
  );

  constant PEAK_DESCRIPTOR_RESULT_NULL : peak_descriptor_result_t := (
    self_trigger       => '0',
    data_available     => '0',
    trailer_available  => '0',
    time_peak          => (others => '0'),
    time_over_baseline => (others => '0'),
    time_start         => (others => '0'),
    adc_peak           => (others => '0'),
    adc_integral       => (others => '0'),
    number_peaks       => (others => '0'),
    amplitude          => (others => '0'),
    peak_current       => '0',
    slope_current      => (others => '0'),
    slope_threshold    => (others => '0'),
    detection          => '0',
    sending            => '0',
    info_previous      => '0'
  );

  constant PEAK_DESCRIPTOR_TRAILER_NULL : peak_descriptor_trailer_t := (
    others => (others => '0')
  );

  constant STC3_FRAME_DESCRIPTOR_NULL : stc3_frame_descriptor_t := (
    valid          => '0',
    ch_id          => (others => '0'),
    version        => (others => '0'),
    start_ptr      => (others => '0'),
    sample0_ts     => (others => '0'),
    baseline       => (others => '0'),
    trigger_sample => (others => '0'),
    threshold_lsb  => (others => '0')
  );

  constant TRIGGER_DESCRIPTOR_NULL : trigger_descriptor_t := (
    valid      => '0',
    channel_id => (others => '0'),
    version_id => (others => '0'),
    payload    => (others => '0')
  );

  constant HERMES_BOUNDARY_STATUS_NULL : hermes_boundary_status_t := (
    ready          => '0',
    backpressure   => '0',
    link_up        => '0',
    transport_busy => '0'
  );

end package daphne_subsystem_pkg;

package body daphne_subsystem_pkg is
end package body daphne_subsystem_pkg;
