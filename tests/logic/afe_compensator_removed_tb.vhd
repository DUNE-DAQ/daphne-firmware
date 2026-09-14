library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

-- LPF/XC use the repository's GHDL validation stand-ins; CFD and the filter
-- wrapper are real RTL. Check the removed block's exact one-clock bypass and
-- prove that driving its retained enable port high cannot change the path.
entity afe_compensator_removed_tb is end;
architecture test of afe_compensator_removed_tb is
  signal clk : std_logic := '0';
  signal reset, enable, invert : std_logic := '0';
  signal selector : std_logic_vector(1 downto 0) := "00";
  signal x : std_logic_vector(15 downto 0) := (others=>'0');
  type words_t is array(0 to 1) of std_logic_vector(15 downto 0);
  signal baseline, y1, y2 : words_t;
  signal trigger : std_logic_vector(0 to 1);
begin
  clk <= not clk after 8 ns;
  instances : for k in 0 to 1 generate
    dut : entity work.hpf_pedestal_recovery_filter_trigger
      port map(clk=>clk, reset=>reset, enable=>enable,
        afe_comp_enable=>std_logic(to_unsigned(k,1)(0)), invert_enable=>invert,
        threshold_xc=>std_logic_vector(to_unsigned(64,28)), output_selector=>selector,
        baseline=>baseline(k), x=>x, trigger_output=>trigger(k), y1=>y1(k), y2=>y2(k));
  end generate;
  source : process
    variable lpf, hpf, hpf_next, base, aux, xc_input, want_y1 : signed(15 downto 0) := (others=>'0');
    variable xc : signed(27 downto 0) := (others=>'0');
    variable input : signed(15 downto 0);
    variable en, rst, inv : std_logic;
    variable select_n : natural range 0 to 3;
  begin
    for n in 0 to 511 loop
      wait until falling_edge(clk);
      input:=to_signed(2000+((n*83) mod 12000),16);
      rst:='0'; if n<4 or n=250 then rst:='1'; end if;
      en:='1'; if n mod 128>=96 then en:='0'; end if;
      inv:='0'; if n mod 64>=32 then inv:='1'; end if;
      select_n:=(n/16) mod 4;
      x<=std_logic_vector(input); reset<=rst; enable<=en; invert<=inv;
      selector<=std_logic_vector(to_unsigned(select_n,2));
      if en='1' then hpf_next:=input-lpf; else hpf_next:=input; end if;
      if inv='1' then xc_input:=hpf; else xc_input:=-hpf; end if;
      if rst='1' then lpf:=(others=>'0'); xc:=(others=>'0');
      elsif en='1' then lpf:=input; xc:=resize(xc_input(13 downto 0),28); end if;
      hpf:=hpf_next;
      if inv='1' then base:=to_signed(16384,16)-lpf; aux:=-hpf; xc_input:=hpf;
      else base:=lpf; aux:=hpf; xc_input:=-hpf; end if;
      case select_n is
        when 0 => if en='1' then want_y1:=hpf+lpf; else want_y1:=hpf; end if;
        when 1 => want_y1:=base+aux;
        when 2 => want_y1:=lpf+xc(15 downto 0);
        when others => want_y1:=input;
      end case;
      wait until rising_edge(clk); wait for 1 ns;
      assert y2(0)=std_logic_vector(xc_input) report "uncompensated path lost its original one-clock latency" severity failure;
      assert baseline(0)=std_logic_vector(base) and y1(0)=std_logic_vector(want_y1)
        report "remaining baseline/polarity/output-selection path changed" severity failure;
      assert baseline(1)=baseline(0) and y1(1)=y1(0) and y2(1)=y2(0)
        report "legacy compensation enable reinstated removed processing" severity failure;
      if n>40 then assert trigger(1)=trigger(0) report "compensation enable changed CFD trigger" severity failure; end if;
    end loop;
    report "afe_compensator_removed_tb PASS: latency, enable immunity, polarity, selectors, reset" severity note;
    stop; wait;
  end process;
end;
