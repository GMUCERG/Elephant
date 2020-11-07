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

entity elephant_perm is
    port(
        clk: in std_logic;
        load_lfsr: in std_logic;
        perm_count: in integer range 0 to PERM_CYCLES; --unsigned(4 downto 0);
        input_a: in std_logic_vector(STATE_SIZE-1 downto 0);
        input_b: in std_logic_vector(STATE_SIZE-1 downto 0);
        input_c: in std_logic_vector(STATE_SIZE-1 downto 0);
        output_a: out std_logic_vector(STATE_SIZE-1 downto 0);
        output_b: out std_logic_vector(STATE_SIZE-1 downto 0);
        output_c: out std_logic_vector(STATE_SIZE-1 downto 0)
    );
end elephant_perm;

architecture elephant_perm of elephant_perm is
    -- No input no extra shares required
    signal lfsr, rev_lfsr: std_logic_vector(6 downto 0);
    
    type input_array_t is array (0 to PERM_ROUNDS_PER_CYCLE-1) of 
                                            std_logic_vector(STATE_SIZE-1 downto 0);

    signal input_array_a, state_sbox_array_a, player_array_a: input_array_t;
    signal input_array_b, state_sbox_array_b, player_array_b: input_array_t;
    signal input_array_c, state_sbox_array_c, player_array_c: input_array_t;
    
    type rom_array is array (0 to 15) of std_logic_vector(0 to 3); 
    constant sbox: rom_array :=(
        x"e", x"d", x"b", x"0", x"2", x"1", x"4", x"f",
        x"7", x"a", x"8", x"5", x"9", x"c", x"3", x"6"
    );
    type lfsr_rom_8t is array (0 to 10) of std_logic_vector(63 downto 0);
    constant lfsr_rom8: lfsr_rom_8t :=(
        x"756a542953274f1f",
        x"3e7d7a7468502143",
        x"070e1c3871624409",
        x"12244913264d1b36",
        x"6d5a356b562d5b37",
        x"6f5e3d7b766c5831",
        x"63460d1a34695225",
        x"4b172e5d3b776e5c",
        x"3973664c1932654a",
        x"152a552b572f5f3f",
        (others => '0'));
    type lfsr_rom_5t is array (0 to 16) of std_logic_vector((8*5)-1 downto 0);
    constant lfsr_rom5: lfsr_rom_5t :=(
        x"756a542953",
        x"274f1f3e7d",
        x"7a74685021",
        x"43070e1c38",
        x"7162440912",
        x"244913264d",
        x"1b366d5a35",
        x"6b562d5b37",
        x"6f5e3d7b76",
        x"6c58316346",
        x"0d1a346952",
        x"254b172e5d",
        x"3b776e5c39",
        x"73664c1932",
        x"654a152a55",
        x"2b572f5f3f",
        (others => '0'));
    type lfsr_rom_4t is array (0 to 20) of std_logic_vector(31 downto 0);
    constant lfsr_rom4: lfsr_rom_4t :=(
        x"756a5429",
        x"53274f1f",
        x"3e7d7a74",
        x"68502143",
        x"070e1c38",
        x"71624409",
        x"12244913",
        x"264d1b36",
        x"6d5a356b",
        x"562d5b37",
        x"6f5e3d7b",
        x"766c5831",
        x"63460d1a",
        x"34695225",
        x"4b172e5d",
        x"3b776e5c",
        x"3973664c",
        x"1932654a",
        x"152a552b",
        x"572f5f3f",
        (others => '0'));


    signal lfsr_rom_sig: std_logic_vector((8*PERM_ROUNDS_PER_CYCLE)-1 downto 0);
    type lfsr_output_array_t is array(0 to PERM_ROUNDS_PER_CYCLE-1) of
                                                std_logic_vector(6 downto 0);
    signal lfsr_output_array, reverse_lfsr_output_array: lfsr_output_array_t;

begin
    -- Permutation LFSR does not have any inputs and does not require other shares
    --  Instead of LFSR ROM implemented LFSR
    perm_round1: if PERM_ROUNDS_PER_CYCLE - 1 = 0 generate
        lsfr: process (clk)
        begin
            if rising_edge(clk) then
                if load_lfsr = '1' then
                    lfsr <= "1110101";
                else
                    lfsr <= lfsr(5 downto 0) & (lfsr(6) xor lfsr(5)); --LFSR poly
                end if;
            end if;
        end process;
        rev_lfsr <= lfsr(0) & lfsr(1) & lfsr(2) & lfsr(3) & lfsr(4) & lfsr(5) & lfsr(6);-- to 6);
    end generate;
    -- Use the LFSR ROM when not doing 1 round per cycle
    perm_round_not_1: if PERM_ROUNDS_PER_CYCLE - 1 /= 0 generate
        lsfr_sig_8: if PERM_ROUNDS_PER_CYCLE = 8 generate
            lfsr_rom_sig <= lfsr_rom8(perm_count);
        end generate;
        lsfr_sig_5: if PERM_ROUNDS_PER_CYCLE = 5 generate
            lfsr_rom_sig <= lfsr_rom5(perm_count);
        end generate;
        lsfr_sig_4: if PERM_ROUNDS_PER_CYCLE = 4 generate
            lfsr_rom_sig <= lfsr_rom4(perm_count);
        end generate;
    end generate;


    -- Generating Round components
    rnd: for x in 0 to PERM_ROUNDS_PER_CYCLE-1 generate

        --Using the LFSR for performing one perm cycle
        g1: if x = 0 and PERM_ROUNDS_PER_CYCLE-1 = 0 generate
            input_array_a(x) <= (rev_lfsr xor input_a(STATE_SIZE - 1 downto 153)) &
                                input_a(152 downto 7) & (lfsr xor input_a(6 downto 0));
            input_array_b(x) <= (rev_lfsr xor input_a(STATE_SIZE - 1 downto 153)) &
                                input_b(152 downto 7) & (lfsr xor input_b(6 downto 0));
            input_array_c(x) <= (rev_lfsr xor input_a(STATE_SIZE - 1 downto 153)) &
                                input_c(152 downto 7) & (lfsr xor input_c(6 downto 0));
        end generate;


        -- Using LFSR ROMs
        permrndnot0: if PERM_ROUNDS_PER_CYCLE /= 0 generate
            lfsr_output_array(x) <= lfsr_rom_sig((8*PERM_ROUNDS_PER_CYCLE)-2-(8*x)
                                       downto (8*(PERM_ROUNDS_PER_CYCLE-1))-(8*x));
            reverse_lfsr_output_array(x) <= lfsr_output_array(x)(0) &
                                            lfsr_output_array(x)(1) &
                                            lfsr_output_array(x)(2) &
                                            lfsr_output_array(x)(3) &
                                            lfsr_output_array(x)(4) &
                                            lfsr_output_array(x)(5) &
                                            lfsr_output_array(x)(6);
        end generate;

        -- Either the first round or only one round per cycle
        g2: if x = 0 and PERM_ROUNDS_PER_CYCLE-1 /= 0 generate
            input_array_a(x) <= (reverse_lfsr_output_array(x) xor
                                   input_a(STATE_SIZE - 1 downto 153)) &
                                input_a(152 downto 7) &
                                (lfsr_output_array(x) xor input_a(6 downto 0));
            input_array_b(x) <= (reverse_lfsr_output_array(x) xor
                                   input_b(STATE_SIZE - 1 downto 153)) &
                                input_b(152 downto 7) &
                                (lfsr_output_array(x) xor input_b(6 downto 0));
            input_array_c(x) <= (reverse_lfsr_output_array(x) xor
                                   input_c(STATE_SIZE - 1 downto 153)) &
                                input_c(152 downto 7) &
                                (lfsr_output_array(x) xor input_c(6 downto 0));
        end generate;

        -- If doing a round greater than 1
        g3: if x > 0 generate
            input_array_a(x) <= (reverse_lfsr_output_array(x) xor
                                    player_array_a(x-1)(STATE_SIZE - 1 downto 153)) &
                                player_array_a(x-1)(152 downto 7) &
                                (lfsr_output_array(x) xor player_array_a(x-1)(6 downto 0));
            input_array_b(x) <= (reverse_lfsr_output_array(x) xor
                                    player_array_b(x-1)(STATE_SIZE - 1 downto 153)) &
                                player_array_b(x-1)(152 downto 7) &
                                (lfsr_output_array(x) xor player_array_b(x-1)(6 downto 0));
            input_array_c(x) <= (reverse_lfsr_output_array(x) xor
                                    player_array_c(x-1)(STATE_SIZE - 1 downto 153)) &
                                player_array_c(x-1)(152 downto 7) &
                                (lfsr_output_array(x) xor player_array_c(x-1)(6 downto 0));
        end generate;


        -- S-Boxes generation
        sbox_gen: for i in 39 downto 0 generate
            state_sbox_array_a(x)(i*4 + 3 downto i*4) <= sbox(to_integer(unsigned(
                                                           input_array_a(x)(i*4 + 3 downto i*4))));
            state_sbox_array_b(x)(i*4 + 3 downto i*4) <= sbox(to_integer(unsigned(
                                                           input_array_b(x)(i*4 + 3 downto i*4))));
            state_sbox_array_c(x)(i*4 + 3 downto i*4) <= sbox(to_integer(unsigned(
                                                           input_array_c(x)(i*4 + 3 downto i*4))));
        end generate;


        -- Player
        playerg: for j in 0 to 158 generate
            player_array_a(x)((40 * j) mod (STATE_SIZE-1)) <= state_sbox_array_a(x)(j);
            player_array_b(x)((40 * j) mod (STATE_SIZE-1)) <= state_sbox_array_b(x)(j);
            player_array_c(x)((40 * j) mod (STATE_SIZE-1)) <= state_sbox_array_c(x)(j);
        end generate;
        player_array_a(x)(STATE_SIZE - 1) <= state_sbox_array_a(x)(STATE_SIZE - 1);
        player_array_b(x)(STATE_SIZE - 1) <= state_sbox_array_b(x)(STATE_SIZE - 1);
        player_array_c(x)(STATE_SIZE - 1) <= state_sbox_array_c(x)(STATE_SIZE - 1);

    end generate;

    output_a <= player_array_a(PERM_ROUNDS_PER_CYCLE-1);
    output_b <= player_array_b(PERM_ROUNDS_PER_CYCLE-1);
    output_c <= player_array_c(PERM_ROUNDS_PER_CYCLE-1);
    
end architecture elephant_perm;
