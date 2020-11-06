--Dom and gate as described by Hannes Gross et al.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity and_dom_n is
    generic (
           N : integer :=  1
    );
    port ( clk : in std_logic;
           X0  : in std_logic_vector(N-1 downto 0);
           X1  : in std_logic_vector(N-1 downto 0);
           Y0  : in std_logic_vector(N-1 downto 0);
           Y1  : in std_logic_vector(N-1 downto 0);
           Z   : in std_logic_vector(N-1 downto 0);
           Q0  : out std_logic_vector(N-1 downto 0);
           Q1  : out std_logic_vector(N-1 downto 0)
    );
end and_dom_n;

architecture behav of and_dom_n is

	attribute keep_hierarchy : string;
	attribute keep_hierarchy of behav : architecture is "true";
    
    signal X0Y0, X0Y1, Y0X1, Y1X1 : std_logic_vector(N-1 downto 0);
    signal reg1, reg2, reg3, reg4 : std_logic_vector(N-1 downto 0);
    
    attribute keep : string;
    attribute keep of X0Y0 : signal is "true";
    attribute keep of X0Y1 : signal is "true";
    attribute keep of Y0X1 : signal is "true";
    attribute keep of Y1X1 : signal is "true";
    attribute keep of reg1 : signal is "true";
    attribute keep of reg2 : signal is "true";
    attribute keep of reg3 : signal is "true";
    attribute keep of reg4 : signal is "true";

begin
    X0Y0 <= X0 and Y0;
    X0Y1 <= X0 and Y1;
    Y0X1 <= Y0 and X1;
    Y1X1 <= Y1 and X1;
    
    --FFs
    regs: process(clk)
    begin
        if rising_edge(clk) then
            reg1 <= X0Y1 xor Z;
            reg2 <= Y0X1 xor Z;
            reg3 <= X0Y0;
            reg4 <= Y1X1;
        end if;
    end process;
    
    Q0 <= reg1 xor reg3;
    Q1 <= reg2 xor reg4;

end behav;