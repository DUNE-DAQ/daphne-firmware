-- self_trigger_xcorr_channel.vhd
-- Repo-owned typed wrapper for the xcorr self-trigger path.
-- Algorithm provenance: Daniel Avila Gomez <daniel.avila@eia.edu.co>, EIA;
-- Esteban Cristaldo (Bicocca).
-- Wrapper and integration provenance: Manuel Arroyave <manuel.arroyave@cern.ch>, FNAL.

library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity self_trigger_xcorr_channel is
  port (
    clock_i     : in  std_logic;
    reset_i     : in  std_logic;
    din_i       : in  std_logic_vector(13 downto 0);
    timestamp_i : in  std_logic_vector(63 downto 0);
    control_i   : in  trigger_xcorr_control_t;
    result_o    : out trigger_xcorr_result_t
  );
end entity self_trigger_xcorr_channel;

architecture rtl of self_trigger_xcorr_channel is
  component trig_xc is
    port (
      clock                  : in  std_logic;
      reset                  : in  std_logic;
      din                    : in  std_logic_vector(13 downto 0);
      enable                 : in  std_logic;
      afe_comp_enable        : in  std_logic;
      invert_enable          : in  std_logic;
      adhoc                  : in  std_logic_vector(7 downto 0);
      filter_output_selector : in  std_logic_vector(1 downto 0);
      ti_trigger             : in  std_logic_vector(7 downto 0);
      ti_trigger_stbr        : in  std_logic;
      threshold_xc           : in  std_logic_vector(27 downto 0);
      ts                     : in  std_logic_vector(63 downto 0);
      baseline               : out std_logic_vector(13 downto 0);
      dout1                  : out std_logic_vector(13 downto 0);
      dout2                  : out std_logic_vector(13 downto 0);
      trig_sample_dat        : out std_logic_vector(13 downto 0);
      trig_sample_ts         : out std_logic_vector(63 downto 0);
      trig                   : out std_logic
    );
  end component;

  signal baseline_s          : std_logic_vector(13 downto 0);
  signal monitor_sample_s    : std_logic_vector(13 downto 0);
  signal descriptor_sample_s : std_logic_vector(13 downto 0);
  signal trigger_sample_s    : std_logic_vector(13 downto 0);
  signal trigger_ts_s        : std_logic_vector(63 downto 0);
  signal trigger_pulse_s     : std_logic;
  signal timing_trigger_s    : std_logic;
  signal calibration_tag_in_s : std_logic_vector(1 downto 0);
  signal calibration_tag_s   : std_logic_vector(1 downto 0);
begin
  trig_xc_inst : trig_xc
    port map (
      clock                  => clock_i,
      reset                  => reset_i,
      din                    => din_i,
      enable                 => control_i.enable,
      afe_comp_enable        => control_i.afe_comp_enable,
      invert_enable          => control_i.invert_enable,
      adhoc                  => control_i.adhoc,
      filter_output_selector => control_i.filter_output_selector,
      ti_trigger             => control_i.ti_trigger,
      ti_trigger_stbr        => control_i.ti_trigger_stbr,
      threshold_xc           => control_i.threshold_xc,
      ts                     => timestamp_i,
      baseline               => baseline_s,
      dout1                  => monitor_sample_s,
      dout2                  => descriptor_sample_s,
      trig_sample_dat        => trigger_sample_s,
      trig_sample_ts         => trigger_ts_s,
      trig                   => trigger_pulse_s
    );

  timing_trigger_s <= '1' when (control_i.ti_trigger = control_i.adhoc and control_i.ti_trigger_stbr = '1') else '0';
  calibration_tag_in_s <= CALIBRATION_TAG_TIMING_C when timing_trigger_s = '1' else CALIBRATION_TAG_NORMAL_C;

  calibration_tag_delay_inst : entity work.fixed_delay_line
    generic map (
      WIDTH_G => 2,
      DELAY_G => 64
    )
    port map (
      clock_i   => clock_i,
      din_i     => calibration_tag_in_s,
      dout_o    => calibration_tag_s
    );

  result_o <= (
    enabled           => control_i.enable,
    trigger_pulse     => trigger_pulse_s,
    baseline          => baseline_s,
    monitor_sample    => monitor_sample_s,
    descriptor_sample => descriptor_sample_s,
    trigger_sample    => trigger_sample_s,
    trigger_timestamp => trigger_ts_s,
    calibration_tag   => calibration_tag_s
  );
end architecture rtl;
