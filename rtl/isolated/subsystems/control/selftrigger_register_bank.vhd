library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity selftrigger_register_bank is
  generic (
    CHANNEL_COUNT_G : positive := 40
  );
  port (
    AXI_IN         : in  AXILITE_INREC;
    AXI_OUT        : out AXILITE_OUTREC;
    threshold_xc_o : out slv28_array_t(0 to CHANNEL_COUNT_G - 1);
    continuation_config_o : out slv32_array_t(0 to CHANNEL_COUNT_G - 1);
    record_count_i : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    full_count_i   : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    busy_count_i   : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    tcount_i       : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    pcount_i       : in  slv64_array_t(0 to CHANNEL_COUNT_G - 1);
    continuation_count_i : in slv64_array_t(0 to CHANNEL_COUNT_G - 1) := (others => (others => '0'));
    continuation_drop_count_i : in slv64_array_t(0 to CHANNEL_COUNT_G - 1) := (others => (others => '0'));
    covered_trigger_count_i : in slv64_array_t(0 to CHANNEL_COUNT_G - 1) := (others => (others => '0'));
    descriptor_overflow_count_i : in slv64_array_t(0 to CHANNEL_COUNT_G - 1) := (others => (others => '0'))
  );
end entity selftrigger_register_bank;

architecture rtl of selftrigger_register_bank is
  constant CHANNEL_STRIDE_C        : integer := 16#20#;
  constant THRESHOLD_OFFSET_C      : integer := 16#00#;
  constant RECORD_COUNT_LO_C       : integer := 16#04#;
  constant RECORD_COUNT_HI_C       : integer := 16#08#;
  constant BUSY_COUNT_LO_C         : integer := 16#0C#;
  constant BUSY_COUNT_HI_C         : integer := 16#10#;
  constant FULL_COUNT_LO_C         : integer := 16#14#;
  constant FULL_COUNT_HI_C         : integer := 16#18#;
  constant CONTINUATION_CONFIG_C   : integer := 16#1C#;
  constant PRIMITIVE_BASE_C        : integer := 16#500#;
  constant PRIMITIVE_STRIDE_C      : integer := 16#10#;
  constant TCOUNT_LO_OFFSET_C      : integer := 16#00#;
  constant TCOUNT_HI_OFFSET_C      : integer := 16#04#;
  constant PCOUNT_LO_OFFSET_C      : integer := 16#08#;
  constant PCOUNT_HI_OFFSET_C      : integer := 16#0C#;

  signal threshold_xc_reg : slv28_array_t(0 to CHANNEL_COUNT_G - 1) := (others => (others => '1'));
  signal continuation_config_reg : slv32_array_t(0 to CHANNEL_COUNT_G - 1) := (others => CONTINUATION_CONFIG_DEFAULT_C);

  signal axi_awaddr   : std_logic_vector(31 downto 0) := (others => '0');
  signal axi_awready  : std_logic := '0';
  signal axi_wready   : std_logic := '0';
  signal axi_bresp    : std_logic_vector(1 downto 0) := "00";
  signal axi_bvalid   : std_logic := '0';
  signal axi_araddr   : std_logic_vector(31 downto 0) := (others => '0');
  signal axi_arready  : std_logic := '0';
  signal axi_rdata    : std_logic_vector(31 downto 0) := (others => '0');
  signal axi_rresp    : std_logic_vector(1 downto 0) := "00";
  signal axi_rvalid   : std_logic := '0';
  signal reg_rden     : std_logic;
  signal reg_wren     : std_logic;
  signal reg_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal aw_en        : std_logic := '1';
begin
  threshold_xc_o <= threshold_xc_reg;
  continuation_config_o <= continuation_config_reg;

  AXI_OUT.AWREADY <= axi_awready;
  AXI_OUT.WREADY  <= axi_wready;
  AXI_OUT.BRESP   <= axi_bresp;
  AXI_OUT.BVALID  <= axi_bvalid;
  AXI_OUT.ARREADY <= axi_arready;
  AXI_OUT.RDATA   <= axi_rdata;
  AXI_OUT.RRESP   <= axi_rresp;
  AXI_OUT.RVALID  <= axi_rvalid;

  process (AXI_IN.ACLK)
  begin
    if rising_edge(AXI_IN.ACLK) then
      if AXI_IN.ARESETN = '0' then
        axi_awready <= '0';
        aw_en <= '1';
      else
        if axi_awready = '0' and AXI_IN.AWVALID = '1' and AXI_IN.WVALID = '1' and aw_en = '1' then
          axi_awready <= '1';
          aw_en <= '0';
        elsif AXI_IN.BREADY = '1' and axi_bvalid = '1' then
          aw_en <= '1';
          axi_awready <= '0';
        else
          axi_awready <= '0';
        end if;
      end if;
    end if;
  end process;

  process (AXI_IN.ACLK)
  begin
    if rising_edge(AXI_IN.ACLK) then
      if AXI_IN.ARESETN = '0' then
        axi_awaddr <= (others => '0');
      else
        if axi_awready = '0' and AXI_IN.AWVALID = '1' and AXI_IN.WVALID = '1' and aw_en = '1' then
          axi_awaddr <= AXI_IN.AWADDR;
        end if;
      end if;
    end if;
  end process;

  process (AXI_IN.ACLK)
  begin
    if rising_edge(AXI_IN.ACLK) then
      if AXI_IN.ARESETN = '0' then
        axi_wready <= '0';
      else
        if axi_wready = '0' and AXI_IN.WVALID = '1' and AXI_IN.AWVALID = '1' and aw_en = '1' then
          axi_wready <= '1';
        else
          axi_wready <= '0';
        end if;
      end if;
    end if;
  end process;

  reg_wren <= axi_wready and AXI_IN.WVALID and axi_awready and AXI_IN.AWVALID;

  process (AXI_IN.ACLK)
    variable addr_v : integer;
  begin
    if rising_edge(AXI_IN.ACLK) then
      if AXI_IN.ARESETN = '0' then
        for idx in 0 to CHANNEL_COUNT_G - 1 loop
          threshold_xc_reg(idx) <= (others => '1');
          continuation_config_reg(idx) <= CONTINUATION_CONFIG_DEFAULT_C;
        end loop;
      else
        if reg_wren = '1' and AXI_IN.WSTRB = "1111" then
          addr_v := to_integer(unsigned(axi_awaddr(11 downto 0)));
          for idx in 0 to CHANNEL_COUNT_G - 1 loop
            if addr_v = idx * CHANNEL_STRIDE_C + THRESHOLD_OFFSET_C then
              threshold_xc_reg(idx) <= AXI_IN.WDATA(27 downto 0);
            elsif addr_v = idx * CHANNEL_STRIDE_C + CONTINUATION_CONFIG_C then
              continuation_config_reg(idx) <= AXI_IN.WDATA and x"81FF3FFF";
            end if;
          end loop;
        end if;
      end if;
    end if;
  end process;

  process (AXI_IN.ACLK)
  begin
    if rising_edge(AXI_IN.ACLK) then
      if AXI_IN.ARESETN = '0' then
        axi_bvalid <= '0';
        axi_bresp <= "00";
      else
        if axi_awready = '1' and AXI_IN.AWVALID = '1' and axi_wready = '1' and AXI_IN.WVALID = '1' and axi_bvalid = '0' then
          axi_bvalid <= '1';
          axi_bresp <= "00";
        elsif AXI_IN.BREADY = '1' and axi_bvalid = '1' then
          axi_bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  process (AXI_IN.ACLK)
  begin
    if rising_edge(AXI_IN.ACLK) then
      if AXI_IN.ARESETN = '0' then
        axi_arready <= '0';
        axi_araddr <= (others => '1');
      else
        if axi_arready = '0' and AXI_IN.ARVALID = '1' then
          axi_arready <= '1';
          axi_araddr <= AXI_IN.ARADDR;
        else
          axi_arready <= '0';
        end if;
      end if;
    end if;
  end process;

  process (AXI_IN.ACLK)
  begin
    if rising_edge(AXI_IN.ACLK) then
      if AXI_IN.ARESETN = '0' then
        axi_rvalid <= '0';
        axi_rresp <= "00";
      else
        if axi_arready = '1' and AXI_IN.ARVALID = '1' and axi_rvalid = '0' then
          axi_rvalid <= '1';
          axi_rresp <= "00";
        elsif axi_rvalid = '1' and AXI_IN.RREADY = '1' then
          axi_rvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  reg_rden <= axi_arready and AXI_IN.ARVALID and (not axi_rvalid);

  process(all)
    variable addr_v : integer;
    variable data_v : std_logic_vector(31 downto 0);
  begin
    addr_v := to_integer(unsigned(axi_araddr(11 downto 0)));
    data_v := (others => '0');

    -- Register addresses are disjoint. Explicitly OR the decoded words so
    -- synthesis builds a parallel read mux rather than a 40-channel priority
    -- chain. AXI timing and unmapped-address zero responses are unchanged.
    for idx in 0 to CHANNEL_COUNT_G - 1 loop
      if addr_v = idx * CHANNEL_STRIDE_C + THRESHOLD_OFFSET_C then
        data_v := data_v or ("0000" & threshold_xc_reg(idx));
      end if;
      if addr_v = idx * CHANNEL_STRIDE_C + RECORD_COUNT_LO_C then
        data_v := data_v or (record_count_i(idx)(31 downto 0));
      end if;
      if addr_v = idx * CHANNEL_STRIDE_C + RECORD_COUNT_HI_C then
        data_v := data_v or (record_count_i(idx)(63 downto 32));
      end if;
      if addr_v = idx * CHANNEL_STRIDE_C + BUSY_COUNT_LO_C then
        data_v := data_v or (busy_count_i(idx)(31 downto 0));
      end if;
      if addr_v = idx * CHANNEL_STRIDE_C + BUSY_COUNT_HI_C then
        data_v := data_v or (busy_count_i(idx)(63 downto 32));
      end if;
      if addr_v = idx * CHANNEL_STRIDE_C + FULL_COUNT_LO_C then
        data_v := data_v or (full_count_i(idx)(31 downto 0));
      end if;
      if addr_v = idx * CHANNEL_STRIDE_C + FULL_COUNT_HI_C then
        data_v := data_v or (full_count_i(idx)(63 downto 32));
      end if;
      if addr_v = idx * CHANNEL_STRIDE_C + CONTINUATION_CONFIG_C then
        data_v := data_v or (continuation_config_reg(idx));
      end if;
      if addr_v = PRIMITIVE_BASE_C + idx * PRIMITIVE_STRIDE_C + TCOUNT_LO_OFFSET_C then
        data_v := data_v or (tcount_i(idx)(31 downto 0));
      end if;
      if addr_v = PRIMITIVE_BASE_C + idx * PRIMITIVE_STRIDE_C + TCOUNT_HI_OFFSET_C then
        data_v := data_v or (tcount_i(idx)(63 downto 32));
      end if;
      if addr_v = PRIMITIVE_BASE_C + idx * PRIMITIVE_STRIDE_C + PCOUNT_LO_OFFSET_C then
        data_v := data_v or (pcount_i(idx)(31 downto 0));
      end if;
      if addr_v = PRIMITIVE_BASE_C + idx * PRIMITIVE_STRIDE_C + PCOUNT_HI_OFFSET_C then
        data_v := data_v or (pcount_i(idx)(63 downto 32));
      end if;
      if addr_v = 16#800# + idx * 32 then
        data_v := data_v or (continuation_count_i(idx)(31 downto 0));
      end if;
      if addr_v = 16#804# + idx * 32 then
        data_v := data_v or (continuation_count_i(idx)(63 downto 32));
      end if;
      if addr_v = 16#808# + idx * 32 then
        data_v := data_v or (continuation_drop_count_i(idx)(31 downto 0));
      end if;
      if addr_v = 16#80C# + idx * 32 then
        data_v := data_v or (continuation_drop_count_i(idx)(63 downto 32));
      end if;
      if addr_v = 16#810# + idx * 32 then
        data_v := data_v or (covered_trigger_count_i(idx)(31 downto 0));
      end if;
      if addr_v = 16#814# + idx * 32 then
        data_v := data_v or (covered_trigger_count_i(idx)(63 downto 32));
      end if;
      if addr_v = 16#818# + idx * 32 then
        data_v := data_v or (descriptor_overflow_count_i(idx)(31 downto 0));
      end if;
      if addr_v = 16#81C# + idx * 32 then
        data_v := data_v or (descriptor_overflow_count_i(idx)(63 downto 32));
      end if;
    end loop;

    reg_data_out <= data_v;
  end process;

  process(AXI_IN.ACLK)
  begin
    if rising_edge(AXI_IN.ACLK) then
      if AXI_IN.ARESETN = '0' then
        axi_rdata <= (others => '0');
      else
        if reg_rden = '1' then
          axi_rdata <= reg_data_out;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;
