-- Coherent, periodically refreshed status/configuration across unrelated clocks.
-- A destination reset invalidates the current value and drains any request in
-- flight. Only a request begun after reset may publish a replacement. Neither
-- XPM handshake is reset/cancelled, even if either clock stops during reset.
library ieee;
use ieee.std_logic_1164.all;
library xpm;
use xpm.vcomponents.all;

entity pdts_cdc_snapshot is
  generic (WIDTH_G : positive := 16);
  port (
    src_clk_i    : in std_logic;
    src_data_i   : in std_logic_vector(WIDTH_G-1 downto 0);
    dst_clk_i    : in std_logic;
    dst_reset_i  : in std_logic;
    dst_data_o   : out std_logic_vector(WIDTH_G-1 downto 0);
    dst_valid_o  : out std_logic;
    dst_update_o : out std_logic
  );
end entity;

architecture rtl of pdts_cdc_snapshot is
  type source_state_t is (S_IDLE, S_SEND, S_DRAIN);
  type destination_state_t is (D_IDLE, D_RESPONSE, D_ACK, D_DRAIN);
  signal source_state : source_state_t := S_IDLE;
  signal destination_state : destination_state_t := D_IDLE;
  signal request_send, request_received, request_seen, request_ack : std_logic := '0';
  signal response_send, response_received, response_seen, response_ack : std_logic := '0';
  signal response_hold, response_data : std_logic_vector(WIDTH_G-1 downto 0) := (others=>'0');
  signal discard_response : std_logic := '1';
  signal value : std_logic_vector(WIDTH_G-1 downto 0) := (others=>'0');
  signal valid, update_value : std_logic := '0';
begin
  request_cdc : xpm_cdc_handshake
    generic map (DEST_EXT_HSK=>1, DEST_SYNC_FF=>3, SRC_SYNC_FF=>3,
                 INIT_SYNC_FF=>1, SIM_ASSERT_CHK=>1, WIDTH=>1)
    port map (src_clk=>dst_clk_i, src_in=>"1", src_send=>request_send,
              src_rcv=>request_received, dest_clk=>src_clk_i,
              dest_out=>open, dest_req=>request_seen, dest_ack=>request_ack);

  response_cdc : xpm_cdc_handshake
    generic map (DEST_EXT_HSK=>1, DEST_SYNC_FF=>3, SRC_SYNC_FF=>3,
                 INIT_SYNC_FF=>1, SIM_ASSERT_CHK=>1, WIDTH=>WIDTH_G)
    port map (src_clk=>src_clk_i, src_in=>response_hold, src_send=>response_send,
              src_rcv=>response_received, dest_clk=>dst_clk_i,
              dest_out=>response_data, dest_req=>response_seen, dest_ack=>response_ack);

  process(src_clk_i)
  begin
    if rising_edge(src_clk_i) then
      case source_state is
        when S_IDLE =>
          if request_seen='1' then
            response_hold <= src_data_i;
            response_send <= '1';
            source_state <= S_SEND;
          end if;
        when S_SEND =>
          if response_received='1' then
            response_send <= '0';
            request_ack <= '1';
            source_state <= S_DRAIN;
          end if;
        when S_DRAIN =>
          if response_received='0' and request_seen='0' then
            request_ack <= '0';
            source_state <= S_IDLE;
          end if;
      end case;
    end if;
  end process;

  process(dst_clk_i)
  begin
    if rising_edge(dst_clk_i) then
      update_value <= '0';
      case destination_state is
        when D_IDLE =>
          if dst_reset_i='0' then
            discard_response <= '0';
            request_send <= '1';
            destination_state <= D_RESPONSE;
          end if;
        when D_RESPONSE =>
          if response_seen='1' then
            if discard_response='0' and dst_reset_i='0' then
              value <= response_data;
              valid <= '1';
              update_value <= '1';
            end if;
            response_ack <= '1';
            destination_state <= D_ACK;
          end if;
        when D_ACK =>
          if request_received='1' then
            request_send <= '0';
            destination_state <= D_DRAIN;
          end if;
        when D_DRAIN =>
          if response_seen='0' then response_ack <= '0'; end if;
          if response_seen='0' and request_received='0' then
            destination_state <= D_IDLE;
          end if;
      end case;
      if dst_reset_i='1' then
        valid <= '0';
        update_value <= '0';
        discard_response <= '1';
      end if;
    end if;
  end process;
  dst_data_o <= value;
  dst_valid_o <= valid;
  dst_update_o <= update_value;
end architecture;
