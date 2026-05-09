library ieee;
use ieee.std_logic_1164.all;

entity axilite_null_slave is
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
end entity axilite_null_slave;

architecture rtl of axilite_null_slave is
  signal aw_pending_s : std_logic := '0';
  signal w_pending_s  : std_logic := '0';
  signal bvalid_s     : std_logic := '0';
  signal rvalid_s     : std_logic := '0';
  signal awready_s    : std_logic;
  signal wready_s     : std_logic;
  signal arready_s    : std_logic;
begin
  awready_s <= '1' when (aw_pending_s = '0' and bvalid_s = '0') else '0';
  wready_s  <= '1' when (w_pending_s = '0' and bvalid_s = '0') else '0';
  arready_s <= '1' when rvalid_s = '0' else '0';

  s_axi_awready <= awready_s;
  s_axi_wready  <= wready_s;
  s_axi_bresp   <= "00";
  s_axi_bvalid  <= bvalid_s;
  s_axi_arready <= arready_s;
  s_axi_rdata   <= (others => '0');
  s_axi_rresp   <= "00";
  s_axi_rvalid  <= rvalid_s;

  axi_proc : process(s_axi_aclk)
    variable aw_next_v : std_logic;
    variable w_next_v  : std_logic;
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        aw_pending_s <= '0';
        w_pending_s  <= '0';
        bvalid_s     <= '0';
        rvalid_s     <= '0';
      else
        aw_next_v := aw_pending_s;
        w_next_v  := w_pending_s;

        if awready_s = '1' and s_axi_awvalid = '1' then
          aw_next_v := '1';
        end if;

        if wready_s = '1' and s_axi_wvalid = '1' then
          w_next_v := '1';
        end if;

        if bvalid_s = '1' then
          if s_axi_bready = '1' then
            bvalid_s <= '0';
          end if;
        elsif aw_next_v = '1' and w_next_v = '1' then
          bvalid_s  <= '1';
          aw_next_v := '0';
          w_next_v  := '0';
        end if;

        aw_pending_s <= aw_next_v;
        w_pending_s  <= w_next_v;

        if rvalid_s = '1' then
          if s_axi_rready = '1' then
            rvalid_s <= '0';
          end if;
        elsif arready_s = '1' and s_axi_arvalid = '1' then
          rvalid_s <= '1';
        end if;
      end if;
    end if;
  end process axi_proc;
end architecture rtl;
