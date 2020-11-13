--------------------------------------------------------------------------------
--! @file       elephant_perm.vhd
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

entity elephant_perm_protected is
    port(
        clk: in std_logic;
        load_lfsr: in std_logic;
        en_lfsr: in std_logic;
        input_a: in std_logic_vector(STATE_SIZE-1 downto 0);
        input_b: in std_logic_vector(STATE_SIZE-1 downto 0);
        random: in std_logic_vector(NUMBER_SBOXS*RANDOM_BITS_PER_SBOX - 1 downto 0);
        output_a: out std_logic_vector(STATE_SIZE-1 downto 0);
        output_b: out std_logic_vector(STATE_SIZE-1 downto 0)
    );
end elephant_perm_protected;

architecture behavior of elephant_perm_protected is
    -- No input no extra shares required
    signal lfsr, rev_lfsr: std_logic_vector(6 downto 0);
    
    signal input_array_a, state_sbox_array_a, player_array_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal input_array_b, state_sbox_array_b, player_array_b: std_logic_vector(STATE_SIZE-1 downto 0);

    attribute keep_hierarchy :string;
    attribute keep_hierarchy of behavior : architecture is "true";
    attribute keep : string;
    attribute keep of lfsr : signal is "true";
    attribute keep of rev_lfsr : signal is "true";
    attribute keep of input_array_a : signal is "true";
    attribute keep of state_sbox_array_a : signal is "true";
    attribute keep of player_array_a : signal is "true";
    attribute keep of input_array_b : signal is "true";
    attribute keep of state_sbox_array_b : signal is "true";
    attribute keep of player_array_b : signal is "true";
    
    signal input_array_comb, state_sbox_array_comb, player_array_comb: std_logic_vector(STATE_SIZE-1 downto 0);

begin
    -- Permutation LFSR does not have any inputs and does not require other shares
    --  Instead of LFSR ROM implemented LFSR
    lsfr: process (clk)
    begin
        if rising_edge(clk) then
            if load_lfsr = '1' then
                lfsr <= "1110101";
            elsif en_lfsr = '1' then
                lfsr <= lfsr(5 downto 0) & (lfsr(6) xor lfsr(5)); --LFSR poly
            end if;
        end if;
    end process;
    rev_lfsr <= lfsr(0) & lfsr(1) & lfsr(2) & lfsr(3) & lfsr(4) & lfsr(5) & lfsr(6);


    --Using the LFSR for performing one perm cycle
    input_array_a <= (rev_lfsr xor input_a(STATE_SIZE - 1 downto 153)) &
                        input_a(152 downto 7) & (lfsr xor input_a(6 downto 0));
    input_array_b <= input_b; 

    -- S-Boxes generation
    sbox_gen: for i in 39 downto 0 generate
        SBOX_E: entity work.spongent_sbox_dom_2_again
            port map(
                clk => clk,
                share1 => input_array_a(i*4 + 3 downto i*4),
                share2 => input_array_b(i*4 + 3 downto i*4),
                random => random((i+1)*RANDOM_BITS_PER_SBOX - 1 downto i*RANDOM_BITS_PER_SBOX),
                output_s1 => state_sbox_array_a(i*4+3 downto i*4),
                output_s2 => state_sbox_array_b(i*4+3 downto i*4)
            );
    end generate;

    -- Player
    playerg: for j in 0 to 158 generate
        player_array_a((40 * j) mod (STATE_SIZE-1)) <= state_sbox_array_a(j);
        player_array_b((40 * j) mod (STATE_SIZE-1)) <= state_sbox_array_b(j);
    end generate;
    player_array_a(STATE_SIZE - 1) <= state_sbox_array_a(STATE_SIZE - 1);
    player_array_b(STATE_SIZE - 1) <= state_sbox_array_b(STATE_SIZE - 1);

    DEBUG_COMB: if DEBUG = 1 generate
        input_array_comb <= input_array_a xor input_array_b;
        state_sbox_array_comb <= state_sbox_array_a xor state_sbox_array_b;
        player_array_comb <= player_array_a xor player_array_b;
    end generate;

    output_a <= player_array_a;
    output_b <= player_array_b;
    
end architecture behavior;
