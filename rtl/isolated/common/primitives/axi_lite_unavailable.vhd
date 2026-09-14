library ieee;
use ieee.std_logic_1164.all;

-- Small AXI-Lite terminator for removed peripherals. Independent AW/W
-- handshakes are accepted; every transaction completes with DECERR.
entity axi_lite_unavailable is
  port (
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    s_axi_awaddr  : in  std_logic_vector(31 downto 0);
    s_axi_awprot  : in  std_logic_vector(2 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(31 downto 0);
    s_axi_arprot  : in  std_logic_vector(2 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic
  );
end entity;
architecture rtl of axi_lite_unavailable is
  signal aw_pending, w_pending, b_valid, r_valid : std_logic := '0';
begin
  s_axi_awready <= s_axi_aresetn and not aw_pending and not b_valid;
  s_axi_wready <= s_axi_aresetn and not w_pending and not b_valid;
  s_axi_arready <= s_axi_aresetn and not r_valid;
  s_axi_bvalid <= b_valid;
  s_axi_rvalid <= r_valid;
  s_axi_bresp <= "11";
  s_axi_rresp <= "11";
  s_axi_rdata <= (others=>'0');
  process(s_axi_aclk)
    variable aw_seen, w_seen : std_logic;
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn='0' then
        aw_pending<='0'; w_pending<='0'; b_valid<='0'; r_valid<='0';
      else
        if b_valid='1' then
          if s_axi_bready='1' then b_valid<='0'; end if;
        else
          aw_seen := aw_pending or s_axi_awvalid;
          w_seen := w_pending or s_axi_wvalid;
          if aw_seen='1' and w_seen='1' then
            b_valid<='1'; aw_pending<='0'; w_pending<='0';
          else aw_pending<=aw_seen; w_pending<=w_seen; end if;
        end if;
        if r_valid='1' then
          if s_axi_rready='1' then r_valid<='0'; end if;
        elsif s_axi_arvalid='1' then r_valid<='1'; end if;
      end if;
    end if;
  end process;
end architecture;
