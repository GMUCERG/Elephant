library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.elephant_constants.all;

entity and_3_input_2_share is
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
end and_3_input_2_share;

architecture behavioral of and_3_input_2_share is
    signal gate0, gate1, gate2, gate3: std_logic;
    signal gate4, gate5, gate6, gate7: std_logic;
    signal r0, r1, r2, r3, r4, r5, r6, r7: std_logic;
begin

    gate0 <= x_0 and y_0 and z_0;
    gate1 <= x_0 and y_1 and z_0;
    gate2 <= x_1 and y_0 and z_0;
    gate3 <= x_1 and y_1 and z_0;
    
 
    gate4 <= x_0 and y_0 and z_1;
    gate5 <= x_0 and y_1 and z_1;
    gate6 <= x_1 and y_0 and z_1;
    gate7 <= x_1 and y_1 and z_1;

    --FFs
    regs: process(clk)
    begin
        if rising_edge(clk) then
            r0 <= gate0;
            r1 <= gate1 xor r0;
            r2 <= gate2 xor r1;
            r3 <= gate3 xor r2;


            r4 <= gate4 xor r2;
            r5 <= gate5 xor r1;
            r6 <= gate6 xor r0;
            r7 <= gate7;
        end if;
    end process;
    o_0 <= r0 xor r1 xor r2 xor r3;
    o_1 <= r4 xor r5 xor r6 xor r7;
end architecture behavioral;
