library ieee;
use ieee.std_logic_1164.all;

library work;
use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity legacy_selftrigger_datapath is
  port (
    clock                  : in  std_logic;
    reset                  : in  std_logic;
    reset_st_counters      : in  std_logic;
    version                : in  std_logic_vector(3 downto 0);
    filter_output_selector : in  std_logic_vector(1 downto 0);
    afe_comp_enable        : in  std_logic_vector(39 downto 0);
    invert_enable          : in  std_logic_vector(39 downto 0);
    st_config              : in  std_logic_vector(13 downto 0);
    signal_delay           : in  std_logic_vector(4 downto 0);
    timestamp              : in  std_logic_vector(63 downto 0);
    forcetrig              : in  std_logic;
    st_trigger_signal      : out std_logic_vector(39 downto 0);
    adhoc                  : in  std_logic_vector(7 downto 0);
    ti_trigger             : in  std_logic_vector(7 downto 0);
    ti_trigger_stbr        : in  std_logic;
    din                    : in  array_5x9x16_type;
    threshold_xc_i         : in  slv28_array_t(0 to 39);
    dout                   : out array_2x64_type;
    afe_dat_filtered       : out array_40x14_type;
    valid                  : out std_logic_vector(1 downto 0);
    last                   : out std_logic_vector(1 downto 0);
    record_count_o         : out slv64_array_t(0 to 39);
    full_count_o           : out slv64_array_t(0 to 39);
    busy_count_o           : out slv64_array_t(0 to 39);
    tcount_o               : out slv64_array_t(0 to 39);
    pcount_o               : out slv64_array_t(0 to 39)
  );
end entity legacy_selftrigger_datapath;

architecture rtl of legacy_selftrigger_datapath is

  component st20_top
    generic (
      start_channel_number : integer := 0
    );
    port (
      thresholds_xc           : in  array_20x28_type;
      version                 : in  std_logic_vector(3 downto 0);
      filter_output_selector  : in  std_logic_vector(1 downto 0);
      afe_comp_enable         : in  std_logic_vector(19 downto 0);
      invert_enable           : in  std_logic_vector(19 downto 0);
      st_config               : in  std_logic_vector(13 downto 0);
      signal_delay            : in  std_logic_vector(4 downto 0);
      clock                   : in  std_logic;
      reset                   : in  std_logic;
      reset_st_counters       : in  std_logic;
      timestamp               : in  std_logic_vector(63 downto 0);
      forcetrig               : in  std_logic;
      adhoc                   : in  std_logic_vector(7 downto 0);
      ti_trigger              : in  std_logic_vector(7 downto 0);
      ti_trigger_stbr         : in  std_logic;
      st_trigger_signal       : out std_logic_vector(19 downto 0);
      din                     : in  array_20x14_type;
      record_count            : out array_20x64_type;
      full_count              : out array_20x64_type;
      busy_count              : out array_20x64_type;
      afe_dat_filtered        : out array_20x14_type;
      TCount                  : out array_20x64_type;
      PCount                  : out array_20x64_type;
      dout                    : out std_logic_vector(63 downto 0);
      valid                   : out std_logic;
      last                    : out std_logic
    );
  end component;

  signal din_lower, din_upper : array_20x14_type;
  signal threshold_xc_lower, threshold_xc_upper : array_20x28_type;
  signal st_trigger_signal_lower : std_logic_vector(19 downto 0);
  signal st_trigger_signal_upper : std_logic_vector(19 downto 0);

  signal afe_dat_filtered_lower, afe_dat_filtered_upper : array_20x14_type;
  signal tcount_lower, tcount_upper : array_20x64_type;
  signal pcount_lower, pcount_upper : array_20x64_type;

  signal record_count_lower, full_count_lower, busy_count_lower : array_20x64_type;
  signal record_count_upper, full_count_upper, busy_count_upper : array_20x64_type;

begin

  -- Break up the 5x9x16 bus into lower/upper 20-channel banks.
  -- Channel index 8 is the frame marker, so only 8 data lanes per AFE feed the trigger path.
  din_lower(0)  <= din(0)(0)(15 downto 2);
  din_lower(1)  <= din(0)(1)(15 downto 2);
  din_lower(2)  <= din(0)(2)(15 downto 2);
  din_lower(3)  <= din(0)(3)(15 downto 2);
  din_lower(4)  <= din(0)(4)(15 downto 2);
  din_lower(5)  <= din(0)(5)(15 downto 2);
  din_lower(6)  <= din(0)(6)(15 downto 2);
  din_lower(7)  <= din(0)(7)(15 downto 2);
  din_lower(8)  <= din(1)(0)(15 downto 2);
  din_lower(9)  <= din(1)(1)(15 downto 2);
  din_lower(10) <= din(1)(2)(15 downto 2);
  din_lower(11) <= din(1)(3)(15 downto 2);
  din_lower(12) <= din(1)(4)(15 downto 2);
  din_lower(13) <= din(1)(5)(15 downto 2);
  din_lower(14) <= din(1)(6)(15 downto 2);
  din_lower(15) <= din(1)(7)(15 downto 2);
  din_lower(16) <= din(2)(0)(15 downto 2);
  din_lower(17) <= din(2)(1)(15 downto 2);
  din_lower(18) <= din(2)(2)(15 downto 2);
  din_lower(19) <= din(2)(3)(15 downto 2);

  din_upper(0)  <= din(2)(4)(15 downto 2);
  din_upper(1)  <= din(2)(5)(15 downto 2);
  din_upper(2)  <= din(2)(6)(15 downto 2);
  din_upper(3)  <= din(2)(7)(15 downto 2);
  din_upper(4)  <= din(3)(0)(15 downto 2);
  din_upper(5)  <= din(3)(1)(15 downto 2);
  din_upper(6)  <= din(3)(2)(15 downto 2);
  din_upper(7)  <= din(3)(3)(15 downto 2);
  din_upper(8)  <= din(3)(4)(15 downto 2);
  din_upper(9)  <= din(3)(5)(15 downto 2);
  din_upper(10) <= din(3)(6)(15 downto 2);
  din_upper(11) <= din(3)(7)(15 downto 2);
  din_upper(12) <= din(4)(0)(15 downto 2);
  din_upper(13) <= din(4)(1)(15 downto 2);
  din_upper(14) <= din(4)(2)(15 downto 2);
  din_upper(15) <= din(4)(3)(15 downto 2);
  din_upper(16) <= din(4)(4)(15 downto 2);
  din_upper(17) <= din(4)(5)(15 downto 2);
  din_upper(18) <= din(4)(6)(15 downto 2);
  din_upper(19) <= din(4)(7)(15 downto 2);

  gen20stuff : for i in 19 downto 0 generate
    threshold_xc_lower(i) <= threshold_xc_i(i);
    threshold_xc_upper(i) <= threshold_xc_i(i + 20);
    st_trigger_signal(i) <= st_trigger_signal_lower(i);
    st_trigger_signal(i + 20) <= st_trigger_signal_upper(i);
    record_count_o(i) <= record_count_lower(i);
    record_count_o(i + 20) <= record_count_upper(i);
    busy_count_o(i) <= busy_count_lower(i);
    busy_count_o(i + 20) <= busy_count_upper(i);
    full_count_o(i) <= full_count_lower(i);
    full_count_o(i + 20) <= full_count_upper(i);
    afe_dat_filtered(i) <= afe_dat_filtered_lower(i);
    afe_dat_filtered(i + 20) <= afe_dat_filtered_upper(i);
    tcount_o(i) <= tcount_lower(i);
    tcount_o(i + 20) <= tcount_upper(i);
    pcount_o(i) <= pcount_lower(i);
    pcount_o(i + 20) <= pcount_upper(i);
  end generate gen20stuff;

  st20_lower_inst : st20_top
    generic map (
      start_channel_number => 0
    )
    port map (
      thresholds_xc => threshold_xc_lower,
      version => version,
      filter_output_selector => filter_output_selector,
      afe_comp_enable => afe_comp_enable(19 downto 0),
      invert_enable => invert_enable(19 downto 0),
      st_config => st_config,
      signal_delay => signal_delay,
      clock => clock,
      reset => reset,
      reset_st_counters => reset_st_counters,
      timestamp => timestamp,
      forcetrig => forcetrig,
      adhoc => adhoc,
      ti_trigger => ti_trigger,
      ti_trigger_stbr => ti_trigger_stbr,
      st_trigger_signal => st_trigger_signal_lower,
      din => din_lower,
      record_count => record_count_lower,
      full_count => full_count_lower,
      busy_count => busy_count_lower,
      afe_dat_filtered => afe_dat_filtered_lower,
      TCount => tcount_lower,
      PCount => pcount_lower,
      dout => dout(0),
      valid => valid(0),
      last => last(0)
    );

  st20_upper_inst : st20_top
    generic map (
      start_channel_number => 20
    )
    port map (
      thresholds_xc => threshold_xc_upper,
      version => version,
      filter_output_selector => filter_output_selector,
      afe_comp_enable => afe_comp_enable(39 downto 20),
      invert_enable => invert_enable(39 downto 20),
      st_config => st_config,
      signal_delay => signal_delay,
      clock => clock,
      reset => reset,
      reset_st_counters => reset_st_counters,
      timestamp => timestamp,
      forcetrig => forcetrig,
      adhoc => adhoc,
      ti_trigger => ti_trigger,
      ti_trigger_stbr => ti_trigger_stbr,
      st_trigger_signal => st_trigger_signal_upper,
      din => din_upper,
      record_count => record_count_upper,
      full_count => full_count_upper,
      busy_count => busy_count_upper,
      afe_dat_filtered => afe_dat_filtered_upper,
      TCount => tcount_upper,
      PCount => pcount_upper,
      dout => dout(1),
      valid => valid(1),
      last => last(1)
    );

end architecture rtl;
