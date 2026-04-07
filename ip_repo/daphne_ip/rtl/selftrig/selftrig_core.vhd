-- selftrig_core.vhd
-- DAPHNE core logic, top level, self triggered mode sender
-- TWO 20:1 self triggered senders
-- AXI-LITE interface for reading diagnostic counters and reading/writing threshold values
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity selftrig_core is
generic( baseline_runlength: integer := 256 ); -- preserved for compatibility with the external legacy core contract
port(
    clock: in std_logic; -- 62.5 MHz
    reset: in std_logic;
    reset_st_counters: in std_logic;
    version: in std_logic_vector(3 downto 0);
    filter_output_selector: in std_logic_vector(1 downto 0); --Esteban
    afe_comp_enable: in std_logic_vector(39 downto 0);
    invert_enable: in std_logic_vector(39 downto 0);
    st_config: in std_logic_vector(13 downto 0); -- Config param for Self-Trigger and Local Primitive Calculation, CIEMAT (Nacho)
    signal_delay: in std_logic_vector(4 downto 0);
    timestamp: in std_logic_vector(63 downto 0);
    forcetrig: in std_logic;
    st_trigger_signal: out std_logic_vector(39 downto 0);
    adhoc: in std_logic_vector(7 downto 0); -- command value for adhoc trigger
    ti_trigger: in std_logic_vector(7 downto 0);
    ti_trigger_stbr: in std_logic;
	  din: in array_5x9x16_type; 
    dout: out array_2x64_type;
    afe_dat_filtered: out array_40x14_type; -- aligned AFE data filtered 
    valid: out std_logic_vector(1 downto 0);
    last:  out std_logic_vector(1 downto 0);
    AXI_IN: in AXILITE_INREC;
    AXI_OUT: out AXILITE_OUTREC
);
end selftrig_core;

architecture selftrig_core_arch of selftrig_core is

signal threshold_xc: slv28_array_t(0 to 39);
signal TCount: slv64_array_t(0 to 39);
signal PCount: slv64_array_t(0 to 39);
signal record_count: slv64_array_t(0 to 39);
signal full_count: slv64_array_t(0 to 39);
signal busy_count: slv64_array_t(0 to 39);

begin

legacy_selftrigger_datapath_inst : entity work.legacy_selftrigger_datapath
  port map (
    clock => clock,
    reset => reset,
    reset_st_counters => reset_st_counters,
    version => version,
    filter_output_selector => filter_output_selector,
    afe_comp_enable => afe_comp_enable,
    invert_enable => invert_enable,
    st_config => st_config,
    signal_delay => signal_delay,
    timestamp => timestamp,
    forcetrig => forcetrig,
    st_trigger_signal => st_trigger_signal,
    adhoc => adhoc,
    ti_trigger => ti_trigger,
    ti_trigger_stbr => ti_trigger_stbr,
    din => din,
    threshold_xc_i => threshold_xc,
    dout => dout,
    afe_dat_filtered => afe_dat_filtered,
    valid => valid,
    last => last,
    record_count_o => record_count,
    full_count_o => full_count,
    busy_count_o => busy_count,
    tcount_o => TCount,
    pcount_o => PCount
  );

legacy_selftrigger_register_bank_inst : entity work.legacy_selftrigger_register_bank
  port map (
    AXI_IN => AXI_IN,
    AXI_OUT => AXI_OUT,
    threshold_xc_o => threshold_xc,
    record_count_i => record_count,
    full_count_i => full_count,
    busy_count_i => busy_count,
    tcount_i => TCount,
    pcount_i => PCount
  );

end selftrig_core_arch;
