library ieee;
use ieee.std_logic_1164.all;

package grouped_transport_pkg is

  type grouped_source_stream_t is record
    data  : std_logic_vector(63 downto 0);
    valid : std_logic;
    last  : std_logic;
  end record;

  type grouped_source_stream_array_t is array (natural range <>) of grouped_source_stream_t;

  constant GROUPED_SOURCE_STREAM_NULL_C : grouped_source_stream_t :=
    ((others => '0'), '0', '0');

end package grouped_transport_pkg;
