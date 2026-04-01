library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity afe_config_slice is
  port (
    clock_i          : in  std_logic;
    reset_i          : in  std_logic;
    cmd_i            : in  afe_config_command_t;
    status_o         : out afe_config_status_t;
    afe_miso_i       : in  std_logic;
    afe_sclk_o       : out std_logic;
    afe_sen_o        : out std_logic;
    afe_mosi_o       : out std_logic;
    trim_sclk_o      : out std_logic;
    trim_mosi_o      : out std_logic;
    trim_ldac_n_o    : out std_logic;
    trim_sync_n_o    : out std_logic;
    offset_sclk_o    : out std_logic;
    offset_mosi_o    : out std_logic;
    offset_ldac_n_o  : out std_logic;
    offset_sync_n_o  : out std_logic
  );
end entity afe_config_slice;

architecture rtl of afe_config_slice is
  signal afe_dout   : std_logic_vector(23 downto 0);
  signal afe_busy   : std_logic;
  signal trim_busy  : std_logic;
  signal offset_busy: std_logic;
begin
  afe_inst : entity work.spim_afe1
    generic map (
      CLKDIV => 8
    )
    port map (
      clock => clock_i,
      reset => reset_i,
      din   => cmd_i.afe_write_data,
      we    => cmd_i.afe_write_valid,
      dout  => afe_dout,
      busy  => afe_busy,
      sclk  => afe_sclk_o,
      sen   => afe_sen_o,
      mosi  => afe_mosi_o,
      miso  => afe_miso_i
    );

  trim_inst : entity work.spim_dac2
    generic map (
      CLKDIV => 8
    )
    port map (
      clock  => clock_i,
      reset  => reset_i,
      din    => cmd_i.trim_write_data,
      we     => cmd_i.trim_write_valid,
      busy   => trim_busy,
      sclk   => trim_sclk_o,
      mosi   => trim_mosi_o,
      ldac_n => trim_ldac_n_o,
      sync_n => trim_sync_n_o
    );

  offset_inst : entity work.spim_dac2
    generic map (
      CLKDIV => 8
    )
    port map (
      clock  => clock_i,
      reset  => reset_i,
      din    => cmd_i.offset_write_data,
      we     => cmd_i.offset_write_valid,
      busy   => offset_busy,
      sclk   => offset_sclk_o,
      mosi   => offset_mosi_o,
      ldac_n => offset_ldac_n_o,
      sync_n => offset_sync_n_o
    );

  status_o.afe_readback <= afe_dout;
  status_o.afe_busy <= afe_busy;
  status_o.trim_busy <= trim_busy;
  status_o.offset_busy <= offset_busy;
  status_o.ready <= (not reset_i) and (not afe_busy) and (not trim_busy) and (not offset_busy);
end architecture rtl;
