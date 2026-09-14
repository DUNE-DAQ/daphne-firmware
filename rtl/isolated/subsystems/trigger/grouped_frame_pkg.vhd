library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package grouped_frame_pkg is
  -- [153:146] channel, [145:142] version, [141:0] continuation metadata.
  subtype grouped_descriptor_t is std_logic_vector(153 downto 0);
  type grouped_descriptor_array_t is array(natural range <>) of grouped_descriptor_t;
  type ring_address_array_t is array(natural range <>) of unsigned(10 downto 0);
  subtype packet_address_t is unsigned(11 downto 0);
end package;
