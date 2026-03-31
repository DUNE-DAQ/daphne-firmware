library ieee;
use ieee.std_logic_1164.all;

entity timing_endpoint_contract_formal is
  port (
    resetn_i         : in std_logic;
    clock_valid_i    : in std_logic;
    timestamp_valid_i : in std_logic;
    command_i        : in std_logic_vector(7 downto 0);
    command_valid_i  : in std_logic;
    tx_enable_req_i  : in std_logic;
    los_a_i          : in std_logic;
    los_b_i          : in std_logic;
    timestamp_i      : in std_logic_vector(63 downto 0)
  );
end entity timing_endpoint_contract_formal;

architecture formal of timing_endpoint_contract_formal is
  signal rst_a             : std_logic;
  signal ready_a           : std_logic;
  signal clock_valid_a     : std_logic;
  signal timestamp_valid_a : std_logic;
  signal timestamp_a_o     : std_logic_vector(63 downto 0);
  signal sync_a            : std_logic_vector(7 downto 0);
  signal sync_stb_a        : std_logic;
  signal tx_disable_a      : std_logic;

  signal rst_b             : std_logic;
  signal ready_b           : std_logic;
  signal clock_valid_b     : std_logic;
  signal timestamp_valid_b : std_logic;
  signal timestamp_b_o     : std_logic_vector(63 downto 0);
  signal sync_b            : std_logic_vector(7 downto 0);
  signal sync_stb_b        : std_logic;
  signal tx_disable_b      : std_logic;
  signal sync_expected     : std_logic;
  signal tx_disable_expected : std_logic;
  signal timestamp_expected  : std_logic_vector(63 downto 0);
begin
  dut_a : entity work.timing_endpoint_contract
    port map (
      resetn_i          => resetn_i,
      clock_valid_i     => clock_valid_i,
      timestamp_valid_i => timestamp_valid_i,
      command_i         => command_i,
      command_valid_i    => command_valid_i,
      tx_enable_req_i    => tx_enable_req_i,
      los_i              => los_a_i,
      timestamp_i        => timestamp_i,
      rst_o             => rst_a,
      ready_o           => ready_a,
      clock_valid_o     => clock_valid_a,
      timestamp_valid_o => timestamp_valid_a,
      timestamp_o       => timestamp_a_o,
      sync_o            => sync_a,
      sync_stb_o        => sync_stb_a,
      tx_disable_o      => tx_disable_a
    );

  dut_b : entity work.timing_endpoint_contract
    port map (
      resetn_i          => resetn_i,
      clock_valid_i     => clock_valid_i,
      timestamp_valid_i => timestamp_valid_i,
      command_i         => command_i,
      command_valid_i    => command_valid_i,
      tx_enable_req_i    => tx_enable_req_i,
      los_i              => los_b_i,
      timestamp_i        => timestamp_i,
      rst_o             => rst_b,
      ready_o           => ready_b,
      clock_valid_o     => clock_valid_b,
      timestamp_valid_o => timestamp_valid_b,
      timestamp_o       => timestamp_b_o,
      sync_o            => sync_b,
      sync_stb_o        => sync_stb_b,
      tx_disable_o      => tx_disable_b
    );

  sync_expected <= '1' when command_valid_i = '1' and ready_a = '1' and command_i = x"00" else '0';
  tx_disable_expected <= '0' when ready_a = '1' and tx_enable_req_i = '1' else '1';
  timestamp_expected <= timestamp_i when ready_a = '1' else (others => '0');

  assert ready_a = (resetn_i and clock_valid_i and timestamp_valid_i)
    report "timing endpoint ready must require reset release, clock validity, and timestamp validity"
    severity failure;

  assert rst_a = not ready_a
    report "timing endpoint reset must remain asserted until the contract is ready"
    severity failure;

  assert clock_valid_a = (resetn_i and clock_valid_i)
    report "clock-valid output must be suppressed while reset is asserted"
    severity failure;

  assert timestamp_valid_a = ready_a
    report "timestamp validity must be a subset of endpoint readiness"
    severity failure;

  assert timestamp_a_o = timestamp_expected
    report "timestamp must pass through only once the timing contract is ready"
    severity failure;

  assert sync_stb_a = sync_expected
    report "command 0 must be the only modeled sync command"
    severity failure;

  assert tx_disable_a = tx_disable_expected
    report "TX disable must reflect explicit enable request only after readiness"
    severity failure;

  assert rst_a = rst_b
    report "reset output must not depend on LOS observation input"
    severity failure;

  assert ready_a = ready_b
    report "ready output must not depend on LOS observation input"
    severity failure;

  assert clock_valid_a = clock_valid_b
    report "clock-valid output must not depend on LOS observation input"
    severity failure;

  assert timestamp_valid_a = timestamp_valid_b
    report "timestamp-valid output must not depend on LOS observation input"
    severity failure;

  assert timestamp_a_o = timestamp_b_o
    report "timestamp output must not depend on LOS observation input"
    severity failure;

  assert sync_a = sync_b
    report "sync output must not depend on LOS observation input"
    severity failure;

  assert sync_stb_a = sync_stb_b
    report "sync strobe must not depend on LOS observation input"
    severity failure;

  assert tx_disable_a = tx_disable_b
    report "TX disable must not depend on LOS observation input"
    severity failure;
end architecture formal;
