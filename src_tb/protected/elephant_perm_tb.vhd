--------------------------------------------------------------------------------
--! @file       elephant_perm_tb.vhd
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
use work.elephant_constants.all;

entity elephant_perm_tb is
end elephant_perm_tb;

architecture behavior of elephant_perm_tb is
component elephant_perm_protected
    port(
        clk: in std_logic;
        load_lfsr: in std_logic;
        en_lfsr: in std_logic;
        input_a: in std_logic_vector(STATE_SIZE-1 downto 0);
        input_b: in std_logic_vector(STATE_SIZE-1 downto 0);
        random: in std_logic_vector(NUMBER_SBOXS*RANDOM_BITS_PER_SBOX - 1 downto 0);
        output_a:out std_logic_vector(STATE_SIZE-1 downto 0);
        output_b:out std_logic_vector(STATE_SIZE-1 downto 0)
    );
end component;
component elephant_perm
    port(
        input: in std_logic_vector(STATE_SIZE-1 downto 0);
        clk: in std_logic;
        perm_count: in integer range 0 to PERM_CYCLES;
        load_lfsr: in std_logic;
        output: out std_logic_vector(STATE_SIZE-1 downto 0)
    );
end component;


    signal rand : integer range 0 to 15;
    signal perm_count : integer range 0 to PERM_CYCLES;
    signal x, y : integer range 0 to STATE_SIZE-1;
    signal share1, share1_mod, share2: std_logic_vector(STATE_SIZE-1 downto 0);
    signal random: std_logic_vector(NUMBER_SBOXS*RANDOM_BITS_PER_SBOX - 1 downto 0);
    signal output_s1, output_s2, output_actual, output_orig: std_logic_vector(STATE_SIZE-1 downto 0);
    signal clk, clk_slow, load_lfsr : std_logic := '1';
    signal en_lfsr : std_logic := '0';

begin
uut: elephant_perm_protected
    port map(
        clk => clk,
        load_lfsr => load_lfsr,
        en_lfsr => en_lfsr,
        input_a => share1_mod,
        input_b => share2,
        random => random,
        output_a => output_s1,
        output_b => output_s2
    );
uut2: elephant_perm
    port map(
        input => share1,
        clk => clk_slow,
        perm_count => perm_count,
        load_lfsr => load_lfsr,
        output => output_orig
    );
    clk <= not clk after 5 ns;
    output_actual <= output_s1 xor output_s2;
    share1_mod <= share1 xor share2;
    perm_count <= 0;
    
    process
    begin
        random <= (others => '0');
        share1 <= (others => '0');
        share2 <= (others => '0');
        wait for 40 ns;
        for rand in 3 to 5 loop
        --for rand in 0 to 7 loop
            random <= std_logic_vector(to_unsigned(rand,NUMBER_SBOXS*RANDOM_BITS_PER_SBOX));
            for y in 0 to 2*STATE_SIZE-1 loop
                share2 <= std_logic_vector(to_unsigned(y,STATE_SIZE));
                for x in 0 to 2*(STATE_SIZE-1) loop
                    share1 <= std_logic_vector(to_unsigned(x,STATE_SIZE));
                    load_lfsr <= '1';
                    clk_slow <= not clk_slow;
                    wait for 5 ns;
                    clk_slow <= not clk_slow;
                    wait for 5 ns;
                    load_lfsr <= '0';
                    wait for 10 ns;
                    wait for 10 ns;
                    if output_actual /= output_orig then
                        report "Test failed outputs did not match" severity error;
                        assert false report "Simulation Finished" severity failure;
                    end if;
                end loop;
            end loop;
        end loop;
        wait;
    end process;
    
end;
