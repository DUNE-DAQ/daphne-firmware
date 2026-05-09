-- st_xc.vhd
-- self trigger using matching filter for single-double-triple PE detection
--
-- This module implements a cross correlation matching filter that uses the 
-- data coming from one channel in order to generate a self trigger signal output
-- whenever simple events occur. This matching filter is capable of detecting
-- Single PhotonElectrons, Double PhotonElectrons, Triple PhotonElectrons 
--
-- Daniel Avila Gomez <daniel.avila@eia.edu.co> & Edgar Rincon Gil <edgar.rincon.g@gmail.com>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity st_xc is
port (     
    reset : in std_logic;
    clock : in std_logic; -- AFE clock 62.500 MHz
    enable : in std_logic;
    din : in std_logic_vector(13 downto 0); -- filtered AFE data (no baseline)
    threshold : in std_logic_vector(27 downto 0); -- matching filter trigger threshold values - used to be (41 downto 0)
    triggered : out std_logic;
    xcorr_calc : out signed(27 downto 0)
);
end st_xc;

architecture st_xc_arch of st_xc is

-- threshold signals (threshold window)
--------------------------------------------------------------------------------------------------------------------------------------------------
signal s_threshold: signed(27 downto 0);
--signal en_threshold: signed(13 downto 0);

-- cross correlator specific signals
--------------------------------------------------------------------------------------------------------------------------------------------------
constant ACC_WIDTH_C : positive := 21;

subtype acc_t is signed(ACC_WIDTH_C - 1 downto 0);
type acc_array_t is array (natural range <>) of acc_t;
type coeff_array_t is array (0 to 31) of integer;

-- matching filter template
constant template_xc: coeff_array_t := (
    1,
    0,
    0,
    0,
    0,
    0,
    -1,
    -1,
    -1,
    -1,
    -1,
    -2,
    -2,
    -3,
    -4,
    -4,
    -5,
    -5,
    -6,
    -7,
    -6,
    -7,
    -7,
    -7,
    -7,
    -6,
    -5,
    -4,
    -3,
    -2,
    -1,
    0
);

signal r_st_xc: acc_array_t(0 to 32):= (others => (others => '0'));
signal mult_stage0: acc_array_t(0 to 31):= (others => (others => '0'));
signal mult_stage1: acc_array_t(0 to 31):= (others => (others => '0'));
signal xcorr, xcorr_reg0, xcorr_reg1: signed(27 downto 0) := (others => '0');
signal s_r_st_xc: acc_t := (others => '0');

function abs_int(value : integer) return natural is
begin
    if value < 0 then
        return natural(-value);
    end if;
    return natural(value);
end function;

function coefficient_product(sample : signed(13 downto 0); coeff : integer) return acc_t is
    variable sample_ext : acc_t := resize(sample, ACC_WIDTH_C);
    variable magnitude  : acc_t := (others => '0');
begin
    case abs_int(coeff) is
        when 0 =>
            magnitude := (others => '0');
        when 1 =>
            magnitude := sample_ext;
        when 2 =>
            magnitude := shift_left(sample_ext, 1);
        when 3 =>
            magnitude := shift_left(sample_ext, 1) + sample_ext;
        when 4 =>
            magnitude := shift_left(sample_ext, 2);
        when 5 =>
            magnitude := shift_left(sample_ext, 2) + sample_ext;
        when 6 =>
            magnitude := shift_left(sample_ext, 2) + shift_left(sample_ext, 1);
        when 7 =>
            magnitude := shift_left(sample_ext, 3) - sample_ext;
        when others =>
            magnitude := (others => '0');
    end case;

    if coeff < 0 then
        return -magnitude;
    end if;
    return magnitude;
end function;

begin

    -- define the configuration of the trigger
--------------------------------------------------------------------------------------------------------------------------------------------------
    -- trigger threshold to ignore larger events
--    en_threshold <= signed(threshold(41 downto 28));

    -- trigger modification to compare the cross correlation output
    s_threshold <= signed(threshold(27 downto 0));

    -- Constant-coefficient transposed FIR.
    -- The old implementation used one DSP48E2 per nonzero coefficient. The
    -- coefficients are only in [-7, 1], so shift/add logic gives the same
    -- arithmetic result while preserving the two-stage tap pipeline.
    --------------------------------------------------------------------------------------------------------------------------------------------------
    st_xc_mult_proc: process(clock)
        variable din_s : signed(13 downto 0);
    begin
        if rising_edge(clock) then
            if (reset='1') then
                r_st_xc <= (others => (others => '0'));
                mult_stage0 <= (others => (others => '0'));
                mult_stage1 <= (others => (others => '0'));
            elsif (enable='1') then
                din_s := signed(din);
                r_st_xc(32) <= (others => '0');
                for i in 0 to 31 loop
                    mult_stage0(i) <= resize(
                        coefficient_product(din_s, template_xc(i)) + r_st_xc(i+1),
                        ACC_WIDTH_C
                    );
                    mult_stage1(i) <= mult_stage0(i);
                    r_st_xc(i) <= mult_stage1(i);
                end loop;
            end if;
        end if;
    end process st_xc_mult_proc;
    
    -- generate a clocked process to register the output of the cross correlation
--------------------------------------------------------------------------------------------------------------------------------------------------
    xcorr_reg: process(clock, reset, enable, r_st_xc, s_r_st_xc, xcorr, xcorr_reg0)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                -- set them to 0 whenever reset is asserted
                s_r_st_xc <= (others => '0');
                xcorr <= (others => '0');
                xcorr_reg0 <= (others => '0');
                xcorr_reg1 <= (others => '0');
            elsif (enable='1') then
                -- register the old values to keep track of how the calculation is behaving
                -- do it only if the module is enabled to trigger
                s_r_st_xc <= signed(r_st_xc(0));
                xcorr <= resize(s_r_st_xc,28);
                xcorr_reg0 <= xcorr;
                xcorr_reg1 <= xcorr_reg0;
            end if;
        end if;
    end process xcorr_reg;

    -- trigger and peak detector simple logic 
-------------------------------------------------------------------------------------------------------------------
    -- this logic uses the cross correlation output to determine when a self trigger must be 
    -- asserted. If this condition is met, it triggers a pulse one clock cycle wide
    trig_proc: process(clock, reset, enable, r_st_xc, xcorr_reg0, xcorr_reg1, s_threshold) 
    begin
        if rising_edge(clock) then
            if (reset='1') then
                triggered <= '0';
            else
                if ( ( enable='1' ) and ( xcorr>s_threshold ) 
                    and ( xcorr_reg0>s_threshold ) and ( xcorr_reg1<s_threshold or xcorr_reg1=s_threshold ) ) then 
                    triggered <= '1';
                else
                    triggered <= '0';
                end if;
            end if;
        end if;
    end process trig_proc;
    
    -- cross correlation output 
-------------------------------------------------------------------------------------------------------------------
    xcorr_calc <= xcorr; 
    
end st_xc_arch;
