library ieee;
use ieee.std_logic_1164.all;

library xpm;
use xpm.vcomponents.all;

use work.daphne_subsystem_pkg.all;

entity trigger_control_sync is
  generic (
    CHANNEL_COUNT_G : positive := 40
  );
  port (
    src_clk_i                : in  std_logic;
    src_reset_i              : in  std_logic;
    dst_clk_i                : in  std_logic;
    dst_reset_i              : in  std_logic;
    core_chan_enable_i       : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    afe_comp_enable_i        : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    invert_enable_i          : in  std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    threshold_xc_i           : in  slv28_array_t(0 to CHANNEL_COUNT_G - 1);
    adhoc_i                  : in  std_logic_vector(7 downto 0);
    filter_output_selector_i : in  std_logic_vector(1 downto 0);
    descriptor_config_i      : in  std_logic_vector(13 downto 0);
    signal_delay_i           : in  std_logic_vector(4 downto 0);
    reset_st_counters_i      : in  std_logic;
    core_chan_enable_o       : out std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    afe_comp_enable_o        : out std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    invert_enable_o          : out std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);
    threshold_xc_o           : out slv28_array_t(0 to CHANNEL_COUNT_G - 1);
    adhoc_o                  : out std_logic_vector(7 downto 0);
    filter_output_selector_o : out std_logic_vector(1 downto 0);
    descriptor_config_o      : out std_logic_vector(13 downto 0);
    signal_delay_o           : out std_logic_vector(4 downto 0);
    reset_st_counters_o      : out std_logic
  );
end entity trigger_control_sync;

architecture rtl of trigger_control_sync is
  type slv31_array_t is array (natural range <>) of std_logic_vector(30 downto 0);

  constant CHANNEL_CONTROL_RESET_C : std_logic_vector(30 downto 0) :=
    (30 downto 28 => '0', 27 downto 0 => '1');
  constant GLOBAL_CONTROL_RESET_C  : std_logic_vector(29 downto 0) := (others => '0');

  signal channel_shadow_s : slv31_array_t(0 to CHANNEL_COUNT_G - 1) := (others => CHANNEL_CONTROL_RESET_C);
  signal channel_cdc_s    : slv31_array_t(0 to CHANNEL_COUNT_G - 1);
  signal channel_active_s : slv31_array_t(0 to CHANNEL_COUNT_G - 1) := (others => CHANNEL_CONTROL_RESET_C);
  signal channel_send_s   : std_logic_vector(CHANNEL_COUNT_G - 1 downto 0) := (others => '1');
  signal channel_rcv_s    : std_logic_vector(CHANNEL_COUNT_G - 1 downto 0);

  signal global_shadow_s : std_logic_vector(29 downto 0) := GLOBAL_CONTROL_RESET_C;
  signal global_cdc_s    : std_logic_vector(29 downto 0);
  signal global_active_s : std_logic_vector(29 downto 0) := GLOBAL_CONTROL_RESET_C;
  signal global_send_s   : std_logic := '1';
  signal global_rcv_s    : std_logic;
begin
  src_channel_proc : process (src_clk_i)
    variable live_bundle_v : std_logic_vector(30 downto 0);
  begin
    if rising_edge(src_clk_i) then
      for idx in 0 to CHANNEL_COUNT_G - 1 loop
        live_bundle_v := core_chan_enable_i(idx) &
                         afe_comp_enable_i(idx) &
                         invert_enable_i(idx) &
                         threshold_xc_i(idx);
        if src_reset_i = '1' then
          channel_shadow_s(idx) <= live_bundle_v;
          channel_send_s(idx)   <= '1';
        elsif channel_send_s(idx) = '1' then
          if channel_rcv_s(idx) = '1' then
            channel_send_s(idx) <= '0';
          end if;
        elsif live_bundle_v /= channel_shadow_s(idx) then
          channel_shadow_s(idx) <= live_bundle_v;
          channel_send_s(idx)   <= '1';
        end if;
      end loop;
    end if;
  end process src_channel_proc;

  src_global_proc : process (src_clk_i)
    variable live_bundle_v : std_logic_vector(29 downto 0);
  begin
    if rising_edge(src_clk_i) then
      live_bundle_v := adhoc_i &
                       filter_output_selector_i &
                       descriptor_config_i &
                       signal_delay_i &
                       reset_st_counters_i;
      if src_reset_i = '1' then
        global_shadow_s <= live_bundle_v;
        global_send_s   <= '1';
      elsif global_send_s = '1' then
        if global_rcv_s = '1' then
          global_send_s <= '0';
        end if;
      elsif live_bundle_v /= global_shadow_s then
        global_shadow_s <= live_bundle_v;
        global_send_s   <= '1';
      end if;
    end if;
  end process src_global_proc;

  gen_channel_sync : for idx in 0 to CHANNEL_COUNT_G - 1 generate
  begin
    channel_cdc_inst : xpm_cdc_handshake
      generic map (
        DEST_EXT_HSK   => 0,
        DEST_SYNC_FF   => 4,
        INIT_SYNC_FF   => 0,
        SIM_ASSERT_CHK => 0,
        SRC_SYNC_FF    => 2,
        WIDTH          => 31
      )
      port map (
        dest_out => channel_cdc_s(idx),
        dest_req => open,
        src_rcv  => channel_rcv_s(idx),
        dest_ack => '1',
        dest_clk => dst_clk_i,
        src_clk  => src_clk_i,
        src_in   => channel_shadow_s(idx),
        src_send => channel_send_s(idx)
      );
  end generate gen_channel_sync;

  global_cdc_inst : xpm_cdc_handshake
    generic map (
      DEST_EXT_HSK   => 0,
      DEST_SYNC_FF   => 4,
      INIT_SYNC_FF   => 0,
      SIM_ASSERT_CHK => 0,
      SRC_SYNC_FF    => 2,
      WIDTH          => 30
    )
    port map (
      dest_out => global_cdc_s,
      dest_req => open,
      src_rcv  => global_rcv_s,
      dest_ack => '1',
      dest_clk => dst_clk_i,
      src_clk  => src_clk_i,
      src_in   => global_shadow_s,
      src_send => global_send_s
    );

  dst_proc : process (dst_clk_i)
  begin
    if rising_edge(dst_clk_i) then
      if dst_reset_i = '1' then
        channel_active_s <= (others => CHANNEL_CONTROL_RESET_C);
        global_active_s  <= GLOBAL_CONTROL_RESET_C;
      else
        channel_active_s <= channel_cdc_s;
        global_active_s  <= global_cdc_s;
      end if;
    end if;
  end process dst_proc;

  gen_outputs : for idx in 0 to CHANNEL_COUNT_G - 1 generate
  begin
    core_chan_enable_o(idx) <= channel_active_s(idx)(30);
    afe_comp_enable_o(idx)  <= channel_active_s(idx)(29);
    invert_enable_o(idx)    <= channel_active_s(idx)(28);
    threshold_xc_o(idx)     <= channel_active_s(idx)(27 downto 0);
  end generate gen_outputs;

  adhoc_o                  <= global_active_s(29 downto 22);
  filter_output_selector_o <= global_active_s(21 downto 20);
  descriptor_config_o      <= global_active_s(19 downto 6);
  signal_delay_o           <= global_active_s(5 downto 1);
  reset_st_counters_o      <= global_active_s(0);
end architecture rtl;
