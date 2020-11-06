--------------------------------------------------------------------------------
--! @file       and_3_input_2_share.vhd
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

entity and_3_input_2_share is
    port(
        clk: in std_logic;
        x0: in std_logic;
        y0: in std_logic;
        z0: in std_logic;
        x1: in std_logic;
        y1: in std_logic;
        z1: in std_logic;
        rand: in std_logic_vector(2 downto 0);
        o0: out std_logic;
        o1: out std_logic
    );
end and_3_input_2_share;

architecture behavioral of and_3_input_2_share is
    attribute keep_hierarchy :string;
    attribute keep_hierarchy of behavioral : architecture is "true";
    signal x0y0z0, x0y1z0, x1y0z0, x1y1z0: std_logic;
    signal x0y0z1, x0y1z1, x1y0z1, x1y1z1: std_logic;
    signal r0, r1, r2, r3, r4, r5, r6, r7: std_logic;

    attribute keep: string;
    attribute keep of x0y0z0 : signal is "true";
    attribute keep of x0y1z0 : signal is "true";
    attribute keep of x1y0z0 : signal is "true";
    attribute keep of x1y1z0 : signal is "true";
    attribute keep of x0y0z1 : signal is "true";
    attribute keep of x0y1z1 : signal is "true";
    attribute keep of x1y0z1 : signal is "true";
    attribute keep of x1y1z1 : signal is "true";
    --attribute keep of r0 : signal is "true";
    attribute keep of r1 : signal is "true";
    attribute keep of r2 : signal is "true";
    attribute keep of r3 : signal is "true";
    attribute keep of r4 : signal is "true";
    attribute keep of r5 : signal is "true";
    attribute keep of r6 : signal is "true";
    --attribute keep of r7 : signal is "true";
begin

    x0y0z0 <= x0 and y0 and z0;
    x0y1z0 <= x0 and y1 and z0;
    x1y0z0 <= x1 and y0 and z0;
    x1y1z0 <= x1 and y1 and z0;
    
 
    x0y0z1 <= x0 and y0 and z1;
    x0y1z1 <= x0 and y1 and z1;
    x1y0z1 <= x1 and y0 and z1;
    x1y1z1 <= x1 and y1 and z1;

    --FFs
    regs: process(clk)
    begin
        if rising_edge(clk) then
            --r0 <= x0y0z0;
            r1 <= x0y1z0 xor rand(0);
            r2 <= x1y0z0 xor rand(1);
            r3 <= x1y1z0 xor rand(2);


            r4 <= x0y0z1 xor rand(2);
            r5 <= x0y1z1 xor rand(1);
            r6 <= x1y0z1 xor rand(0);
            --r7 <= x1y1z1;
        end if;
    end process;
    --o0 <= r0 xor r1 xor r2 xor r3;
    --o1 <= r4 xor r5 xor r6 xor r7;
    o0 <= x0y0z0 xor r1 xor r2 xor r3;
    o1 <= r4 xor r5 xor r6 xor x1y1z1;
end architecture behavioral;
