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
        bdi_or_key: in std_logic_vector(CCW_SIZE-1 downto 0);
        padding_extra: in std_logic;
        bdi_valid_bytes : in   std_logic_vector (CCWdiv8 -1 downto 0);
        bdi_pad_loc : in   std_logic_vector (CCWdiv8 -1 downto 0);
        data_type_sel: std_logic;

        load_data_en: in std_logic;
        load_data_sel: in std_logic;
        lfsr_mux_sel: in std_logic_vector(1 downto 0);
        
        --Signals for key and npub
        key_en: in std_logic;
        npub_en: in std_logic;
        tag_en: in std_logic;
        tag_reset: in std_logic;
        
        ms_en: in std_logic;
        --Signals for permutation
        ms_sel: in std_logic_vector(1 downto 0);
        load_lfsr: in std_logic;
        
        datap_lfsr_load: in std_logic;
        datap_lfsr_en: in std_logic;
        
        bdo: out std_logic_vector(CCW_SIZE-1 downto 0);
        bdo_sel: in std_logic_vector(1 downto 0);
        saving_bdo: in std_logic;
        data_count: in integer range 0 to BLOCK_SIZE+1; --std_logic_vector(2 downto 0);
        perm_count: in integer range 0 to PERM_CYCLES;
        clk: in std_logic
    );
end elephant_datapath;

architecture behavioral of elephant_datapath is
    
    signal permout: std_logic_vector(STATE_SIZE-1 downto 0);
    
    signal datap_lfsr_out: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_current: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_next: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_prev: std_logic_vector(STATE_SIZE-1 downto 0);
    signal cur_ms_xor: std_logic_vector(STATE_SIZE-1 downto 0);
    signal prev_next_ms_xor: std_logic_vector(STATE_SIZE-1 downto 0);
    signal cur_next_ms_xor: std_logic_vector(STATE_SIZE-1 downto 0);

    
    signal bdi_or_bdo: std_logic_vector(CCW_SIZE-1 downto 0);
    signal load_data_input_mux: std_logic_vector(CCW_SIZE-1 downto 0);
    signal load_data_output: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_xor_mux: std_logic_vector(STATE_SIZE-1 downto 0);
    
    signal key_out: std_logic_vector(STATE_SIZE-1 downto 0);
    signal npub_out: std_logic_vector(NPUB_SIZE_BITS-1 downto 0);
    signal tag_out: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    signal tag_input: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    
    -- Verifiy this size
    signal ms_reg_input_mux: std_logic_vector(STATE_SIZE-1 downto 0);
    signal ms_reg_out: std_logic_vector(STATE_SIZE-1 downto 0);
    
    signal data_bdo, data_bdo1: std_logic_vector(CCW_SIZE-1 downto 0);
    signal data_out: std_logic_vector(CCW_SIZE-1 downto 0);
    
    signal lfsr_input: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_output: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_temp_rot: std_logic_vector(7 downto 0);
begin
    --LFSR output
    --C code
    --BYTE temp = rotl3(input[0]) ^ (input[3] << 7) ^ (input[13] >> 7);
    lfsr_temp_rot <= (lfsr_output(4+16)  xor lfsr_output(24+16)) & lfsr_output(3+16 downto 0+16) & lfsr_output(7+16 downto 6+16) &
                     (lfsr_output(5+16) xor lfsr_output(111+16));
    lfsr_input <= lfsr_temp_rot & lfsr_output(STATE_SIZE+16-1 downto 8) when datap_lfsr_load = '0' else  key_out & x"0000";
    datap_lfsr_out <= lfsr_output;

    p_lfsr_data: process(clk, datap_lfsr_en)
    begin
        if rising_edge(clk) and datap_lfsr_en = '1' then
            lfsr_output <= lfsr_input;
        end if;
    end process;

    PERM: entity work.elephant_perm
        port map(
            input => ms_reg_out,
            clk => clk,
            perm_count => perm_count,
            load_lfsr => load_lfsr,
            output => permout
        );
    p_ms_reg: process(clk, ms_en)
    begin
        if rising_edge(clk) and  ms_en = '1' then
            ms_reg_out <= ms_reg_input_mux;
        end if;
    end process;
    p_key_reg: process(clk, key_en)
    begin
        if rising_edge(clk) and key_en = '1' then
            key_out <= ms_reg_input_mux(STATE_SIZE-1 downto 0);
        end if;
    end process;

    p_npub_reg: process(clk, npub_en)
    begin
        if rising_edge(clk) and npub_en = '1' then
            npub_out <= load_data_output(STATE_SIZE-1 downto STATE_SIZE-NPUB_SIZE_BITS);
        end if;
    end process;

    p_tag_reg: process(clk, tag_en)
    begin
        if rising_edge(clk) and tag_en = '1' then
            tag_out <= tag_input;
        end if;
    end process;

    p_load_data: process(clk, load_data_en)
    begin
        if rising_edge(clk) and load_data_en = '1' then
                load_data_output <= load_data_input_mux & load_data_output(STATE_SIZE-1 downto CCW_SIZE);
        end if;
    end process;

    --Select between process key or bdi
    bdi_or_bdo <= bdi_or_key when saving_bdo = '0' else data_bdo;

    --Also mux is very large at the momment might be able to reduce to CCW size
    --mux to reset load_data and shift data input
    with load_data_sel select
        load_data_input_mux <= x"0000000" &"000" & padding_extra  when '0',
                               bdi_or_bdo   when others;

    --Above and beyond logic see if there is a way to not include ms_reg_out in xor.
    --Would likely required this to happen after mux and => ms_reg would be zero prior
    --to the loading the state.
    lfsr_current <= datap_lfsr_out(STATE_SIZE+8-1 downto 8);
    lfsr_next <= datap_lfsr_out(STATE_SIZE+16-1 downto 16);
    lfsr_prev <= datap_lfsr_out(STATE_SIZE-1 downto 0);
    cur_ms_xor <= lfsr_current xor ms_reg_out;
    prev_next_ms_xor <= lfsr_prev xor lfsr_next xor ms_reg_out;
    cur_next_ms_xor <= lfsr_next xor cur_ms_xor;
    with lfsr_mux_sel select
        lfsr_xor_mux <= load_data_output when "00",
                        cur_ms_xor when "01",     
                        prev_next_ms_xor when "10",
                        cur_next_ms_xor when others;
    --Update Tag
    tag_input <= lfsr_xor_mux(TAG_SIZE_BITS-1 downto 0) xor tag_out when tag_reset = '0' else (others => '0');

    --Logic for ms_reg_mux and perm
    with ms_sel select
        ms_reg_input_mux <= x"00000000" & ms_reg_out(STATE_SIZE-1 downto CCW) when "00",
                            lfsr_xor_mux when "01",
                            x"0000000000000000" & npub_out when "10",
                            permout when others; 
    data_bdo1 <= bdi_or_key xor ms_reg_out(CCW-1 downto 0);

    data_bdo <= --padd(reverse_byte(data_bdo1),bdi_valid_bytes,bdi_pad_loc);
        reverse_byte(padd(reverse_byte(data_bdo1),bdi_valid_bytes,bdi_pad_loc));
    with bdo_sel select
        bdo <= data_bdo1 when "00",
               tag_out(31 downto 0) when "01",
               tag_out(TAG_SIZE_BITS-1 downto 32) when others;
    
end behavioral;

