entity spongent_sbox_tb is
end spongent_sbox_tb;

architecture behavior of spongent_sbox_tb is
component spongent_sbox
    port(
        input : in integer range 0 to 15;
        output_modified : out integer range 0 to 15;
        output : out integer range 0 to 15
    );
end component;


    signal input, output, output_mod, x : integer range 0 to 15;
   
begin
uut: spongent_sbox
    port map(
        input => input,
        output_modified => output_mod,
        output => output
    );
    
    process
    begin
        for x in 0 to 15 loop
            input <= x;
            wait for 10 ns;
        end loop;
        wait;
    end process;
    
end;
