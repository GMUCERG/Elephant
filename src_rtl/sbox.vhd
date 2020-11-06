library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.elephant_constants.all;

entity spongent_sbox is
    generic(
        constant STATE_SIZE: integer := 160
    );
    port(
         input: in integer range 0 to 15;
         output_modified: out integer range 0 to 15;
         output: out integer range 0 to 15
    );
end spongent_sbox;

architecture spongent_sbox of spongent_sbox is
    type rom_array is array (0 to 15) of std_logic_vector(0 to 3);
    constant sbox: rom_array :=(
        x"e", x"d", x"b", x"0", x"2", x"1", x"4", x"f",
        x"7", x"a", x"8", x"5", x"9", x"c", x"3", x"6"
    );
    signal input_s : std_logic_vector(3 downto 0);
    signal output_s : std_logic_vector(3 downto 0);
    signal s_0, s_1, s_2, s_3 : std_logic;
    signal s3_and_s0, s3_and_s1, s3_and_s2: std_logic;
    signal s2_and_s1: std_logic;
    signal s3_and_s2_and_s1: std_logic;
begin
    input_s <= std_logic_vector(to_unsigned(input, 4));
    output <= to_integer(unsigned(sbox(input)));
    s3_and_s0 <= input_s(3) and input_s(0);
    s3_and_s1 <= input_s(3) and input_s(1);
    s3_and_s2 <= input_s(3) and input_s(2);
    s3_and_s2_and_s1 <= input_s(3) and input_s(2) and input_s(1);
    s2_and_s1 <= input_s(2) and input_s(1);
    s_0 <= '0' xor input_s(0) xor input_s(1) xor
           s2_and_s1 xor 
           input_s(3);
    s_1 <= '1' xor input_s(0) xor s2_and_s1 xor
           s3_and_s0 xor
           s3_and_s1 xor
           s3_and_s2 xor
           s3_and_s2_and_s1;
    s_2 <= '1' xor input_s(1) xor input_s(2) xor
           s3_and_s0 xor s3_and_s2_and_s1;
    s_3 <= '1' xor (input_s(1) and input_s(0)) xor input_s(2) xor input_s(3) xor
           s3_and_s0 xor s3_and_s1 xor
           (input_s(3) and input_s(1) and input_s(0)) xor  
           (input_s(3) and input_s(2) and input_s(0));
    output_s <= s_3 & s_2 & s_1 & s_0;
    output_modified <= to_integer(unsigned(output_s));
end architecture spongent_sbox;
