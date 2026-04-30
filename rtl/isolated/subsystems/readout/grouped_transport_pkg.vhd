library ieee;
use ieee.std_logic_1164.all;

library work;
use work.tx_mux_decl.all;

package grouped_transport_pkg is

  type grouped_source_stream_t is record
    data  : std_logic_vector(63 downto 0);
    valid : std_logic;
    last  : std_logic;
  end record;

  type grouped_source_stream_array_t is array (natural range <>) of grouped_source_stream_t;

  constant GROUPED_SOURCE_STREAM_NULL_C : grouped_source_stream_t :=
    ((others => '0'), '0', '0');

  function to_src_d(
    stream_i : grouped_source_stream_t
  ) return src_d;

  function to_src_d_array(
    streams_i : grouped_source_stream_array_t
  ) return src_d_array;

end package grouped_transport_pkg;

package body grouped_transport_pkg is

  function to_src_d(
    stream_i : grouped_source_stream_t
  ) return src_d is
    variable result_v : src_d := SRC_D_NULL;
  begin
    result_v.d     := stream_i.data;
    result_v.valid := stream_i.valid;
    result_v.last  := stream_i.last;
    return result_v;
  end function to_src_d;

  function to_src_d_array(
    streams_i : grouped_source_stream_array_t
  ) return src_d_array is
    variable result_v : src_d_array(streams_i'range);
  begin
    for idx in streams_i'range loop
      result_v(idx) := to_src_d(streams_i(idx));
    end loop;
    return result_v;
  end function to_src_d_array;

end package body grouped_transport_pkg;
