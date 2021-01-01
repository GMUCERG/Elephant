--------------------------------------------------------------------------------
--! @file       elephant_datapath.vhd
--! @brief      
--! @author     Richard Haeussler
--! @copyright  Copyright (c) 2020 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.elephant_constants.all;
use work.Design_pkg.all;

entity elephant_datapath is
    port(
        --Signals to con
        sipo: in std_logic_vector(STATE_SIZE-1 downto 0);
        sipo_cnt : integer range 0 to BLOCK_SIZE+1;
        sipo_valid_bytes : in   std_logic_vector (CCWdiv8 -1 downto 0);
        sipo_pad_loc : in   std_logic_vector (CCWdiv8 -1 downto 0);

        piso_en: in std_logic;
        piso_sel: in std_logic_vector(1 downto 0);
        
        --Signals for key and npub
        key_en: in std_logic;
        npub_en: in std_logic;
        tag_sel: in std_logic_vector(1 downto 0);
        
        ms_en: in std_logic;
        ms_sel: in std_logic;

        
        datap_lfsr_load: in std_logic;
        datap_lfsr_en: in std_logic;

        adcreg_en : in std_logic;
        adcreg_sel: in std_logic_vector(2 downto 0);
        
        bdo: out std_logic_vector(CCW_SIZE-1 downto 0);

        load_lfsr: in std_logic;
        perm_count: in integer range 0 to PERM_CYCLES;
        clk: in std_logic
    );
end elephant_datapath;

architecture behavioral of elephant_datapath is
    
    signal permout1, permout2: std_logic_vector(STATE_SIZE-1 downto 0);
    
    signal datap_lfsr_out: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_current: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_next: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_prev: std_logic_vector(STATE_SIZE-1 downto 0);
    
    signal key_out: std_logic_vector(STATE_SIZE-1 downto 0);
    signal npub_out: std_logic_vector(NPUB_SIZE_BITS-1 downto 0);
    signal tag_out, tag_temp, tag_ad, tag_ct: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    signal tag_input: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    

    signal piso, piso_input_mux: std_logic_vector(STATE_SIZE-1 downto 0);

    
    signal mreg, ms_reg_input_mux, ms_mask_out: std_logic_vector(STATE_SIZE-1 downto 0);
    signal ms_mask_out0, ms_mask_out1, ms_mask_out2, ms_mask_out3, ms_mask_out4: std_logic_vector(CCW-1 downto 0);
    signal npub_xor : std_logic_vector(NPUB_SIZE_BITS-1 downto 0);

    signal adcreg, mask_temp, ad_mask, ct_mask: std_logic_vector(STATE_SIZE-1 downto 0);

    signal lfsr_input: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_output: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_temp_rot: std_logic_vector(7 downto 0);
    
    
begin
    --Idea is to stop sipo on last byte
    --Load into here then padd next cycle in here while loading into sipo normally
    mask_temp <= adcreg xor lfsr_next;
    ad_mask <= mask_temp xor lfsr_prev;
    ct_mask <= mask_temp xor lfsr_current;

    ms_mask_out <= mreg xor sipo xor lfsr_current;
    ms_mask_out0 <= ms_mask_out(CCW-1 downto 0);
    ms_mask_out1 <= ms_mask_out(CCW*2-1 downto CCW);
    ms_mask_out2 <= ms_mask_out(CCW*3-1 downto CCW*2);
    ms_mask_out3 <= ms_mask_out(CCW*4-1 downto CCW*3);
    ms_mask_out4 <= ms_mask_out(CCW*5-1 downto CCW*4);
                             
    p_adcreg: process(all)
    begin
        if rising_edge(clk) then
            if adcreg_en = '1' then
                if adcreg_sel = "000" then
                    adcreg <= permout2;
                elsif adcreg_sel = "001" then
                    adcreg <= sipo;
                elsif adcreg_sel = "011" then
                    adcreg <= ad_mask;
                elsif adcreg_sel = "100" then
                    adcreg <= ct_mask;
                elsif adcreg_sel = "010" then
                    if sipo_cnt <= 1 then
                        adcreg(CCW-1 downto 0) <= reverse_byte(padd(reverse_byte(ms_mask_out0),
                                                sipo_valid_bytes,
                                                sipo_pad_loc, x"01"));
                    else --All of the bytes valid
                        adcreg(CCW-1 downto 0) <= ms_mask_out0;
                    end if;

                    if sipo_cnt < 2 then
                        if sipo_valid_bytes = "1111" and sipo_cnt = 1 then
                            adcreg(CCW*2-1 downto CCW*1) <= x"00000001";
                        else
                            adcreg(CCW*2-1 downto CCW*1) <= (others => '0');
                        end if;
                    elsif sipo_cnt = 2 then
                        adcreg(CCW*2-1 downto CCW*1) <= reverse_byte(padd(reverse_byte(ms_mask_out1),
                                                                     sipo_valid_bytes,
                                                                     sipo_pad_loc, x"01"));
                    else
                         adcreg(CCW*2-1 downto CCW*1) <= ms_mask_out1;
                    end if;

                    if sipo_cnt < 3 then
                        if sipo_valid_bytes = "1111" and sipo_cnt = 2 then
                            adcreg(CCW*3-1 downto CCW*2) <= x"00000001";
                        else
                            adcreg(CCW*3-1 downto CCW*2) <= (others => '0');
                        end if;
                    elsif sipo_cnt = 3 then
                        adcreg(CCW*3-1 downto CCW*2) <= reverse_byte(padd(reverse_byte(ms_mask_out2),
                                                                     sipo_valid_bytes,
                                                                     sipo_pad_loc, x"01"));
                    else
                        adcreg(CCW*3-1 downto CCW*2) <= ms_mask_out2;
                    end if;
                    
                    if sipo_cnt < 4 then
                        if sipo_valid_bytes = "1111" and sipo_cnt = 3 then
                            adcreg(CCW*4-1 downto CCW*3) <= x"00000001";
                        else
                            adcreg(CCW*4-1 downto CCW*3) <= (others => '0');
                        end if;
                    elsif sipo_cnt = 4 then
                        adcreg(CCW*4-1 downto CCW*3) <= reverse_byte(padd(reverse_byte(ms_mask_out3),
                                                                     sipo_valid_bytes,
                                                                     sipo_pad_loc, x"01"));
                    else
                        adcreg(CCW*4-1 downto CCW*3) <= ms_mask_out3;
                    end if;
                    
                    if sipo_cnt < 5 then
                        if sipo_valid_bytes = "1111" and sipo_cnt = 4 then
                            adcreg(CCW*5-1 downto CCW*4) <= x"00000001";
                        else
                            adcreg(CCW*5-1 downto CCW*4) <= (others => '0');
                        end if;
                    elsif sipo_cnt = 5 then
                        adcreg(CCW*5-1 downto CCW*4) <= reverse_byte(padd(reverse_byte(ms_mask_out4),
                                                                     sipo_valid_bytes,
                                                                     sipo_pad_loc, x"01"));
                    else
                        adcreg(CCW*5-1 downto CCW*4) <= ms_mask_out4;
                    end if;
                --elsif adcreg_sel = "111" then
                --    adcreg(sipo_cnt) <=  padd(adcreg(CCW*(sipo_cnt+1)-1 downto CCW*sipo_cnt), sipo_valid_bytes, sipo_pad_loc, x"01");                    
                end if;
            --adcreg <= adcreg_blocks(4) & adcreg_blocks(3) & adcreg_blocks(2) & adcreg_blocks(1) & adcreg_blocks(0);
            end if;
            if key_en = '1' then
                key_out <= permout2;
            end if;
        end if;
    end process;


    --LFSR output
    --C code
    --BYTE temp = rotl3(input[0]) ^ (input[3] << 7) ^ (input[13] >> 7);
    lfsr_temp_rot <= (lfsr_output(4+16)  xor lfsr_output(24+16)) & lfsr_output(3+16 downto 0+16) & lfsr_output(7+16 downto 6+16) &
                     (lfsr_output(5+16) xor lfsr_output(111+16));
    lfsr_input <= lfsr_temp_rot & lfsr_output(STATE_SIZE+16-1 downto 8) when datap_lfsr_load = '0' else  key_out & x"0000";
    datap_lfsr_out <= lfsr_output;

    --Above and beyond logic see if there is a way to not include ms_reg_out in xor.
    --Would likely required this to happen after mux and => ms_reg would be zero prior
    --to the loading the state.
    lfsr_current <= datap_lfsr_out(STATE_SIZE+8-1 downto 8);
    lfsr_next <= datap_lfsr_out(STATE_SIZE+16-1 downto 16);
    lfsr_prev <= datap_lfsr_out(STATE_SIZE-1 downto 0);

    p_lfsr_data: process(clk, datap_lfsr_en)
    begin
        if rising_edge(clk) and datap_lfsr_en = '1' then
            lfsr_output <= lfsr_input;
        end if;
    end process;

    PERM: entity work.elephant_perm
        port map(
            input => mreg,
            clk => clk,
            perm_count => perm_count,
            load_lfsr => load_lfsr,
            output => permout1
        );
    PERM2: entity work.elephant_perm
        port map(
            input => adcreg,
            clk => clk,
            perm_count => perm_count,
            load_lfsr => load_lfsr,
            output => permout2
        );

    npub_xor <= npub_out xor lfsr_current(NPUB_SIZE_BITS-1 downto 0);
    with ms_sel select
        ms_reg_input_mux <= 
                            lfsr_current(STATE_SIZE-1 downto NPUB_SIZE_BITS) & npub_xor when '0',
                            permout1 when others;

    p_ms_reg: process(clk, ms_en)
    begin
        if rising_edge(clk) and  ms_en = '1' then
            mreg <= ms_reg_input_mux;
        end if;
    end process;


    p_npub_reg: process(clk, npub_en)
    begin
        if rising_edge(clk) and npub_en = '1' then
            npub_out <= sipo(NPUB_SIZE_BITS-1 downto 0);
        end if;
    end process;

    tag_temp <= tag_out xor mask_temp(TAG_SIZE_BITS-1 downto 0);
    tag_ad <= tag_temp xor lfsr_prev(TAG_SIZE_BITS-1 downto 0);
    tag_ct <= tag_temp xor lfsr_current(TAG_SIZE_BITS-1 downto 0);

    --Update Tag
    with tag_sel select
        tag_input <= tag_out when "00",
                     tag_ad when "01",
                     tag_ct when "10",
                     (others =>'0') when others;
    p_tag_reg: process(clk)
    begin
        if rising_edge(clk) then
            tag_out <= tag_input;
        end if;
    end process;
    
    
    with piso_sel select
        piso_input_mux <= x"000000000000000000000000"&tag_out when "00",
                          ms_mask_out when "01",
                          x"00000000" & piso(STATE_SIZE-1 downto CCW) when others;
    p_piso: process(all)
    begin
        if rising_edge(clk) and piso_en = '1' then
                piso <= piso_input_mux;
        end if;
    end process;
    
    bdo <= piso(CCW-1 downto 0);
    
end behavioral;

