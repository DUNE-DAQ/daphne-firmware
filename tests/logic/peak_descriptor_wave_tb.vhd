library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.all;
use std.textio.all;

use work.daphne_subsystem_pkg.all;

entity peak_descriptor_wave_tb is
  generic (
    INPUT_FILE_G        : string  := "waveform.txt";
    OUTPUT_FILE_G       : string  := "peak_descriptor_wave_events.csv";
    BASELINE_G          : natural := 2800;
    TRIGGER_DELTA_G     : natural := 64;
    TRIGGER_HOLDOFF_G   : natural := 1024;
    DESCRIPTOR_CONFIG_G : natural := 16#36CD#;
    MAX_SAMPLES_G       : natural := 0;
    FLUSH_SAMPLES_G     : natural := 2048
  );
end entity peak_descriptor_wave_tb;

architecture tb of peak_descriptor_wave_tb is
  constant CLOCK_PERIOD_C : time := 16 ns;

  function clamp_u14(value : integer) return natural is
  begin
    if value < 0 then
      return 0;
    elsif value > 16#3FFF# then
      return 16#3FFF#;
    else
      return natural(value);
    end if;
  end function clamp_u14;

  function to_sample14(value : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(clamp_u14(value), 14));
  end function to_sample14;

  function sl_char(value : std_logic) return character is
  begin
    case value is
      when '0' =>
        return '0';
      when '1' =>
        return '1';
      when others =>
        return '?';
    end case;
  end function sl_char;

  function is_binary(value : std_logic_vector) return boolean is
  begin
    for idx in value'range loop
      if (value(idx) /= '0') and (value(idx) /= '1') then
        return false;
      end if;
    end loop;
    return true;
  end function is_binary;

  function slv_unsigned_image(value : std_logic_vector) return string is
  begin
    if is_binary(value) then
      return integer'image(to_integer(unsigned(value)));
    else
      return "NA";
    end if;
  end function slv_unsigned_image;

  function slv_signed_image(value : std_logic_vector) return string is
  begin
    if is_binary(value) then
      return integer'image(to_integer(signed(value)));
    else
      return "NA";
    end if;
  end function slv_signed_image;

  function slv_hex_image(value : std_logic_vector) return string is
  begin
    if is_binary(value) then
      return to_hstring(value);
    else
      return "NA";
    end if;
  end function slv_hex_image;

  signal clock_s : std_logic := '0';
  signal reset_s : std_logic := '1';

  signal raw_sample_s       : integer := integer(BASELINE_G);
  signal sample_valid_s     : std_logic := '0';
  signal sample_done_s      : std_logic := '0';
  signal sample_index_s     : natural := 0;
  signal timestamp_s        : unsigned(63 downto 0) := (others => '0');
  signal previous_sample_s  : integer := integer(BASELINE_G);
  signal holdoff_count_s    : natural := 0;
  signal trigger_pulse_s    : std_logic := '0';

  signal trigger_result_s     : trigger_xcorr_result_t := TRIGGER_XCORR_RESULT_NULL;
  signal descriptor_control_s : peak_descriptor_control_t := PEAK_DESCRIPTOR_CONTROL_NULL;
  signal descriptor_result_s  : peak_descriptor_result_t := PEAK_DESCRIPTOR_RESULT_NULL;
  signal trailer_s            : peak_descriptor_trailer_t := PEAK_DESCRIPTOR_TRAILER_NULL;
begin
  clock_s <= not clock_s after CLOCK_PERIOD_C / 2;
  reset_s <= '1', '0' after (CLOCK_PERIOD_C * 8);

  descriptor_control_s <= (
    config      => std_logic_vector(to_unsigned(DESCRIPTOR_CONFIG_G, 14)),
    frame_match => '1'
  );

  trigger_result_s <= (
    enabled           => '1',
    trigger_pulse     => trigger_pulse_s,
    baseline          => std_logic_vector(to_unsigned(BASELINE_G, 14)),
    monitor_sample    => to_sample14(raw_sample_s),
    descriptor_sample => to_sample14(raw_sample_s),
    trigger_sample    => to_sample14(raw_sample_s),
    trigger_timestamp => std_logic_vector(timestamp_s)
  );

  dut : entity work.peak_descriptor_channel
    port map (
      clock_i   => clock_s,
      reset_i   => reset_s,
      trigger_i => trigger_result_s,
      control_i => descriptor_control_s,
      result_o  => descriptor_result_s,
      trailer_o => trailer_s
    );

  reader_proc : process
    file input_file : text open read_mode is INPUT_FILE_G;
    variable row_v          : line;
    variable sample_v       : integer;
    variable consumed_v     : natural := 0;
    variable flush_count_v  : natural := 0;
  begin
    wait until falling_edge(clock_s);

    if reset_s = '1' then
      raw_sample_s <= integer(BASELINE_G);
      sample_valid_s <= '0';
      sample_done_s <= '0';
    elsif (((MAX_SAMPLES_G = 0) or (consumed_v < MAX_SAMPLES_G)) and (not endfile(input_file))) then
      readline(input_file, row_v);
      read(row_v, sample_v);
      raw_sample_s <= sample_v;
      sample_valid_s <= '1';
      sample_done_s <= '0';
      consumed_v := consumed_v + 1;
    elsif flush_count_v < FLUSH_SAMPLES_G then
      raw_sample_s <= integer(BASELINE_G);
      sample_valid_s <= '1';
      sample_done_s <= '0';
      flush_count_v := flush_count_v + 1;
    else
      raw_sample_s <= integer(BASELINE_G);
      sample_valid_s <= '0';
      sample_done_s <= '1';
    end if;
  end process reader_proc;

  trigger_proc : process(clock_s)
  begin
    if rising_edge(clock_s) then
      if reset_s = '1' then
        sample_index_s <= 0;
        timestamp_s <= (others => '0');
        previous_sample_s <= integer(BASELINE_G);
        holdoff_count_s <= 0;
        trigger_pulse_s <= '0';
      else
        trigger_pulse_s <= '0';

        if sample_valid_s = '1' then
          sample_index_s <= sample_index_s + 1;
          timestamp_s <= timestamp_s + 1;

          if holdoff_count_s /= 0 then
            holdoff_count_s <= holdoff_count_s - 1;
          elsif (raw_sample_s >= integer(BASELINE_G + TRIGGER_DELTA_G)) and
                (previous_sample_s < integer(BASELINE_G + TRIGGER_DELTA_G)) then
            trigger_pulse_s <= '1';
            holdoff_count_s <= TRIGGER_HOLDOFF_G;
          end if;

          previous_sample_s <= raw_sample_s;
        end if;
      end if;
    end if;
  end process trigger_proc;

  logger_proc : process(clock_s)
    file output_file : text open write_mode is OUTPUT_FILE_G;
    variable row_v            : line;
    variable header_written_v : boolean := false;
    variable finish_armed_v   : boolean := false;
  begin
    if rising_edge(clock_s) then
      if not header_written_v then
        write(
          row_v,
          string'("sample_idx,timestamp,raw_sample,baseline,trigger_pulse,self_trigger,data_available,trailer_available,time_peak,time_over_baseline,time_start,adc_peak,adc_integral,number_peaks,amplitude,peak_current,slope_current,slope_threshold,detection,sending,info_previous,trailer0,trailer1")
        );
        writeline(output_file, row_v);
        header_written_v := true;
      end if;

      if reset_s = '0' then
        if (trigger_pulse_s = '1') or
           (descriptor_result_s.self_trigger = '1') or
           (descriptor_result_s.data_available = '1') or
           (descriptor_result_s.trailer_available = '1') or
           (descriptor_result_s.peak_current = '1') then
          write(row_v, integer'image(integer(sample_index_s)));
          write(row_v, string'(","));
          write(row_v, integer'image(to_integer(timestamp_s)));
          write(row_v, string'(","));
          write(row_v, integer'image(raw_sample_s));
          write(row_v, string'(","));
          write(row_v, integer'image(integer(BASELINE_G)));
          write(row_v, string'(","));
          write(row_v, sl_char(trigger_pulse_s));
          write(row_v, string'(","));
          write(row_v, sl_char(descriptor_result_s.self_trigger));
          write(row_v, string'(","));
          write(row_v, sl_char(descriptor_result_s.data_available));
          write(row_v, string'(","));
          write(row_v, sl_char(descriptor_result_s.trailer_available));
          write(row_v, string'(","));
          write(row_v, slv_unsigned_image(descriptor_result_s.time_peak));
          write(row_v, string'(","));
          write(row_v, slv_unsigned_image(descriptor_result_s.time_over_baseline));
          write(row_v, string'(","));
          write(row_v, slv_unsigned_image(descriptor_result_s.time_start));
          write(row_v, string'(","));
          write(row_v, slv_unsigned_image(descriptor_result_s.adc_peak));
          write(row_v, string'(","));
          write(row_v, slv_unsigned_image(descriptor_result_s.adc_integral));
          write(row_v, string'(","));
          write(row_v, slv_unsigned_image(descriptor_result_s.number_peaks));
          write(row_v, string'(","));
          write(row_v, slv_unsigned_image(descriptor_result_s.amplitude));
          write(row_v, string'(","));
          write(row_v, sl_char(descriptor_result_s.peak_current));
          write(row_v, string'(","));
          write(row_v, slv_signed_image(descriptor_result_s.slope_current));
          write(row_v, string'(","));
          write(row_v, slv_signed_image(descriptor_result_s.slope_threshold));
          write(row_v, string'(","));
          write(row_v, sl_char(descriptor_result_s.detection));
          write(row_v, string'(","));
          write(row_v, sl_char(descriptor_result_s.sending));
          write(row_v, string'(","));
          write(row_v, sl_char(descriptor_result_s.info_previous));
          write(row_v, string'(","));
          write(row_v, slv_hex_image(trailer_s(0)));
          write(row_v, string'(","));
          write(row_v, slv_hex_image(trailer_s(1)));
          writeline(output_file, row_v);
        end if;

        if sample_done_s = '1' and not finish_armed_v then
          finish_armed_v := true;
          assert true report "peak descriptor wave simulation completed" severity note;
          finish;
        end if;
      end if;
    end if;
  end process logger_proc;
end architecture tb;
