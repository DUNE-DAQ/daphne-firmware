library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;

entity fe_axi_axi_formal is
  port (
    clk                  : in std_logic;
    ctrl_write_data_i    : in std_logic_vector(31 downto 0);
    partial_addr_i       : in std_logic_vector(5 downto 0);
    partial_data_i       : in std_logic_vector(31 downto 0);
    tap_index_i          : in std_logic_vector(2 downto 0);
    tap_write_data_i     : in std_logic_vector(8 downto 0);
    bitslip_index_i      : in std_logic_vector(2 downto 0);
    bitslip_write_data_i : in std_logic_vector(3 downto 0);
    idelayctrl_ready_i   : in std_logic
  );
end entity fe_axi_axi_formal;

architecture formal of fe_axi_axi_formal is
  constant CTRL_ADDR : std_logic_vector(31 downto 0) := X"00000000";
  constant STAT_ADDR : std_logic_vector(31 downto 0) := X"00000004";
  constant TRIG_ADDR : std_logic_vector(31 downto 0) := X"00000008";
  constant STEP_LAST : integer := 40;

  signal step              : integer range 0 to STEP_LAST := 0;
  signal aresetn           : std_logic := '0';
  signal awaddr            : std_logic_vector(31 downto 0) := (others => '0');
  signal awprot            : std_logic_vector(2 downto 0) := (others => '0');
  signal awvalid           : std_logic := '0';
  signal awready           : std_logic;
  signal wdata             : std_logic_vector(31 downto 0) := (others => '0');
  signal wstrb             : std_logic_vector(3 downto 0) := (others => '0');
  signal wvalid            : std_logic := '0';
  signal wready            : std_logic;
  signal bresp             : std_logic_vector(1 downto 0);
  signal bvalid            : std_logic;
  signal bready            : std_logic := '1';
  signal araddr            : std_logic_vector(31 downto 0) := (others => '0');
  signal arprot            : std_logic_vector(2 downto 0) := (others => '0');
  signal arvalid           : std_logic := '0';
  signal arready           : std_logic;
  signal rdata             : std_logic_vector(31 downto 0);
  signal rresp             : std_logic_vector(1 downto 0);
  signal rvalid            : std_logic;
  signal rready            : std_logic := '1';
  signal idelay_tap        : array_5x9_type;
  signal idelay_load       : std_logic_vector(4 downto 0);
  signal iserdes_bitslip   : array_5x4_type;
  signal iserdes_reset     : std_logic;
  signal idelayctrl_reset  : std_logic;
  signal idelay_en_vtc     : std_logic;
  signal trig              : std_logic;

  function tap_addr(index : std_logic_vector(2 downto 0)) return std_logic_vector is
  begin
    case to_integer(unsigned(index)) is
      when 0 => return X"0000000C";
      when 1 => return X"00000010";
      when 2 => return X"00000014";
      when 3 => return X"00000018";
      when 4 => return X"0000001C";
      when others => return X"0000000C";
    end case;
  end function tap_addr;

  function bitslip_addr(index : std_logic_vector(2 downto 0)) return std_logic_vector is
  begin
    case to_integer(unsigned(index)) is
      when 0 => return X"00000020";
      when 1 => return X"00000024";
      when 2 => return X"00000028";
      when 3 => return X"0000002C";
      when 4 => return X"00000030";
      when others => return X"00000020";
    end case;
  end function bitslip_addr;

  function pack_tap_data(data : std_logic_vector(8 downto 0)) return std_logic_vector is
    variable packed : std_logic_vector(31 downto 0) := (others => '0');
  begin
    packed(8 downto 0) := data;
    return packed;
  end function pack_tap_data;

  function pack_bitslip_data(data : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable packed : std_logic_vector(31 downto 0) := (others => '0');
  begin
    packed(3 downto 0) := data;
    return packed;
  end function pack_bitslip_data;

  function status_data(ready : std_logic) return std_logic_vector is
    variable packed : std_logic_vector(31 downto 0) := (others => '0');
  begin
    packed(0) := ready;
    return packed;
  end function status_data;
begin
  dut : entity work.fe_axi
    port map (
      S_AXI_ACLK        => clk,
      S_AXI_ARESETN     => aresetn,
      S_AXI_AWADDR      => awaddr,
      S_AXI_AWPROT      => awprot,
      S_AXI_AWVALID     => awvalid,
      S_AXI_AWREADY     => awready,
      S_AXI_WDATA       => wdata,
      S_AXI_WSTRB       => wstrb,
      S_AXI_WVALID      => wvalid,
      S_AXI_WREADY      => wready,
      S_AXI_BRESP       => bresp,
      S_AXI_BVALID      => bvalid,
      S_AXI_BREADY      => bready,
      S_AXI_ARADDR      => araddr,
      S_AXI_ARPROT      => arprot,
      S_AXI_ARVALID     => arvalid,
      S_AXI_ARREADY     => arready,
      S_AXI_RDATA       => rdata,
      S_AXI_RRESP       => rresp,
      S_AXI_RVALID      => rvalid,
      S_AXI_RREADY      => rready,
      trig_IN           => '0',
      idelayctrl_ready  => idelayctrl_ready_i,
      idelay_tap        => idelay_tap,
      idelay_load       => idelay_load,
      iserdes_bitslip   => iserdes_bitslip,
      iserdes_reset     => iserdes_reset,
      idelayctrl_reset  => idelayctrl_reset,
      idelay_en_vtc     => idelay_en_vtc,
      trig              => trig
    );

  drive_axi : process(all)
  begin
    aresetn <= '0';
    awaddr  <= (others => '0');
    awprot  <= (others => '0');
    awvalid <= '0';
    wdata   <= (others => '0');
    wstrb   <= (others => '0');
    wvalid  <= '0';
    bready  <= '1';
    araddr  <= (others => '0');
    arprot  <= (others => '0');
    arvalid <= '0';
    rready  <= '1';

    if step >= 2 then
      aresetn <= '1';
    end if;

    case step is
      when 2 | 3 =>
        awaddr  <= CTRL_ADDR;
        awvalid <= '1';
        wdata   <= ctrl_write_data_i;
        wstrb   <= "1111";
        wvalid  <= '1';

      when 5 | 6 =>
        awaddr  <= (31 downto 6 => '0') & partial_addr_i;
        awvalid <= '1';
        wdata   <= partial_data_i;
        wstrb   <= "0011";
        wvalid  <= '1';

      when 8 | 9 =>
        araddr  <= CTRL_ADDR;
        arvalid <= '1';

      when 11 | 12 =>
        araddr  <= STAT_ADDR;
        arvalid <= '1';

      when 14 | 15 =>
        awaddr  <= tap_addr(tap_index_i);
        awvalid <= '1';
        wdata   <= pack_tap_data(tap_write_data_i);
        wstrb   <= "1111";
        wvalid  <= '1';

      when 20 | 21 =>
        araddr  <= tap_addr(tap_index_i);
        arvalid <= '1';

      when 23 | 24 =>
        awaddr  <= bitslip_addr(bitslip_index_i);
        awvalid <= '1';
        wdata   <= pack_bitslip_data(bitslip_write_data_i);
        wstrb   <= "1111";
        wvalid  <= '1';

      when 26 | 27 =>
        araddr  <= bitslip_addr(bitslip_index_i);
        arvalid <= '1';

      when 29 | 30 =>
        awaddr  <= TRIG_ADDR;
        awvalid <= '1';
        wdata   <= X"0000BABA";
        wstrb   <= "1111";
        wvalid  <= '1';

      when others =>
        null;
    end case;
  end process drive_axi;

  check_proc : process(clk)
  begin
    if rising_edge(clk) then
      assert to_integer(unsigned(tap_index_i)) <= 4
        report "tap_index_i must select one of the five IDELAY tap registers"
        severity failure;

      assert to_integer(unsigned(bitslip_index_i)) <= 4
        report "bitslip_index_i must select one of the five ISERDES bitslip registers"
        severity failure;

      if (step >= 1) and (aresetn = '0') then
        assert awready = '0'
          report "AWREADY must reset low"
          severity failure;
        assert wready = '0'
          report "WREADY must reset low"
          severity failure;
        assert bvalid = '0'
          report "BVALID must reset low"
          severity failure;
        assert arready = '0'
          report "ARREADY must reset low"
          severity failure;
        assert rvalid = '0'
          report "RVALID must reset low"
          severity failure;
        assert bresp = "00"
          report "BRESP must reset to OKAY"
          severity failure;
        assert rresp = "00"
          report "RRESP must reset to OKAY"
          severity failure;
        assert rdata = X"00000000"
          report "RDATA must reset low"
          severity failure;
        assert idelay_en_vtc = '0'
          report "idelay_en_vtc must reset low"
          severity failure;
        assert iserdes_reset = '0'
          report "iserdes_reset must reset low"
          severity failure;
        assert idelayctrl_reset = '0'
          report "idelayctrl_reset must reset low"
          severity failure;
        assert trig = '0'
          report "trigger output must reset low"
          severity failure;
        assert idelay_load = "00000"
          report "IDELAY load pulse must reset low"
          severity failure;

        for i in 0 to 4 loop
          assert idelay_tap(i) = (idelay_tap(i)'range => '0')
            report "all IDELAY tap registers must reset low"
            severity failure;
          assert iserdes_bitslip(i) = (iserdes_bitslip(i)'range => '0')
            report "all ISERDES bitslip registers must reset low"
            severity failure;
        end loop;
      end if;

      case step is
        when 4 =>
          assert idelay_en_vtc = ctrl_write_data_i(2)
            report "control register bit 2 must drive idelay_en_vtc"
            severity failure;
          assert iserdes_reset = ctrl_write_data_i(1)
            report "control register bit 1 must drive iserdes_reset"
            severity failure;
          assert idelayctrl_reset = ctrl_write_data_i(0)
            report "control register bit 0 must drive idelayctrl_reset"
            severity failure;

        when 7 =>
          assert idelay_en_vtc = ctrl_write_data_i(2)
            report "partial writes must not modify idelay_en_vtc"
            severity failure;
          assert iserdes_reset = ctrl_write_data_i(1)
            report "partial writes must not modify iserdes_reset"
            severity failure;
          assert idelayctrl_reset = ctrl_write_data_i(0)
            report "partial writes must not modify idelayctrl_reset"
            severity failure;
          assert trig = '0'
            report "partial writes must not generate a trigger pulse"
            severity failure;
          assert idelay_load = "00000"
            report "partial writes must not generate an IDELAY load pulse"
            severity failure;

          for i in 0 to 4 loop
            assert idelay_tap(i) = (idelay_tap(i)'range => '0')
              report "partial writes must not modify IDELAY tap registers"
              severity failure;
            assert iserdes_bitslip(i) = (iserdes_bitslip(i)'range => '0')
              report "partial writes must not modify ISERDES bitslip registers"
              severity failure;
          end loop;

        when 10 =>
          assert rvalid = '1'
            report "control register readback must assert RVALID"
            severity failure;
          assert rresp = "00"
            report "control register readback must return OKAY"
            severity failure;
          assert rdata = ctrl_write_data_i
            report "control register readback must match the accepted full write"
            severity failure;

        when 13 =>
          assert rvalid = '1'
            report "status register readback must assert RVALID"
            severity failure;
          assert rresp = "00"
            report "status register readback must return OKAY"
            severity failure;
          assert rdata = status_data(idelayctrl_ready_i)
            report "status register must mirror idelayctrl_ready in bit 0 only"
            severity failure;

        when 16 =>
          for i in 0 to 4 loop
            if i = to_integer(unsigned(tap_index_i)) then
              assert idelay_tap(i) = tap_write_data_i
                report "selected IDELAY tap register must update on a full write"
                severity failure;
            else
              assert idelay_tap(i) = (idelay_tap(i)'range => '0')
                report "non-selected IDELAY tap registers must remain unchanged"
                severity failure;
            end if;
          end loop;

          assert idelay_load = "00000"
            report "IDELAY load pulse must not assert until after the accepted write"
            severity failure;

        when 17 | 18 =>
          for i in 0 to 4 loop
            if i = to_integer(unsigned(tap_index_i)) then
              assert idelay_load(i) = '1'
                report "selected IDELAY load pulse must stretch for two cycles"
                severity failure;
            else
              assert idelay_load(i) = '0'
                report "non-selected IDELAY load pulses must remain low"
                severity failure;
            end if;
          end loop;

        when 19 =>
          assert idelay_load = "00000"
            report "IDELAY load pulse must self-clear after two cycles"
            severity failure;

        when 22 =>
          assert rvalid = '1'
            report "tap register readback must assert RVALID"
            severity failure;
          assert rresp = "00"
            report "tap register readback must return OKAY"
            severity failure;
          assert rdata = pack_tap_data(tap_write_data_i)
            report "tap register readback must match the programmed tap value"
            severity failure;

        when 25 =>
          for i in 0 to 4 loop
            if i = to_integer(unsigned(bitslip_index_i)) then
              assert iserdes_bitslip(i) = bitslip_write_data_i
                report "selected bitslip register must update on a full write"
                severity failure;
            else
              assert iserdes_bitslip(i) = (iserdes_bitslip(i)'range => '0')
                report "non-selected bitslip registers must remain unchanged"
                severity failure;
            end if;
          end loop;

        when 28 =>
          assert rvalid = '1'
            report "bitslip register readback must assert RVALID"
            severity failure;
          assert rresp = "00"
            report "bitslip register readback must return OKAY"
            severity failure;
          assert rdata = pack_bitslip_data(bitslip_write_data_i)
            report "bitslip register readback must match the programmed bitslip value"
            severity failure;

        when 31 =>
          assert trig = '0'
            report "trigger output must stay low in the cycle immediately after the accepted write"
            severity failure;

        when 32 | 33 | 34 | 35 | 36 =>
          assert trig = '1'
            report "trigger write must produce a stretched trigger pulse"
            severity failure;

        when 37 =>
          assert trig = '0'
            report "trigger pulse must self-clear after the documented stretch interval"
            severity failure;
          assert rresp = "00"
            report "trigger proof must not perturb the read response code"
            severity failure;

        when others =>
          null;
      end case;

      if step < STEP_LAST then
        step <= step + 1;
      end if;
    end if;
  end process check_proc;
end architecture formal;
