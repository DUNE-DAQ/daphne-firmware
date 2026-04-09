library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;

entity thresholds_axi_formal is
  port (
    clk             : in std_logic;
    write_index_i   : in std_logic_vector(5 downto 0);
    write_data_i    : in std_logic_vector(9 downto 0);
    partial_index_i : in std_logic_vector(5 downto 0);
    partial_data_i  : in std_logic_vector(9 downto 0);
    probe_index_i   : in std_logic_vector(5 downto 0)
  );
end entity thresholds_axi_formal;

architecture formal of thresholds_axi_formal is
  constant ALL_ONES_10 : std_logic_vector(9 downto 0) := (others => '1');
  constant STEP_LAST   : integer := 16;

  signal step    : integer range 0 to STEP_LAST := 0;
  signal axi_in  : AXILITE_INREC := (
    ACLK    => '0',
    ARESETN => '0',
    AWADDR  => (others => '0'),
    AWPROT  => (others => '0'),
    AWVALID => '0',
    WDATA   => (others => '0'),
    WSTRB   => (others => '0'),
    WVALID  => '0',
    BREADY  => '1',
    ARADDR  => (others => '0'),
    ARPROT  => (others => '0'),
    ARVALID => '0',
    RREADY  => '1'
  );
  signal axi_out : AXILITE_OUTREC;
  signal dout    : array_40x10_type;
  signal write_index_s   : std_logic_vector(5 downto 0) := (others => '0');
  signal write_data_s    : std_logic_vector(9 downto 0) := (others => '0');
  signal partial_index_s : std_logic_vector(5 downto 0) := (others => '0');
  signal partial_data_s  : std_logic_vector(9 downto 0) := (others => '0');
  signal probe_index_s   : std_logic_vector(5 downto 0) := (others => '0');

  function threshold_index(index : std_logic_vector(5 downto 0)) return natural is
  begin
    case to_integer(unsigned(index)) is
      when 0 to 39 => return to_integer(unsigned(index));
      when others  => return 0;
    end case;
  end function threshold_index;

  function threshold_addr(index : std_logic_vector(5 downto 0)) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(threshold_index(index) * 4, 32));
  end function threshold_addr;

  function pack_threshold_data(data : std_logic_vector(9 downto 0)) return std_logic_vector is
    variable packed : std_logic_vector(31 downto 0) := (others => '0');
  begin
    packed(9 downto 0) := data;
    return packed;
  end function pack_threshold_data;

  function expected_threshold(
    channel     : natural;
    write_index : natural;
    write_data  : std_logic_vector(9 downto 0)
  ) return std_logic_vector is
  begin
    if channel = write_index then
      return write_data;
    end if;
    return ALL_ONES_10;
  end function expected_threshold;
begin
  axi_in.ACLK <= clk;

  dut : entity work.thresholds
    port map (
      AXI_IN  => axi_in,
      AXI_OUT => axi_out,
      dout    => dout
    );

  drive_axi : process(all)
  begin
    axi_in.ARESETN <= '0';
    axi_in.AWADDR  <= (others => '0');
    axi_in.AWPROT  <= (others => '0');
    axi_in.AWVALID <= '0';
    axi_in.WDATA   <= (others => '0');
    axi_in.WSTRB   <= (others => '0');
    axi_in.WVALID  <= '0';
    axi_in.BREADY  <= '1';
    axi_in.ARADDR  <= (others => '0');
    axi_in.ARPROT  <= (others => '0');
    axi_in.ARVALID <= '0';
    axi_in.RREADY  <= '1';

    if step >= 3 then
      axi_in.ARESETN <= '1';
    end if;

    case step is
      when 3 | 4 =>
        axi_in.AWADDR  <= threshold_addr(write_index_s);
        axi_in.AWVALID <= '1';
        axi_in.WDATA   <= pack_threshold_data(write_data_s);
        axi_in.WSTRB   <= "1111";
        axi_in.WVALID  <= '1';

      when 6 | 7 =>
        axi_in.AWADDR  <= threshold_addr(partial_index_s);
        axi_in.AWVALID <= '1';
        axi_in.WDATA   <= pack_threshold_data(partial_data_s);
        axi_in.WSTRB   <= "0011";
        axi_in.WVALID  <= '1';

      when 9 | 10 =>
        axi_in.ARADDR  <= threshold_addr(write_index_s);
        axi_in.ARVALID <= '1';

      when 12 | 13 =>
        axi_in.ARADDR  <= threshold_addr(probe_index_s);
        axi_in.ARVALID <= '1';

      when others =>
        null;
    end case;
  end process drive_axi;

  check_proc : process(clk)
  begin
    if rising_edge(clk) then
      if step = 1 then
        write_index_s   <= write_index_i;
        write_data_s    <= write_data_i;
        partial_index_s <= partial_index_i;
        partial_data_s  <= partial_data_i;
        probe_index_s   <= probe_index_i;
      end if;

      -- Hold reset for three harness cycles so the synchronous-reset image is
      -- checked only after the DUT has observed multiple low-reset clocks.
      if (step >= 2) and (axi_in.ARESETN = '0') then
        assert axi_out.AWREADY = '0'
          report "AWREADY must reset low"
          severity failure;
        assert axi_out.WREADY = '0'
          report "WREADY must reset low"
          severity failure;
        assert axi_out.BVALID = '0'
          report "BVALID must reset low"
          severity failure;
        assert axi_out.ARREADY = '0'
          report "ARREADY must reset low"
          severity failure;
        assert axi_out.RVALID = '0'
          report "RVALID must reset low"
          severity failure;
        assert axi_out.BRESP = "00"
          report "BRESP must reset to OKAY"
          severity failure;
        assert axi_out.RRESP = "00"
          report "RRESP must reset to OKAY"
          severity failure;
        assert axi_out.RDATA = X"00000000"
          report "RDATA must reset low"
          severity failure;

        for i in 0 to 39 loop
          assert dout(i) = ALL_ONES_10
            report "all threshold channels must reset to all ones"
            severity failure;
        end loop;
      end if;

      case step is
        when 5 =>
          for i in 0 to 39 loop
            assert dout(i) = expected_threshold(i, threshold_index(write_index_s), write_data_s)
              report "full-strobe threshold write must update only the selected channel"
              severity failure;
          end loop;

        when 8 =>
          for i in 0 to 39 loop
            assert dout(i) = expected_threshold(i, threshold_index(write_index_s), write_data_s)
              report "partial threshold write must not modify any channel"
              severity failure;
          end loop;

        when 11 =>
          assert axi_out.RVALID = '1'
            report "readback of the written threshold channel must assert RVALID"
            severity failure;
          assert axi_out.RRESP = "00"
            report "written-channel readback must return OKAY"
            severity failure;
          assert axi_out.RDATA = pack_threshold_data(write_data_s)
            report "written threshold channel must read back the programmed value"
            severity failure;

        when 14 =>
          assert axi_out.RVALID = '1'
            report "probe-channel readback must assert RVALID"
            severity failure;
          assert axi_out.RRESP = "00"
            report "probe-channel readback must return OKAY"
            severity failure;
          assert axi_out.RDATA = pack_threshold_data(
            expected_threshold(
              threshold_index(probe_index_s),
              threshold_index(write_index_s),
              write_data_s
            )
          )
            report "probe-channel readback must match the expected threshold image"
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
