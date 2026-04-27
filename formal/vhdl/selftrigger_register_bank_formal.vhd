library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne_package.all;
use work.daphne_subsystem_pkg.all;

entity selftrigger_register_bank_formal is
  port (
    clk           : in std_logic;
    write_index_i : in std_logic_vector(5 downto 0);
    write_data_i  : in std_logic_vector(27 downto 0);
    probe_index_i : in std_logic_vector(5 downto 0)
  );
end entity selftrigger_register_bank_formal;

architecture formal of selftrigger_register_bank_formal is
  constant CHANNEL_COUNT_C       : natural := 40;
  constant ALL_ONES_28_C         : std_logic_vector(27 downto 0) := (others => '1');
  constant CHANNEL_STRIDE_C      : natural := 16#20#;
  constant THRESHOLD_OFFSET_C    : natural := 16#00#;
  constant RECORD_COUNT_LO_C     : natural := 16#04#;
  constant RECORD_COUNT_HI_C     : natural := 16#08#;
  constant BUSY_COUNT_LO_C       : natural := 16#0C#;
  constant BUSY_COUNT_HI_C       : natural := 16#10#;
  constant FULL_COUNT_LO_C       : natural := 16#14#;
  constant FULL_COUNT_HI_C       : natural := 16#18#;
  constant PRIMITIVE_BASE_C      : natural := 16#500#;
  constant PRIMITIVE_STRIDE_C    : natural := 16#10#;
  constant TCOUNT_LO_OFFSET_C    : natural := 16#00#;
  constant TCOUNT_HI_OFFSET_C    : natural := 16#04#;
  constant PCOUNT_LO_OFFSET_C    : natural := 16#08#;
  constant PCOUNT_HI_OFFSET_C    : natural := 16#0C#;
  constant STEP_LAST_C           : natural := 28;

  signal step_s : natural range 0 to STEP_LAST_C := 0;

  signal axi_in_s : AXILITE_INREC := (
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
  signal axi_out_s : AXILITE_OUTREC;

  signal threshold_xc_s : slv28_array_t(0 to CHANNEL_COUNT_C - 1);
  signal record_count_s : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal full_count_s   : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal busy_count_s   : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal tcount_s       : slv64_array_t(0 to CHANNEL_COUNT_C - 1);
  signal pcount_s       : slv64_array_t(0 to CHANNEL_COUNT_C - 1);

  signal write_index_s  : std_logic_vector(5 downto 0) := (others => '0');
  signal write_data_s   : std_logic_vector(27 downto 0) := (others => '0');
  signal probe_index_s  : std_logic_vector(5 downto 0) := (others => '0');

  function channel_index(index : std_logic_vector(5 downto 0)) return natural is
  begin
    case to_integer(unsigned(index)) is
      when 0 to CHANNEL_COUNT_C - 1 => return to_integer(unsigned(index));
      when others                   => return 0;
    end case;
  end function;

  function channel_addr(index : std_logic_vector(5 downto 0); offset : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(channel_index(index) * CHANNEL_STRIDE_C + offset, 32));
  end function;

  function primitive_addr(index : std_logic_vector(5 downto 0); offset : natural) return std_logic_vector is
  begin
    return std_logic_vector(
      to_unsigned(PRIMITIVE_BASE_C + channel_index(index) * PRIMITIVE_STRIDE_C + offset, 32)
    );
  end function;

  function pack_threshold_data(value : std_logic_vector(27 downto 0)) return std_logic_vector is
    variable packed_v : std_logic_vector(31 downto 0) := (others => '0');
  begin
    packed_v(27 downto 0) := value;
    return packed_v;
  end function;

  function make_count(channel : natural; salt : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned((salt * 16#10000#) + (channel * 16#101#) + 16#55#, 64));
  end function;

  function expected_threshold(channel : natural; write_index : natural; write_data : std_logic_vector(27 downto 0)) return std_logic_vector is
  begin
    if channel = write_index then
      return write_data;
    end if;
    return ALL_ONES_28_C;
  end function;
begin
  axi_in_s.ACLK <= clk;

  gen_counts : for idx in 0 to CHANNEL_COUNT_C - 1 generate
  begin
    record_count_s(idx) <= make_count(idx, 1);
    busy_count_s(idx)   <= make_count(idx, 2);
    full_count_s(idx)   <= make_count(idx, 3);
    tcount_s(idx)       <= make_count(idx, 4);
    pcount_s(idx)       <= make_count(idx, 5);
  end generate;

  dut : entity work.selftrigger_register_bank
    generic map (
      CHANNEL_COUNT_G => CHANNEL_COUNT_C
    )
    port map (
      AXI_IN         => axi_in_s,
      AXI_OUT        => axi_out_s,
      threshold_xc_o => threshold_xc_s,
      record_count_i => record_count_s,
      full_count_i   => full_count_s,
      busy_count_i   => busy_count_s,
      tcount_i       => tcount_s,
      pcount_i       => pcount_s
    );

  drive_axi : process(all)
  begin
    axi_in_s.ARESETN <= '0';
    axi_in_s.AWADDR  <= (others => '0');
    axi_in_s.AWPROT  <= (others => '0');
    axi_in_s.AWVALID <= '0';
    axi_in_s.WDATA   <= (others => '0');
    axi_in_s.WSTRB   <= (others => '0');
    axi_in_s.WVALID  <= '0';
    axi_in_s.BREADY  <= '1';
    axi_in_s.ARADDR  <= (others => '0');
    axi_in_s.ARPROT  <= (others => '0');
    axi_in_s.ARVALID <= '0';
    axi_in_s.RREADY  <= '1';

    if step_s >= 3 then
      axi_in_s.ARESETN <= '1';
    end if;

    case step_s is
      when 3 | 4 =>
        axi_in_s.AWADDR  <= channel_addr(write_index_s, THRESHOLD_OFFSET_C);
        axi_in_s.AWVALID <= '1';
        axi_in_s.WDATA   <= pack_threshold_data(write_data_s);
        axi_in_s.WSTRB   <= "1111";
        axi_in_s.WVALID  <= '1';

      when 6 | 7 =>
        axi_in_s.AWADDR  <= channel_addr(probe_index_s, THRESHOLD_OFFSET_C);
        axi_in_s.AWVALID <= '1';
        axi_in_s.WDATA   <= std_logic_vector(to_unsigned(channel_index(probe_index_s), 32));
        axi_in_s.WSTRB   <= "0011";
        axi_in_s.WVALID  <= '1';

      when 9 | 10 =>
        axi_in_s.ARADDR  <= channel_addr(write_index_s, THRESHOLD_OFFSET_C);
        axi_in_s.ARVALID <= '1';

      when 12 | 13 =>
        axi_in_s.ARADDR  <= channel_addr(probe_index_s, THRESHOLD_OFFSET_C);
        axi_in_s.ARVALID <= '1';

      when 15 | 16 =>
        axi_in_s.ARADDR  <= channel_addr(probe_index_s, RECORD_COUNT_LO_C);
        axi_in_s.ARVALID <= '1';

      when 18 | 19 =>
        axi_in_s.ARADDR  <= channel_addr(probe_index_s, BUSY_COUNT_HI_C);
        axi_in_s.ARVALID <= '1';

      when 21 | 22 =>
        axi_in_s.ARADDR  <= primitive_addr(probe_index_s, TCOUNT_LO_OFFSET_C);
        axi_in_s.ARVALID <= '1';

      when 24 | 25 =>
        axi_in_s.ARADDR  <= primitive_addr(probe_index_s, PCOUNT_HI_OFFSET_C);
        axi_in_s.ARVALID <= '1';

      when others =>
        null;
    end case;
  end process;

  check_proc : process(clk)
    variable probe_idx_v : natural;
    variable write_idx_v : natural;
  begin
    if rising_edge(clk) then
      if step_s = 1 then
        write_index_s <= write_index_i;
        write_data_s  <= write_data_i;
        probe_index_s <= probe_index_i;
      end if;

      write_idx_v := channel_index(write_index_s);
      probe_idx_v := channel_index(probe_index_s);

      if (step_s >= 2) and (axi_in_s.ARESETN = '0') then
        assert axi_out_s.AWREADY = '0' report "AWREADY must reset low" severity failure;
        assert axi_out_s.WREADY = '0' report "WREADY must reset low" severity failure;
        assert axi_out_s.BVALID = '0' report "BVALID must reset low" severity failure;
        assert axi_out_s.ARREADY = '0' report "ARREADY must reset low" severity failure;
        assert axi_out_s.RVALID = '0' report "RVALID must reset low" severity failure;
        assert axi_out_s.BRESP = "00" report "BRESP must reset to OKAY" severity failure;
        assert axi_out_s.RRESP = "00" report "RRESP must reset to OKAY" severity failure;
        assert axi_out_s.RDATA = X"00000000" report "RDATA must reset low" severity failure;
        for idx in 0 to CHANNEL_COUNT_C - 1 loop
          assert threshold_xc_s(idx) = ALL_ONES_28_C
            report "threshold bank must reset to all ones"
            severity failure;
        end loop;
      end if;

      case step_s is
        when 5 =>
          for idx in 0 to CHANNEL_COUNT_C - 1 loop
            assert threshold_xc_s(idx) = expected_threshold(idx, write_idx_v, write_data_s)
              report "full-strobe threshold write must update only the selected channel"
              severity failure;
          end loop;

        when 8 =>
          for idx in 0 to CHANNEL_COUNT_C - 1 loop
            assert threshold_xc_s(idx) = expected_threshold(idx, write_idx_v, write_data_s)
              report "partial threshold write must not modify any threshold channel"
              severity failure;
          end loop;

        when 11 =>
          assert axi_out_s.RVALID = '1' report "written threshold channel must assert RVALID" severity failure;
          assert axi_out_s.RRESP = "00" report "written threshold channel must return OKAY" severity failure;
          assert axi_out_s.RDATA = pack_threshold_data(write_data_s)
            report "written threshold channel must read back the programmed value"
            severity failure;

        when 14 =>
          assert axi_out_s.RVALID = '1' report "probe threshold read must assert RVALID" severity failure;
          assert axi_out_s.RRESP = "00" report "probe threshold read must return OKAY" severity failure;
          assert axi_out_s.RDATA = pack_threshold_data(expected_threshold(probe_idx_v, write_idx_v, write_data_s))
            report "probe threshold channel must match the expected image"
            severity failure;

        when 17 =>
          assert axi_out_s.RVALID = '1' report "record low read must assert RVALID" severity failure;
          assert axi_out_s.RDATA = record_count_s(probe_idx_v)(31 downto 0)
            report "record low readback must match the selected channel"
            severity failure;

        when 20 =>
          assert axi_out_s.RVALID = '1' report "busy high read must assert RVALID" severity failure;
          assert axi_out_s.RDATA = busy_count_s(probe_idx_v)(63 downto 32)
            report "busy high readback must match the selected channel"
            severity failure;

        when 23 =>
          assert axi_out_s.RVALID = '1' report "tcount low read must assert RVALID" severity failure;
          assert axi_out_s.RDATA = tcount_s(probe_idx_v)(31 downto 0)
            report "tcount low readback must match the selected primitive channel"
            severity failure;

        when 26 =>
          assert axi_out_s.RVALID = '1' report "pcount high read must assert RVALID" severity failure;
          assert axi_out_s.RDATA = pcount_s(probe_idx_v)(63 downto 32)
            report "pcount high readback must match the selected primitive channel"
            severity failure;

        when others =>
          null;
      end case;

      if step_s < STEP_LAST_C then
        step_s <= step_s + 1;
      end if;
    end if;
  end process;
end architecture formal;
