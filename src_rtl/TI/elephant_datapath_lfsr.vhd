--------------------------------------------------------------------------------
--! @file       elephant_datapath_lfsr.vhd
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

entity elephant_datapath_lfsr is
    port(
        clk: in std_logic;
        en: in std_logic;
        load_key: in std_logic;
        key_in_a: in std_logic_vector(STATE_SIZE-1 downto 0);
        key_in_b: in std_logic_vector(STATE_SIZE-1 downto 0);
        key_in_c: in std_logic_vector(STATE_SIZE-1 downto 0);
        ele_lfsr_output_a: out std_logic_vector(STATE_SIZE+16-1 downto 0)
        ele_lfsr_output_b: out std_logic_vector(STATE_SIZE+16-1 downto 0)
        ele_lfsr_output_c: out std_logic_vector(STATE_SIZE+16-1 downto 0)
    );
end elephant_datapath_lfsr;

architecture behavioral of elephant_datapath_lfsr is
    signal lfsr_input_a: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_input_b: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_input_c: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_output_a: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_output_b: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_output_c: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal lfsr_temp_rot_a: std_logic_vector(7 downto 0);
    signal lfsr_temp_rot_b: std_logic_vector(7 downto 0);
    signal lfsr_temp_rot_c: std_logic_vector(7 downto 0);
begin
    --LFSR output
    --C code
    --BYTE temp = rotl3(input[0]) ^ (input[3] << 7) ^ (input[13] >> 7);
    lfsr_temp_rot_a <= (lfsr_output_a(4+16)  xor lfsr_output_a(24+16)) &
                       lfsr_output_a(3+16 downto 0+16) &
                       lfsr_output_a(7+16 downto 6+16) &
                       (lfsr_output_a(5+16) xor lfsr_output_a(111+16));
    lfsr_temp_rot_b <= (lfsr_output_b(4+16)  xor lfsr_output_b(24+16)) &
                       lfsr_output_b(3+16 downto 0+16) &
                       lfsr_output_b(7+16 downto 6+16) &
                       (lfsr_output_b(5+16) xor lfsr_output_b(111+16));
    lfsr_temp_rot_c <= (lfsr_output_c(4+16)  xor lfsr_output_c(24+16)) &
                       lfsr_output_c(3+16 downto 0+16) &
                       lfsr_output_c(7+16 downto 6+16) &
                       (lfsr_output_c(5+16) xor lfsr_output_c(111+16));


    lfsr_input_a <= lfsr_temp_rot_a & lfsr_output_a(STATE_SIZE+16-1 downto 8) when
                        load_key_a = '0' else  key_in_a & x"0000";
    lfsr_input_b <= lfsr_temp_rot_b & lfsr_output_b(STATE_SIZE+16-1 downto 8) when
                        load_key_b = '0' else  key_in_b & x"0000";
    lfsr_input_c <= lfsr_temp_rot_c & lfsr_output_c(STATE_SIZE+16-1 downto 8) when
                        load_key_c = '0' else  key_in_c & x"0000";

    ele_lfsr_output_a <= lfsr_output_a;
    ele_lfsr_output_b <= lfsr_output_b;
    ele_lfsr_output_c <= lfsr_output_c;

    p_lfsr_data: process(clk, en)
    begin
        if rising_edge(clk) and en = '1' then
            lfsr_output_a <= lfsr_input_a;
            lfsr_output_b <= lfsr_input_b;
            lfsr_output_c <= lfsr_input_c;
        end if;
    end process;

end architecture behavioral;
