library ieee;
use ieee.std_logic_1164.all;

package grouped_transport_pkg is

  constant GROUPED_SOURCE_COUNT_5_C  : positive := 5;
  constant GROUPED_SOURCE_COUNT_10_C : positive := 10;
  constant GROUPED_CHANNELS_PER_SOURCE_4_C : positive := 4;

  type slv64_array_t is array (natural range <>) of std_logic_vector(63 downto 0);

  type grouped_frame_descriptor_t is record
    channel_id        : std_logic_vector(5 downto 0);
    source_group_id   : std_logic_vector(3 downto 0);
    start_ptr         : std_logic_vector(11 downto 0);
    sample0_ts        : std_logic_vector(63 downto 0);
    trigger_offset    : std_logic_vector(9 downto 0);
    frame_block_count : std_logic_vector(4 downto 0);
    baseline          : std_logic_vector(13 downto 0);
    threshold_lsb     : std_logic_vector(13 downto 0);
    trigger_sample    : std_logic_vector(13 downto 0);
    continuation      : std_logic;
    peak_desc_first   : std_logic_vector(7 downto 0);
    peak_desc_count   : std_logic_vector(7 downto 0);
  end record;

  type grouped_frame_descriptor_array_t is array (natural range <>) of grouped_frame_descriptor_t;

  constant GROUPED_FRAME_DESCRIPTOR_NULL_C : grouped_frame_descriptor_t := (
    channel_id        => (others => '0'),
    source_group_id   => (others => '0'),
    start_ptr         => (others => '0'),
    sample0_ts        => (others => '0'),
    trigger_offset    => (others => '0'),
    frame_block_count => (others => '0'),
    baseline          => (others => '0'),
    threshold_lsb     => (others => '0'),
    trigger_sample    => (others => '0'),
    continuation      => '0',
    peak_desc_first   => (others => '0'),
    peak_desc_count   => (others => '0')
  );

end package grouped_transport_pkg;
