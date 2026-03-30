library ieee;
use ieee.std_logic_1164.all;

package daphne_subsystem_pkg is

  type timing_control_t is record
    use_endpoint_clock : std_logic;
    mmcm0_reset        : std_logic;
    mmcm1_reset        : std_logic;
    endpoint_reset     : std_logic;
    endpoint_addr      : std_logic_vector(15 downto 0);
  end record;

  type timing_status_t is record
    mmcm0_locked    : std_logic;
    mmcm1_locked    : std_logic;
    endpoint_ready  : std_logic;
    endpoint_state  : std_logic_vector(3 downto 0);
    timestamp_valid : std_logic;
  end record;

  type trigger_descriptor_t is record
    valid      : std_logic;
    channel_id : std_logic_vector(7 downto 0);
    version_id : std_logic_vector(3 downto 0);
    payload    : std_logic_vector(63 downto 0);
  end record;

  type hermes_boundary_status_t is record
    ready          : std_logic;
    backpressure   : std_logic;
    link_up        : std_logic;
    transport_busy : std_logic;
  end record;

  constant TIMING_CONTROL_NULL : timing_control_t := (
    use_endpoint_clock => '0',
    mmcm0_reset        => '0',
    mmcm1_reset        => '0',
    endpoint_reset     => '0',
    endpoint_addr      => (others => '0')
  );

  constant TIMING_STATUS_NULL : timing_status_t := (
    mmcm0_locked    => '0',
    mmcm1_locked    => '0',
    endpoint_ready  => '0',
    endpoint_state  => (others => '0'),
    timestamp_valid => '0'
  );

  constant TRIGGER_DESCRIPTOR_NULL : trigger_descriptor_t := (
    valid      => '0',
    channel_id => (others => '0'),
    version_id => (others => '0'),
    payload    => (others => '0')
  );

  constant HERMES_BOUNDARY_STATUS_NULL : hermes_boundary_status_t := (
    ready          => '0',
    backpressure   => '0',
    link_up        => '0',
    transport_busy => '0'
  );

end package daphne_subsystem_pkg;

package body daphne_subsystem_pkg is
end package body daphne_subsystem_pkg;
