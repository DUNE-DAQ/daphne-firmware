library ieee;
use ieee.std_logic_1164.all;

use work.daphne_subsystem_pkg.all;

entity afe_config_bank is
  generic (
    AFE_COUNT_G : positive range 1 to 5 := 5
  );
  port (
    clock_i          : in  std_logic;
    reset_i          : in  std_logic;
    config_valid_i   : in  std_logic_vector(AFE_COUNT_G - 1 downto 0);
    cmd_i            : in  afe_config_command_bank_t(0 to AFE_COUNT_G - 1);
    status_o         : out afe_config_status_bank_t(0 to AFE_COUNT_G - 1);
    afe_miso_i       : in  std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_sclk_o       : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_sen_o        : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    afe_mosi_o       : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_sclk_o      : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_mosi_o      : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_ldac_n_o    : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    trim_sync_n_o    : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_sclk_o    : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_mosi_o    : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_ldac_n_o  : out std_logic_vector(AFE_COUNT_G - 1 downto 0);
    offset_sync_n_o  : out std_logic_vector(AFE_COUNT_G - 1 downto 0)
  );
end entity afe_config_bank;

architecture rtl of afe_config_bank is
begin
  gen_afe : for idx in 0 to AFE_COUNT_G - 1 generate
  begin
    analog_island_inst : entity work.afe_analog_island
      port map (
        clock_i         => clock_i,
        reset_i         => reset_i,
        config_valid_i  => config_valid_i(idx),
        cmd_i           => cmd_i(idx),
        status_o        => status_o(idx),
        afe_miso_i      => afe_miso_i(idx),
        afe_sclk_o      => afe_sclk_o(idx),
        afe_sen_o       => afe_sen_o(idx),
        afe_mosi_o      => afe_mosi_o(idx),
        trim_sclk_o     => trim_sclk_o(idx),
        trim_mosi_o     => trim_mosi_o(idx),
        trim_ldac_n_o   => trim_ldac_n_o(idx),
        trim_sync_n_o   => trim_sync_n_o(idx),
        offset_sclk_o   => offset_sclk_o(idx),
        offset_mosi_o   => offset_mosi_o(idx),
        offset_ldac_n_o => offset_ldac_n_o(idx),
        offset_sync_n_o => offset_sync_n_o(idx)
      );
  end generate gen_afe;
end architecture rtl;
