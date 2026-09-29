library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity readout_trigger_policy_formal is
  port (clk, inhibit, software_trigger, hardware_trigger : in std_logic;
        source : in std_logic_vector(2 downto 0));
end entity;

architecture formal of readout_trigger_policy_formal is
  signal previous_source : std_logic_vector(2 downto 0) := "011";
  signal admission, self_enable, timing_enable, forced : std_logic;
  signal tag : std_logic_vector(1 downto 0);
  signal policy_ready, sw_accepted, hw_accepted : boolean;
begin
  dut : entity work.readout_trigger_policy port map (
    clock_i=>clk, source_i=>source, inhibit_i=>inhibit,
    software_trigger_i=>software_trigger, hardware_trigger_i=>hardware_trigger,
    admission_enable_o=>admission, self_trigger_enable_o=>self_enable, timing_trigger_enable_o=>timing_enable,
    force_trigger_o=>forced, calibration_tag_o=>tag);
  process(clk)
  begin
    if rising_edge(clk) then previous_source <= source; end if;
  end process;
  policy_ready <= source = previous_source and inhibit = '0' and
    (source = "000" or source = "001" or source = "010" or source = "011" or source = "100");
  sw_accepted <= policy_ready and software_trigger = '1' and (source = "000" or source = "011");
  hw_accepted <= policy_ready and hardware_trigger = '1' and (source = "001" or source = "011");
  assert (admission = '1') = policy_ready severity failure;
  assert (self_enable = '1') = (policy_ready and (source = "010" or source = "011")) severity failure;
  assert (timing_enable = '1') = (policy_ready and (source = "100" or source = "011")) severity failure;
  assert (forced = '1') = (sw_accepted or hw_accepted) severity failure;
  assert not sw_accepted or tag = CALIBRATION_TAG_SOFTWARE_C severity failure;
  assert sw_accepted or not hw_accepted or tag = CALIBRATION_TAG_BNC_C severity failure;
  assert sw_accepted or hw_accepted or tag = CALIBRATION_TAG_NORMAL_C severity failure;
  -- Explicit rejection properties, including simultaneous unselected sources.
  assert source /= "000" or self_enable = '0' severity failure;
  assert source /= "001" or self_enable = '0' severity failure;
  assert source /= "010" or forced = '0' severity failure;
  assert inhibit /= '1' or (forced = '0' and self_enable = '0' and timing_enable = '0' and admission = '0') severity failure;
  assert source = previous_source or (forced = '0' and self_enable = '0' and timing_enable = '0' and admission = '0') severity failure;
end architecture;
