--------------------------------------------------------------------------------
--! @file       counter.vhd
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

entity counter is
    generic (num_bits: integer := 8 );
    port(
        clk : std_logic;
        reset : std_logic;
        enable : in std_logic;
        q: out std_logic_vector(num_bits - 1 downto 0)
        );
end counter;

architecture Behavioral of counter is
    signal count: unsigned(num_bits-1 downto 0);
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                count <= to_unsigned(0, count'length);
            elsif enable = '1'  then
                count <= count + 1;
            end if;
        end if;
    end process;
    q <= std_logic_vector(count);
end Behavioral;
