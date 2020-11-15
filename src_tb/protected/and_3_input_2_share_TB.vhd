--------------------------------------------------------------------------------
--! @file       and_3_input_2_share_TB.vhd
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

entity and_3_input_2_share_tb is
end and_3_input_2_share_tb;

architecture behavior of and_3_input_2_share_tb is
component and_3_input_2_share
    port(
        clk: in std_logic;
        x_0: in std_logic;
        y_0: in std_logic;
        z_0: in std_logic;
        x_1: in std_logic;
        y_1: in std_logic;
        z_1: in std_logic;
        r_0: in std_logic;
        r_1: in std_logic;
        r_2: in std_logic;
        o_0: out std_logic;
        o_1: out std_logic
    );
end component;

    signal share1, share1_mod, share2, random :std_logic_vector(2 downto 0);
    signal clk: std_logic := '0';
    signal out1, out2, output_actual:std_logic;
    signal x, y, rand: integer range 0 to 7;
   
begin
uut: and_3_input_2_share
    port map(
        clk => clk,
        x_0 => share1_mod(0),
        y_0 => share1_mod(1),
        z_0 => share1_mod(2),
        x_1 => share2(0),
        y_1 => share2(1),
        z_1 => share2(2),
        r_0 => random(0),
        r_1 => random(1),
        r_2 => random(2),
        o_0 => out1,
        o_1 => out2
    );
    clk <= not clk after 5 ns;
    output_actual <= out1 xor out2;
    share1_mod <= share1 xor share2; 
    process
    begin
        random <= "000";
        share2 <= "000";
        share1 <= "000";
        wait for 40 ns;
        for rand in 0 to 7 loop
            random <= std_logic_vector(to_unsigned(rand,3));
            for y in 0 to 7 loop
                share2 <= std_logic_vector(to_unsigned(y,3));
                for x in 0 to 7 loop
                    share1 <= std_logic_vector(to_unsigned(x, 3));
                    wait for 10 ns;
                    wait for 10 ns;
                    if '1' = (share1(0) and share1(1) and share1(2)) then
                        assert(output_actual='1')
                        report "Test failed 1" severity error;
                    else
                        assert(output_actual='0')
                        report "Test failed 0" severity error;
                    end if;
                end loop;
            end loop;
        end loop;
        wait;
    end process;
    
end;
