-- Behavioral FIFO model with conservative pointer and count visibility.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
entity xpm_fifo_async is
  generic(CDC_SYNC_STAGES:integer:=2; DOUT_RESET_VALUE:string:="0"; ECC_MODE:string:="no_ecc";
    FIFO_MEMORY_TYPE:string:="block"; FIFO_READ_LATENCY:integer:=0; FIFO_WRITE_DEPTH:integer:=512;
    FULL_RESET_VALUE:integer:=0; PROG_EMPTY_THRESH:integer:=10; PROG_FULL_THRESH:integer:=385;
    RD_DATA_COUNT_WIDTH:integer:=10; READ_DATA_WIDTH:integer:=88; READ_MODE:string:="fwft";
    RELATED_CLOCKS:integer:=0; SIM_ASSERT_CHK:integer:=1; USE_ADV_FEATURES:string:="0004";
    WAKEUP_TIME:integer:=0; WRITE_DATA_WIDTH:integer:=88; WR_DATA_COUNT_WIDTH:integer:=10);
  port(rst,wr_clk,wr_en:in std_logic; din:in std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
    full,wr_ack,overflow,prog_full:out std_logic; wr_data_count:out std_logic_vector(WR_DATA_COUNT_WIDTH-1 downto 0);
    almost_full,wr_rst_busy:out std_logic; rd_clk,rd_en:in std_logic;
    dout:out std_logic_vector(READ_DATA_WIDTH-1 downto 0);
    empty,underflow,prog_empty:out std_logic; rd_data_count:out std_logic_vector(RD_DATA_COUNT_WIDTH-1 downto 0);
    almost_empty,data_valid,rd_rst_busy:out std_logic;
    sleep,injectsbiterr,injectdbiterr:in std_logic; sbiterr,dbiterr:out std_logic);
end entity;
architecture sim of xpm_fifo_async is
  constant AB:positive:=integer(ceil(log2(real(FIFO_WRITE_DEPTH))));
  subtype pointer_t is unsigned(AB downto 0);
  type pointer_pipe_t is array(0 to CDC_SYNC_STAGES-1) of pointer_t;
  type memory_t is array(0 to FIFO_WRITE_DEPTH-1) of std_logic_vector(WRITE_DATA_WIDTH-1 downto 0);
  signal memory:memory_t:=(others=>(others=>'0'));
  signal wp,rp: pointer_t:=(others=>'0');
  signal ws,rs:pointer_pipe_t:=(others=>(others=>'0'));
  signal count1,count2:pointer_t:=(others=>'0');
  signal wb,rb:std_logic_vector(3 downto 0):=(others=>'1');
  signal wc,rc:pointer_t;
begin
  assert READ_MODE="fwft" and READ_DATA_WIDTH=WRITE_DATA_WIDTH and FIFO_READ_LATENCY=0
    report "FIFO model supports equal-width FWFT subset only" severity failure;
  wc<=wp-rs(CDC_SYNC_STAGES-1); rc<=ws(CDC_SYNC_STAGES-1)-rp;
  full<='1' when wc>=FIFO_WRITE_DEPTH else '0';
  empty<='1' when rc=0 else '0';
  wr_rst_busy<=wb(3); rd_rst_busy<=rb(3);
  -- Two additional write-count clocks deliberately exercise reservation margin.
  wr_data_count<=std_logic_vector(resize(count2,WR_DATA_COUNT_WIDTH));
  rd_data_count<=std_logic_vector(resize(rc,RD_DATA_COUNT_WIDTH));
  dout<=memory(to_integer(rp(AB-1 downto 0)));
  process(wr_clk,rst) begin
    if rst='1' then wp<=(others=>'0'); rs<=(others=>(others=>'0')); wb<=(others=>'1'); count1<=(others=>'0'); count2<=(others=>'0');
    elsif rising_edge(wr_clk) then
      wb<=wb(2 downto 0)&'0'; rs(0)<=rp;
      for i in 1 to CDC_SYNC_STAGES-1 loop rs(i)<=rs(i-1); end loop;
      count1<=wc; count2<=count1;
      if wr_en='1' then
        assert wb(3)='0' and wc<FIFO_WRITE_DEPTH report "async FIFO overflow/reset write" severity failure;
        memory(to_integer(wp(AB-1 downto 0)))<=din; wp<=wp+1;
      end if;
    end if;
  end process;
  process(rd_clk,rst) begin
    if rst='1' then rp<=(others=>'0'); ws<=(others=>(others=>'0')); rb<=(others=>'1');
    elsif rising_edge(rd_clk) then
      rb<=rb(2 downto 0)&'0'; ws(0)<=wp;
      for i in 1 to CDC_SYNC_STAGES-1 loop ws(i)<=ws(i-1); end loop;
      if rd_en='1' then
        assert rb(3)='0' and rc/=0 report "async FIFO underflow/reset read" severity failure;
        rp<=rp+1;
      end if;
    end if;
  end process;
  wr_ack<=wr_en and not wb(3); overflow<='0'; underflow<='0';
  prog_full<='1' when wc>=PROG_FULL_THRESH else '0';
  prog_empty<='1' when rc<=PROG_EMPTY_THRESH else '0';
  almost_full<='1' when wc>=FIFO_WRITE_DEPTH-1 else '0';
  almost_empty<='1' when rc<=1 else '0';
  data_valid<='1' when rc/=0 and rb(3)='0' else '0';
  sbiterr<='0'; dbiterr<='0';
end architecture;
