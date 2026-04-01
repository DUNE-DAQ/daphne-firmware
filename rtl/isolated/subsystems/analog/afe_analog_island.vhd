library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity afe_analog_island is
  port (
    clock_i          : in  std_logic;
    reset_i          : in  std_logic;
    config_valid_i   : in  std_logic;
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
end entity afe_analog_island;

architecture rtl of afe_analog_island is
  signal status_raw_s  : afe_config_status_t;
  signal resetn_s      : std_logic;
begin
  resetn_s <= not reset_i;

  config_slice_inst : entity work.afe_config_slice
    port map (
      clock_i         => clock_i,
      reset_i         => reset_i,
      cmd_i           => cmd_i,
      status_o        => status_raw_s,
      afe_miso_i      => afe_miso_i,
      afe_sclk_o      => afe_sclk_o,
      afe_sen_o       => afe_sen_o,
      afe_mosi_o      => afe_mosi_o,
      trim_sclk_o     => trim_sclk_o,
      trim_mosi_o     => trim_mosi_o,
      trim_ldac_n_o   => trim_ldac_n_o,
      trim_sync_n_o   => trim_sync_n_o,
      offset_sclk_o   => offset_sclk_o,
      offset_mosi_o   => offset_mosi_o,
      offset_ldac_n_o => offset_ldac_n_o,
      offset_sync_n_o => offset_sync_n_o
    );

  config_boundary_inst : entity work.afe_config_slice_boundary
    port map (
      resetn_i       => resetn_s,
      config_valid_i => config_valid_i,
      status_i       => status_raw_s,
      status_o       => status_o
    );
end architecture rtl;
