-- trig_xc.vhd
-- Cross-correlation self-trigger path integrating the imported EIA/Bicocca
-- algorithm sources with the current repo-owned trigger pipeline.
-- Daniel Avila Gomez <daniel.avila@eia.edu.co> - Esteban Cristaldo (Bicocca) -
-- Manuel Arroyave <manuel.arroyave@cern.ch>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trig_xc is
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
    dout2: out std_logic_vector(13 downto 0); -- Filtered AFE data: movmean data for the descriptor path
    trig_sample_dat: out std_logic_vector(13 downto 0); -- the sample that caused the trigger
    trig_sample_ts:  out std_logic_vector(63 downto 0); -- the timestamp of the sample that caused the trigger
    trig: out std_logic -- trigger pulse (after latency delay)
);
end trig_xc;

architecture trig_xc_arch of trig_xc is 

signal current_sample: std_logic_vector(13 downto 0) := (others => '0');
signal din_trig: std_logic_vector(15 downto 0) := (others => '0');
signal dout_filter1, dout_filter2, k_lpf_baseline: std_logic_vector(15 downto 0);
signal triggered_i, triggered_i_module: std_logic;
-- All tuple fields have the same64-cycle latency. Updating a single capture
-- register while only delaying the pulse corrupts closely spaced events.
signal trigger_tuple_in, trigger_tuple_out: std_logic_vector(78 downto 0);
signal valid_cycles: natural range 0 to 64 := 0;
signal ts_reg: std_logic_vector(63 downto 0) := (others => '0');

component hpf_pedestal_recovery_filter_trigger
port(
    clk : in std_logic;
    reset : in std_logic;
    enable : in std_logic;
    afe_comp_enable : in std_logic;
    invert_enable : in std_logic;
    threshold_xc : in std_logic_vector(27 downto 0); --(41 downto 0)
    output_selector : in std_logic_vector(1 downto 0);
    baseline : out std_logic_vector(15 downto 0);
    x : in std_logic_vector(15 downto 0);
    trigger_output : out std_logic;
    y1 : out std_logic_vector(15 downto 0);
    y2 : out std_logic_vector(15 downto 0)
);
end component hpf_pedestal_recovery_filter_trigger;

begin

    trig_pipeline_proc: process(clock)
    begin
        if rising_edge(clock) then
            current_sample <= din;
            ts_reg <= ts;
        end if;
    end process trig_pipeline_proc;

    -- filtering stages and self trigger module
    xcorr_filter_trigger_inst: hpf_pedestal_recovery_filter_trigger
    port map (
        clk => clock,
        reset => reset,
        enable => enable,
        afe_comp_enable => afe_comp_enable,
        invert_enable => invert_enable,
        threshold_xc => threshold_xc,
        output_selector => filter_output_selector,
        baseline => k_lpf_baseline,
        x => din_trig,
        trigger_output => triggered_i_module,
        y1 => dout_filter1,
        y2 => dout_filter2
    );

    -- trigger goes between the adhoc conditions or the EIA self trigger condition
    triggered_i <= '1' when ( ( ti_trigger=adhoc and ti_trigger_stbr='1' ) or ( triggered_i_module='1' ) ) else '0';

    -- Preserve the sample/timestamp sampled by the old event capture process:
    -- current_sample and ts_reg refer to the preceding input clock. Shift them
    -- together with each event, rather than reusing the most recent event's
    -- metadata when another event arrives during the trigger latency.
    trigger_tuple_in <= triggered_i & current_sample & ts_reg;
    trigger_tuple_delay_inst : entity work.fixed_delay_line
    generic map (WIDTH_G => 79, DELAY_G => 64)
    port map (clock_i => clock, din_i => trigger_tuple_in, dout_o => trigger_tuple_out);

    -- Keep reset off the sample/timestamp delay so Vivado can infer SRLs.
    -- Suppress stale valid bits until all64 pre-reset entries have flushed.
    valid_flush_proc : process(clock)
    begin
        if rising_edge(clock) then
            if reset='1' then valid_cycles <= 0;
            elsif valid_cycles<64 then valid_cycles <= valid_cycles+1;
            end if;
        end if;
    end process;
    trig <= trigger_tuple_out(78) when reset='0' and valid_cycles=64 else '0';
    -- Metadata is meaningful on every asserted trigger clock, including
    -- adjacent asserted clocks; it need not remain constant between events.
    trig_sample_dat <= trigger_tuple_out(77 downto 64);
    trig_sample_ts <= trigger_tuple_out(63 downto 0);
    dout1                 <= dout_filter1(13 downto 0);
    dout2                 <= dout_filter2(13 downto 0);
    baseline              <= k_lpf_baseline(13 downto 0);
    din_trig(13 downto 0) <= din;

end trig_xc_arch;
