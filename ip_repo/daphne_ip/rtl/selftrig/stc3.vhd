-- stc3.vhd
-- self triggered channel machine for ONE DAPHNE channel
-- Jamieson Olsen <jamieson@fnal.gov> - Daniel Avila Gomez <daniel.avila.gomez@cern.ch> - Esteban Cristaldo <> - Ignacio Lopez de Rego <>
--
-- updated again: the backend FIFO returns! The merge logic has been removed from
-- Adam's 10G sender and is now under control in the DAPHNE core logic.
-- 
-- This module watches one channel data bus and computes the average signal level 
-- (baseline.vhd) based on the last N samples. When it detects a trigger condition
-- (defined in trig.vhd) it then begins assemblying the output frame in the output FIFO.
-- The output FIFO is UltraRAM based and is a single clock domain.
--
-- the trigger module provided here is very basic and is intended as a placeholder
-- to simulate a more advanced trigger which has a total latency of 64 clock cycles.
--
-- enable input removed; just set threshold to all 1's to disable this module
--
-- 64 bit diagnostic registers:
-- trig_count = counts the number of trigger pulses
-- drop_full_count = trigger pulse was ignored because the FIFO was too full
-- drop_busy_count = trigger pulse was ignored because I was busy

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

use work.daphne_subsystem_pkg.all;

entity stc3 is
-- generic( baseline_runlength: integer := 256 ); -- options 32, 64, 128, or 256
port(
    ch_id: std_logic_vector(7 downto 0);
    version: std_logic_vector(3 downto 0);
    -- threshold: std_logic_vector(9 downto 0); -- counts relative calculated avg baseline
    st_config: in std_logic_vector(13 downto 0); -- Config param for Self-Trigger and Local Primitive Calculation, CIEMAT (Nacho)
    signal_delay: in std_logic_vector(4 downto 0);
    threshold_xc: in std_logic_vector(27 downto 0); -- cross correlation trigger threshold 
    filter_output_selector: in std_logic_vector(1 downto 0); --Esteban
    afe_comp_enable: in std_logic;
    invert_enable: in std_logic;

    clock: in std_logic; -- master clock 62.5MHz
    reset: in std_logic;
    reset_st_counters: in std_logic;
    forcetrig: in std_logic; -- force a trigger
    timestamp: in std_logic_vector(63 downto 0);
	din: in std_logic_vector(13 downto 0); -- aligned AFE data

    adhoc: in std_logic_vector(7 downto 0); -- command value for adhoc trigger
    ti_trigger: in std_logic_vector(7 downto 0);
    ti_trigger_stbr: in std_logic;

    record_count: out std_logic_vector(63 downto 0); -- diagnostic counters
    full_count: out std_logic_vector(63 downto 0);
    busy_count: out std_logic_vector(63 downto 0);

    trigger_output: out std_logic;

    st_afe_dat_filtered: out std_logic_vector(13 downto 0); -- aligned AFE data filtered
    TCount: out std_logic_vector(63 downto 0);
    PCount: out std_logic_vector(63 downto 0);

    ready: out std_logic; -- i have something!
    rd_en: in std_logic; -- output FIFO read enable
    dout: out std_logic_vector(71 downto 0) -- output FIFO data
);
end stc3;

architecture stc3_arch of stc3 is
signal trig_sample_ts: std_logic_vector(63 downto 0) := (others=>'0');
signal calculated_baseline, trig_sample_dat: std_logic_vector(13 downto 0) := (others=>'0');
signal triggered: std_logic := '0';
signal clean_forcetrig: std_logic := '0';
signal forcetrig_reg: std_logic_vector(1 downto 0) := "00";
signal enable: std_logic;

signal triggered_bicocca: std_logic := '0';
signal afe_dat_filtered: std_logic_vector(13 downto 0);
signal afe_dat_filtered_TP: std_logic_vector(13 downto 0);
signal trigCount: std_logic_vector(63 downto 0) := (others => '0');
signal packCount: std_logic_vector(63 downto 0) := (others => '0');

signal Match_TP_With_FRAME: std_logic; -- ACTIVE HIGH when LOCAL primitives are calculated
signal Data_Available_Trailer_aux: std_logic; -- ACTIVE HIGH when metadata is ready
signal Trailer_Word_0_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_1_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_2_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_3_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_4_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_5_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_6_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_7_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_8_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_9_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_10_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal Trailer_Word_11_aux: std_logic_vector(31 downto 0); -- TRAILER WORD with metada (Local Trigger Primitives)
signal xcorr_control_s: trigger_xcorr_control_t := TRIGGER_XCORR_CONTROL_NULL;
signal trigger_builder_s: trigger_xcorr_result_t := TRIGGER_XCORR_RESULT_NULL;
signal descriptor_control_s: peak_descriptor_control_t := PEAK_DESCRIPTOR_CONTROL_NULL;
signal descriptor_result_s: peak_descriptor_result_t := PEAK_DESCRIPTOR_RESULT_NULL;
signal trailer_builder_s: peak_descriptor_trailer_t := PEAK_DESCRIPTOR_TRAILER_NULL;
signal frame_match_s: std_logic;

-- component baseline
-- generic( baseline_runlength: integer := 256 );
-- port(
--     clock: in std_logic;
--     reset: in std_logic;
--     din: in std_logic_vector(13 downto 0);
--     bline: out std_logic_vector(13 downto 0));
-- end component;

-- component trig
-- port(
--     clock: in std_logic;
--     din: in std_logic_vector(13 downto 0);
--     ts: in std_logic_vector(63 downto 0);
--     baseline: in std_logic_vector(13 downto 0);
--     threshold: in std_logic_vector(9 downto 0);
--     adhoc: in std_logic_vector(7 downto 0); -- command value for adhoc trigger
--     ti_trigger: in std_logic_vector(7 downto 0);
--     ti_trigger_stbr: in std_logic;
--     trig: out std_logic;
--     trig_sample_dat: out std_logic_vector(13 downto 0);
--     trig_sample_ts: out std_logic_vector(63 downto 0)
-- );
-- end component;

component trig_xc is 
port(
    clock: in std_logic;
    reset: in std_logic; 
    din: in std_logic_vector(13 downto 0); -- raw AFE data aligned to clock
    enable: in std_logic;
    afe_comp_enable: in std_logic;
    invert_enable: in std_logic;
    adhoc: in std_logic_vector(7 downto 0); -- command value for adhoc trigger
    filter_output_selector: in std_logic_vector(1 downto 0);
    ti_trigger: in std_logic_vector(7 downto 0); -- adhoc trigger signals
    ti_trigger_stbr: in std_logic; -- adhoc trigger signals
    threshold_xc: in std_logic_vector(27 downto 0); -- trigger threshold relative to cross correlation value, originally (41 downto 0)
    ts: in std_logic_vector(63 downto 0); -- timestamp
    baseline: out std_logic_vector(13 downto 0); -- baseline 300mHz LPF output
    dout1: out std_logic_vector(13 downto 0); -- Filtered AFE data: selected data. To see filter process
    dout2: out std_logic_vector(13 downto 0); -- Filtered AFE data: movmean data. To use with Nacho's module 
    trig_sample_dat: out std_logic_vector(13 downto 0); -- the sample that caused the trigger
    trig_sample_ts:  out std_logic_vector(63 downto 0); -- the timestamp of the sample that caused the trigger
    trig: out std_logic -- trigger pulse (after latency delay)
);
end component;

component Self_Trigger_Primitive_Calculation is
port(
    clock:                          in  std_logic;                                              -- AFE clock
    reset:                          in  std_logic;                                              -- Reset signal. ACTIVE HIGH
    din:                            in  std_logic_vector(13 downto 0);                          -- Data coming from the Filter Block / Raw data from AFEs
    Config_Param:                   in  std_logic_vector(13 downto 0);                          -- Configure parameters for filtering & self-trigger bloks
    Ext_Self_Trigger:               in  std_logic;                                              -- External Self-Trigger coming from another block
    Match_with_Frame:               in  std_logic;                                              -- External signal that allows being matched with the frame construction.
    Self_trigger:                   out std_logic;                                              -- Self-Trigger signal comming from the Self-Trigger block
    Data_Available:                 out std_logic;                                              -- ACTIVE HIGH when LOCAL primitives are calculated
    Time_Peak:                      out std_logic_vector(8 downto 0);                           -- Time in Samples to achieve de Max peak
    Time_Over_Baseline:             out std_logic_vector(8 downto 0);                           -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
    Time_Start:                     out std_logic_vector(9 downto 0);                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
    ADC_Peak:                       out std_logic_vector(13 downto 0);                          -- Amplitude in ADC counts od the peak
    ADC_Integral:                   out std_logic_vector(22 downto 0);                          -- Charge of the light pulse (without undershoot) in ADC*samples
    Number_Peaks:                   out std_logic_vector(3 downto 0);                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
    Baseline:                       in std_logic_vector(13 downto 0);                          -- Real Time calculated BASELINE
    Amplitude:                      out std_logic_vector(14 downto 0);                          -- Real Time calculated AMPLITUDE
    Peak_Current:                   out std_logic;                                              -- ACTIVE HIGH when a peak is detected
    Slope_Current:                  out std_logic_vector(13 downto 0);                          -- Real Time calculated SLOPE
    Slope_Threshold:                out std_logic_vector(6 downto 0);                           -- Threshold over the slope to detect Peaks
    Detection:                      out std_logic;                                              -- ACTIVE HIGH when primitives are being calculated (during light pulse)
    Sending:                        out std_logic;                                              -- ACTIVE HIGH when colecting data for self-trigger frame
    Info_Previous:                  out std_logic;                                              -- ACTIVE HIGH when self-trigger is produced by a waveform between two frames 
    Data_Available_Trailer:         out std_logic;                                              -- ACTIVE HIGH when metadata is ready
    Trailer_Word_0:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_1:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_2:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_3:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_4:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_5:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_6:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_7:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_8:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_9:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_10:                out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    Trailer_Word_11:                out std_logic_vector(31 downto 0)                           -- TRAILER WORD with metada (Local Trigger Primitives)
);
end component;

begin

-- clean up forcetrig (edge detection) just in case it is async or too long

cleantrig_proc: process(clock)
begin
    if rising_edge(clock) then
        forcetrig_reg(0) <= forcetrig;
        forcetrig_reg(1) <= forcetrig_reg(0);
    end if;
end process cleantrig_proc;  

clean_forcetrig <= '1' when (forcetrig_reg="01") else '0';

-- to disable this sender, set threshold value to all 1s.

-- enable <= '0' when (threshold="1111111111") else '1';
enable <= '0' when (threshold_xc=X"FFFFFFF") else '1';

-- trig_inst: trig
-- port map(
--      clock => clock,
--      din => din_delay(0), -- watching live AFE data
--      ts => timestamp,
--      baseline => calculated_baseline,
--      threshold => threshold,
--      adhoc => adhoc,
--      ti_trigger => ti_trigger,
--      ti_trigger_stbr => ti_trigger_stbr,
--      trig => triggered,
--      trig_sample_dat => trig_sample_dat, 
--      trig_sample_ts => trig_sample_ts 
-- );        

xcorr_control_s <= (
    enable                 => enable,
    afe_comp_enable        => afe_comp_enable,
    invert_enable          => invert_enable,
    filter_output_selector => filter_output_selector,
    threshold_xc           => threshold_xc,
    adhoc                  => adhoc,
    ti_trigger             => ti_trigger,
    ti_trigger_stbr        => ti_trigger_stbr
);

xcorr_channel_inst: entity work.self_trigger_xcorr_channel
port map(
    clock_i     => clock,
    reset_i     => reset,
    din_i       => din,
    timestamp_i => timestamp,
    control_i   => xcorr_control_s,
    result_o    => trigger_builder_s
);

triggered <= trigger_builder_s.trigger_pulse;
calculated_baseline <= trigger_builder_s.baseline;
afe_dat_filtered <= trigger_builder_s.monitor_sample;
trig_sample_dat <= trigger_builder_s.trigger_sample;
trig_sample_ts <= trigger_builder_s.trigger_timestamp;

descriptor_control_s <= (
    config      => st_config,
    frame_match => Match_TP_With_FRAME
);

descriptor_channel_inst: entity work.peak_descriptor_channel
port map(
    clock_i   => clock,
    reset_i   => reset,
    trigger_i => trigger_builder_s,
    control_i => descriptor_control_s,
    result_o  => descriptor_result_s,
    trailer_o => trailer_builder_s
);

Data_Available_Trailer_aux <= descriptor_result_s.trailer_available;

Match_TP_With_FRAME <= frame_match_s;

record_builder_inst: entity work.stc3_record_builder
port map(
    ch_id_i             => ch_id,
    version_i           => version,
    threshold_xc_i      => threshold_xc,
    signal_delay_i      => signal_delay,
    clock_i             => clock,
    reset_i             => reset,
    reset_st_counters_i => reset_st_counters,
    enable_i            => enable,
    force_trigger_i     => clean_forcetrig,
    din_i               => din,
    trigger_i           => trigger_builder_s,
    trailer_capture_i   => Data_Available_Trailer_aux,
    trailer_i           => trailer_builder_s,
    frame_match_o       => frame_match_s,
    record_count_o      => record_count,
    full_count_o        => full_count,
    busy_count_o        => busy_count,
    trigger_count_o     => trigCount,
    packet_count_o      => packCount,
    delayed_sample_o    => st_afe_dat_filtered,
    ready_o             => ready,
    rd_en_i             => rd_en,
    dout_o              => dout
);

trigger_output <= triggered;
TCount <= trigCount;
PCount <= packCount;

end stc3_arch;
