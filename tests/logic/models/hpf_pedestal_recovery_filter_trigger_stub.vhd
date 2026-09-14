-- Alignment-only fixture: exercise trig_xc's timing-command trigger input
-- independently of the analog filtering and CFD algorithms.
library ieee;
use ieee.std_logic_1164.all;
entity hpf_pedestal_recovery_filter_trigger is
  port(clk, reset, enable, afe_comp_enable, invert_enable : in std_logic;
    threshold_xc : in std_logic_vector(27 downto 0);
    output_selector : in std_logic_vector(1 downto 0);
    baseline : out std_logic_vector(15 downto 0);
    x : in std_logic_vector(15 downto 0);
    trigger_output : out std_logic;
    y1, y2 : out std_logic_vector(15 downto 0));
end entity;
architecture fixture of hpf_pedestal_recovery_filter_trigger is
begin
  trigger_output<='0'; baseline<=X"1000"; y1<=x; y2<=x;
end architecture;
