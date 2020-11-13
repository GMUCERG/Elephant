--------------------------------------------------------------------------------
--! @file       spongent_sbox_dom_2.vhd
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

entity spongent_sbox_dom_2_again is
    generic(
        constant STATE_SIZE: integer := 160
    );
    port(
        clk: in std_logic;
        share1: in std_logic_vector(3 downto 0);
        share2: in std_logic_vector(3 downto 0);
        random: in std_logic_vector(13 downto 0);
        output_s1:out std_logic_vector(3 downto 0);
        output_s2:out std_logic_vector(3 downto 0);
        output_s3:out std_logic_vector(3 downto 0);
        output_s4:out std_logic_vector(3 downto 0)
        --input: in integer range 0 to 15;
        --output: out integer range 0 to 15
    );
end spongent_sbox_dom_2_again;

architecture behav of spongent_sbox_dom_2_again is
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of behav : architecture is "true";

--    type rom_array is array (0 to 15) of std_logic_vector(0 to 3);
--    constant sbox: rom_array :=(
--        x"e", x"d", x"b", x"0", x"2", x"1", x"4", x"f",
--        x"7", x"a", x"8", x"5", x"9", x"c", x"3", x"6"
--    );
    signal and10, and21, and30, and31, and32: std_logic_vector(1 downto 0);
    signal and321, and310, and320: std_logic_vector(1 downto 0);
    --signal s2 : std_logic_vector(3 downto 0);
    signal s1_0xor1, s2_0xor1: std_logic;
    signal s1_0xor2, s2_0xor2: std_logic;
    signal s1_0xor3, s2_0xor3: std_logic;
    signal s1_1xor2, s2_1xor2: std_logic;
    signal s1_1xor3, s2_1xor3: std_logic;
    signal s_1xor2_and1: std_logic_vector(1 downto 0);
    signal s_1xor2_and_1xor3: std_logic_vector(1 downto 0);
    signal s_0xor3_and_0xor1: std_logic_vector(1 downto 0);
    signal s_3and_0xor1_and_0xor2: std_logic_vector(1 downto 0); 
    signal s_3and_1xor2_and_0xor3: std_logic_vector(1 downto 0);

    attribute keep : string;
    attribute keep of and10  : signal is "true";
    attribute keep of and21  : signal is "true";
    attribute keep of and30  : signal is "true";
    attribute keep of and31  : signal is "true";
    attribute keep of and32  : signal is "true";
    attribute keep of and321 : signal is "true";
    attribute keep of and310 : signal is "true";
    attribute keep of and320 : signal is "true";

begin
    s1_0xor1 <= share1(0) xor share1(1);
    s1_0xor2 <= share1(0) xor share1(2);
    s1_0xor3 <= share1(0) xor share1(3);
    s1_1xor2 <= share1(1) xor share1(2);
    s1_1xor3 <= share1(1) xor share1(3);

    s2_0xor1 <= share2(0) xor share2(1);
    s2_0xor2 <= share2(0) xor share2(2);
    s2_0xor3 <= share2(0) xor share2(3);
    s2_1xor2 <= share2(1) xor share2(2);
    s2_1xor3 <= share2(1) xor share2(3);
    --s2 <= share1 xor share2;
    --output <= to_integer(unsigned(sbox(input)));
    --output_s3(0) <= s2(0) xor s2(3) xor ((s2(1) xor s2(2))and s2(1));
    --output_s3(1) <= not(s2(0) xor s2(1) xor 
    --                ((s2(1) xor s2(2)) and s2(1)) xor
    --                (s2(3) and (s2(0) xor s2(1)) and (s2(0) xor s2(2))) xor
    --                ((s2(1) xor s2(2)) and (s2(0) xor s2(3)) and s2(3)));
    --output_s3(2) <= not(s2(1) xor s2(2) xor
    --                ((s2(1) xor s2(2))and(s2(1) xor s2(3))) xor
    --                ((s2(1)xor s2(2)) and s2(1)) xor
    --                (s2(3) and (s2(0) xor s2(1)) and (s2(0) xor s2(2))) xor
    --                ((s2(1) xor s2(2)) and (s2(0) xor s2(3)) and s2(3)));
    --output_s3(3) <= not(s2(0) xor s2(2) xor s2(3) xor
    --                    ((s2(1) xor s2(2)) and (s2(1) xor s2(3))) xor
    --                    ((s2(0) xor s2(3)) and (s2(0) xor s2(1))) xor
    --                    ((s2(1) xor s2(2)) and s2(1)) xor
    --                    ((s2(1) xor s2(2))  and (s2(0) xor s2(3)) and s2(3)));

    output_s3(0) <= share1(0) xor share1(3) xor s_1xor2_and1(0);
    output_s4(0) <= share2(0) xor share2(3) xor s_1xor2_and1(1);
    E_s_1xor2_and1_0: entity work.and_dom
        port map(
            clk => clk,
            X0 => s1_1xor2,
            X1 => s2_1xor2,
            Y0 => share1(1),
            Y1 => share2(1),
            Z  => random(0),
            Q0 => s_1xor2_and1(0),
            Q1 => s_1xor2_and1(1)
        );

    output_s3(1) <= not(share1(0) xor share1(1) xor
                        s_1xor2_and1(0) xor
                        s_3and_0xor1_and_0xor2(0) xor
                        s_3and_1xor2_and_0xor3(0));
    output_s4(1) <= share2(0) xor share2(1) xor
                        s_1xor2_and1(1) xor
                        s_3and_0xor1_and_0xor2(1) xor
                        s_3and_1xor2_and_0xor3(1);
    E_3And0x1And0x2: entity work.and_3_input_2_share
        port map(
            clk => clk,
            x0 => share1(3),
            y0 => s1_0xor1,
            z0 => s1_0xor2,
            x1 => share2(3),
            y1 => s2_0xor1,
            z1 => s2_0xor2,
            rand => random(3 downto 1),
            o0 => s_3and_0xor1_and_0xor2(0),
            o1 => s_3and_0xor1_and_0xor2(1)
        );
    E_3And1x2And0x3: entity work.and_3_input_2_share
        port map(
            clk => clk,
            x0 => share1(3),
            y0 => s1_1xor2,
            z0 => s1_0xor3,
            x1 => share2(3),
            y1 => s2_1xor2,
            z1 => s2_0xor3,
            rand => random(6 downto 4),
            o0 => s_3and_1xor2_and_0xor3(0),
            o1 => s_3and_1xor2_and_0xor3(1)
        );


    output_s3(2) <= not(share1(1) xor share1(2) xor
                        s_1xor2_and_1xor3(0) xor
                        s_1xor2_and1(0) xor
                        s_3and_0xor1_and_0xor2(0) xor
                        s_3and_1xor2_and_0xor3(0));
    output_s4(2) <= share2(1) xor share2(2) xor
                        s_1xor2_and_1xor3(1) xor
                        s_1xor2_and1(1) xor
                        s_3and_0xor1_and_0xor2(1) xor
                        s_3and_1xor2_and_0xor3(1);
    E_s_1xor2_and_1xor3: entity work.and_dom
        port map(
            clk => clk,
            X0 => s1_1xor2,
            X1 => s2_1xor2,
            Y0 => s1_1xor3,
            Y1 => s2_1xor3,
            Z  => random(7),
            Q0 => s_1xor2_and_1xor3(0),
            Q1 => s_1xor2_and_1xor3(1)
        );

    output_s3(3) <= not(share1(0) xor share1(2) xor share1(3) xor
                        s_1xor2_and_1xor3(0) xor
                        s_0xor3_and_0xor1(0) xor
                        s_1xor2_and1(0) xor
                        s_3and_1xor2_and_0xor3(0));
    output_s4(3) <= share2(0) xor share2(2) xor share2(3) xor
                        s_1xor2_and_1xor3(1) xor
                        s_0xor3_and_0xor1(1) xor
                        s_1xor2_and1(1) xor
                        s_3and_1xor2_and_0xor3(1);
    E_s_0xor3_and_0xor1: entity work.and_dom
        port map(
            clk => clk,
            X0 => s1_0xor3,
            X1 => s2_0xor3,
            Y0 => s1_0xor1,
            Y1 => s2_0xor1,
            Z  => random(8),
            Q0 => s_0xor3_and_0xor1(0),
            Q1 => s_0xor3_and_0xor1(1)
        );

    output_s1(0) <= share1(0) xor share1(1) xor and21(0) xor share1(3);
    output_s2(0) <= share2(0) xor share2(1) xor and21(1) xor share2(3);

    output_s1(1) <= '1' xor share1(0) xor and21(0) xor and30(0) xor and31(0) xor and32(0) xor and321(0);
    output_s2(1) <=         share2(0) xor and21(1) xor and30(1) xor and31(1) xor and32(1) xor and321(1);

    output_s1(2) <= '1' xor share1(1) xor share1(2) xor and30(0) xor and321(0);
    output_s2(2) <=         share2(1) xor share2(2) xor and30(1) xor and321(1);

    output_s1(3) <= '1' xor and10(0) xor share1(2) xor share1(3) xor and30(0) xor
                            and31(0) xor and310(0) xor and320(0);
    output_s2(3) <=         and10(1) xor share2(2) xor share2(3) xor and30(1) xor
                            and31(1) xor and310(1) xor and320(1);

    E_AND321: entity work.and_3_input_2_share
        port map(
            clk => clk,
            x0 => share1(3),
            y0 => share1(2),
            z0 => share1(1),
            x1 => share2(3),
            y1 => share2(2),
            z1 => share2(1),
            rand => random(2 downto 0),
            o0 => and321(0),
            o1 => and321(1)
        );
    E_AND310: entity work.and_3_input_2_share
        port map(
            clk => clk,
            x0 => share1(3),
            y0 => share1(1),
            z0 => share1(0),
            x1 => share2(3),
            y1 => share2(1),
            z1 => share2(0),
            rand => random(5 downto 3),
            o0 => and310(0),
            o1 => and310(1)
        );
    E_AND320: entity work.and_3_input_2_share
        port map(
            clk => clk,
            x0 => share1(3),
            y0 => share1(2),
            z0 => share1(0),
            x1 => share2(3),
            y1 => share2(2),
            z1 => share2(0),
            rand => random(8 downto 6),
            o0 => and320(0),
            o1 => and320(1)
        );
    E_AND10_0: entity work.and_dom
        port map(
            clk => clk,
            X0 => share1(0),
            X1 => share2(0),
            Y0 => share1(1),
            Y1 => share2(1),
            Z  => random(9),
            Q0 => and10(0),
            Q1 => and10(1)
        );
    E_AND21_0: entity work.and_dom
        port map(
            clk => clk,
            X0 => share1(1),
            X1 => share2(1),
            Y0 => share1(2),
            Y1 => share2(2),
            Z  => random(10),
            Q0 => and21(0),
            Q1 => and21(1)
        );
    E_AND30_0: entity work.and_dom
        port map(
            clk => clk,
            X0 => share1(0),
            X1 => share2(0),
            Y0 => share1(3),
            Y1 => share2(3),
            Z  => random(11),
            Q0 => and30(0),
            Q1 => and30(1)
        );
    E_AND31_0: entity work.and_dom
        port map(
            clk => clk,
            X0 => share1(1),
            X1 => share2(1),
            Y0 => share1(3),
            Y1 => share2(3),
            Z  => random(12),
            Q0 => and31(0),
            Q1 => and31(1)
        );
    E_AND32_0: entity work.and_dom
        port map(
            clk => clk,
            X0 => share1(2),
            X1 => share2(2),
            Y0 => share1(3),
            Y1 => share2(3),
            Z  => random(13),
            Q0 => and32(0),
            Q1 => and32(1)
        );

end architecture behav;
