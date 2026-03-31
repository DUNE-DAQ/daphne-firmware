library ieee;
use ieee.std_logic_1164.all;

-- Contract wrapper for the PDTS timing endpoint integration boundary.
--
-- This is intentionally conservative: it models the guide-level semantics the
-- DAPHNE design needs to rely on without touching the imported endpoint RTL.
entity timing_endpoint_contract is
  port (
    resetn_i          : in  std_logic;
    clock_valid_i     : in  std_logic;
    timestamp_valid_i : in  std_logic;
    command_i         : in  std_logic_vector(7 downto 0);
    command_valid_i   : in  std_logic;
    tx_enable_req_i   : in  std_logic;
    los_i             : in  std_logic;
    timestamp_i       : in  std_logic_vector(63 downto 0);
    rst_o             : out std_logic;
    ready_o           : out std_logic;
    clock_valid_o     : out std_logic;
    timestamp_valid_o : out std_logic;
    timestamp_o       : out std_logic_vector(63 downto 0);
    sync_o            : out std_logic_vector(7 downto 0);
    sync_stb_o        : out std_logic;
    tx_disable_o      : out std_logic
  );
end entity timing_endpoint_contract;

architecture rtl of timing_endpoint_contract is
  signal endpoint_ready : std_logic;
  signal sync_req       : std_logic;
begin
  endpoint_ready    <= resetn_i and clock_valid_i and timestamp_valid_i;
  ready_o           <= endpoint_ready;
  clock_valid_o     <= resetn_i and clock_valid_i;
  timestamp_valid_o <= endpoint_ready;
  rst_o             <= not endpoint_ready;
  timestamp_o       <= timestamp_i when endpoint_ready = '1' else (others => '0');

  -- Command 0 is the only sync command we model at this boundary.
  sync_req   <= '1' when command_valid_i = '1' and endpoint_ready = '1' and command_i = x"00" else '0';
  sync_stb_o <= sync_req;
  sync_o     <= command_i when sync_req = '1' else (others => '0');

  -- Keep the transmitter disabled unless the endpoint contract says the link
  -- is ready and the environment explicitly requests transmission.
  tx_disable_o <= '0' when endpoint_ready = '1' and tx_enable_req_i = '1' else '1';

  -- LOS is intentionally not used by the contract outputs. It remains a pure
  -- observation input so formal can prove it is non-gating at the wrapper.
end architecture rtl;
