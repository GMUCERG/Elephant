--------------------------------------------------------------------------------
--! @file       spongent_sbox_dom_2_tb.vhd
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

entity spongent_sbox_dom_2_tb is
end spongent_sbox_dom_2_tb;

architecture behavior of spongent_sbox_dom_2_tb is
component spongent_sbox_dom_2_again
    port(
        clk: in std_logic;
        share1: in std_logic_vector(3 downto 0);
        share2: in std_logic_vector(3 downto 0);
--        random: in std_logic_vector(13 downto 0);
        random: in std_logic_vector(8 downto 0);
        output_s1:out std_logic_vector(3 downto 0);
        output_s2:out std_logic_vector(3 downto 0)
    );
end component;


    signal input, output, x, y, rand : integer range 0 to 15;
    signal share1, share1_mod, share2: std_logic_vector(3 downto 0);
    signal random: std_logic_vector(8 downto 0);
--    signal random: std_logic_vector(13 downto 0);
    signal output_s1, output_s2, output_actual: std_logic_vector(3 downto 0);
    signal clk : std_logic := '0';

    type rom_array is array (0 to 15) of std_logic_vector(0 to 3);
    constant sbox: rom_array :=(
        x"e", x"d", x"b", x"0", x"2", x"1", x"4", x"f",
        x"7", x"a", x"8", x"5", x"9", x"c", x"3", x"6"
    );
   
begin
uut: spongent_sbox_dom_2_again
    port map(
        clk => clk,
        share1 =>  share1_mod,
        share2 => share2,
        random => random,
        output_s1 => output_s1,
        output_s2 => output_s2
    );
    clk <= not clk after 5 ns;
    output_actual <= output_s1 xor output_s2;
    share1_mod <= share1 xor share2;
    output <= to_integer(unsigned(sbox(input)));
    
    process
    begin
        random <= (others => '0');
        share1 <= "0000";
        share2 <= "0000";
        wait for 40 ns;
        for rand in 0 to 7 loop
            random <= std_logic_vector(to_unsigned(rand,9));
--            random <= std_logic_vector(to_unsigned(rand,14));
            for y in 0 to 15 loop
                share2 <= std_logic_vector(to_unsigned(y,4));
                for x in 0 to 15 loop
                    input <= x;
                    share1 <= std_logic_vector(to_unsigned(x,4));
                    wait for 10 ns;
                    wait for 10 ns;
                    if output_actual /= std_logic_vector(to_unsigned(output, 4)) then
                        report "Test failed outputs did not match" severity error;
                        assert false report "failure" severity failure;
                    end if;
                end loop;
            end loop;
        end loop;
        wait;
    end process;
    
end;
