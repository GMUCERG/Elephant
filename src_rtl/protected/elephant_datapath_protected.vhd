--------------------------------------------------------------------------------
--! @file       elephant_datapath.vhd
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
use work.design_pkg.all;

entity elephant_datapath_protected is
    port(
        --Signals to con
        key_a: in std_logic_vector(CCW_SIZE-1 downto 0);
        key_b: in std_logic_vector(CCW_SIZE-1 downto 0);
        bdi_a: in std_logic_vector(CCW_SIZE-1 downto 0);
        bdi_b: in std_logic_vector(CCW_SIZE-1 downto 0);
        random: in std_logic_vector(RANDOM_BITS_PER_SBOX*NUMBER_SBOXS - 1 downto 0);
        bdi_size: in std_logic_vector(1 downto 0);
        data_type_sel: std_logic;

        load_data_en: in std_logic;
        load_data_sel: in std_logic_vector(1 downto 0);
        lfsr_mux_sel: in std_logic_vector(1 downto 0);
        
        --Signals for key and npub
        key_en: in std_logic;
        npub_en: in std_logic;
        tag_en: in std_logic;
        tag_reset: in std_logic;
        
        ms_en: in std_logic;
        --Signals for permutation
        perm_sel: in std_logic;
        load_lfsr: in std_logic;
        en_lfsr:in std_logic;
        
        datap_lfsr_load: in std_logic;
        datap_lfsr_en: in std_logic;
        
        bdo_a: out std_logic_vector(CCW_SIZE-1 downto 0);
        bdo_b: out std_logic_vector(CCW_SIZE-1 downto 0);
        bdo_sel: in std_logic;
        saving_bdo: in std_logic;
        data_count: in std_logic_vector(2 downto 0);
        clk: in std_logic
    );
end elephant_datapath_protected;

architecture behavioral of elephant_datapath_protected is
    attribute keep_hierarchy :string;
    attribute keep_hierarchy of behavioral : architecture is "true";
    attribute keep : string;

    signal permout_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal permout_b: std_logic_vector(STATE_SIZE-1 downto 0);
    signal permout_comb: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of permout_a : signal is "true";
    attribute keep of permout_b : signal is "true";

    signal perm_input_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal perm_input_b: std_logic_vector(STATE_SIZE-1 downto 0);
    signal perm_input_comb: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of perm_input_a : signal is "true";
    attribute keep of perm_input_b : signal is "true";

    signal datap_lfsr_out_a: std_logic_vector(STATE_SIZE+16-1 downto 0);
    signal datap_lfsr_out_b: std_logic_vector(STATE_SIZE+16-1 downto 0);
    attribute keep of datap_lfsr_out_a : signal is "true";
    attribute keep of datap_lfsr_out_b : signal is "true";

    signal lfsr_current_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_current_b: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_current_comb: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of lfsr_current_a : signal is "true";
    attribute keep of lfsr_current_b : signal is "true";

    signal lfsr_next_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_next_b: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of lfsr_next_a : signal is "true";
    attribute keep of lfsr_next_b : signal is "true";

    signal lfsr_prev_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_prev_b: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of lfsr_prev_a : signal is "true";
    attribute keep of lfsr_prev_b : signal is "true";

    signal cur_ms_xor_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal cur_ms_xor_b: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of cur_ms_xor_a : signal is "true";
    attribute keep of cur_ms_xor_b : signal is "true";

    signal prev_next_ms_xor_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal prev_next_ms_xor_b: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of prev_next_ms_xor_a : signal is "true";
    attribute keep of prev_next_ms_xor_b : signal is "true";

    signal cur_next_ms_xor_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal cur_next_ms_xor_b: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of cur_next_ms_xor_a : signal is "true";
    attribute keep of cur_next_ms_xor_b : signal is "true";

    signal bdi_or_key_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal bdi_or_key_b: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of bdi_or_key_a : signal is "true";
    attribute keep of bdi_or_key_b : signal is "true";

    signal bdi_or_key_rev_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal bdi_or_key_rev_b: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of bdi_or_key_rev_a : signal is "true";
    attribute keep of bdi_or_key_rev_b : signal is "true";

    signal bdi_or_bdo_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal bdi_or_bdo_b: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of bdi_or_bdo_a : signal is "true";
    attribute keep of bdi_or_bdo_b : signal is "true";

    signal padding_bdi_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal padding_bdi_b: std_logic_vector(CCW_SIZE-1 downto 0);
    signal padding_bdi_comb: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of padding_bdi_a : signal is "true";
    attribute keep of padding_bdi_b : signal is "true";

    signal load_data_input_mux_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal load_data_input_mux_b: std_logic_vector(CCW_SIZE-1 downto 0);
    signal load_data_input_mux_comb: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of load_data_input_mux_a : signal is "true";
    attribute keep of load_data_input_mux_b : signal is "true";

    signal load_data_output_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal load_data_output_b: std_logic_vector(STATE_SIZE-1 downto 0);
    signal load_data_output_comb: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of load_data_output_a : signal is "true";
    attribute keep of load_data_output_b : signal is "true";

    signal lfsr_xor_mux_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal lfsr_xor_mux_b: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of lfsr_xor_mux_a : signal is "true";
    attribute keep of lfsr_xor_mux_b : signal is "true";
    
    signal key_out_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal key_out_b: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of key_out_a : signal is "true";
    attribute keep of key_out_b : signal is "true";

    signal npub_out_a: std_logic_vector(NPUB_SIZE_BITS-1 downto 0);
    signal npub_out_b: std_logic_vector(NPUB_SIZE_BITS-1 downto 0);
    signal npub_out_comb: std_logic_vector(NPUB_SIZE_BITS-1 downto 0);
    attribute keep of npub_out_a : signal is "true";
    attribute keep of npub_out_b : signal is "true";

    signal tag_out_a: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    signal tag_out_b: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    signal tag_out_comb: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    attribute keep of tag_out_a : signal is "true";
    attribute keep of tag_out_b : signal is "true";

    signal tag_input_a: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    signal tag_input_b: std_logic_vector(TAG_SIZE_BITS-1 downto 0);
    attribute keep of tag_input_a : signal is "true";
    attribute keep of tag_input_b : signal is "true";

    signal ms_reg_input_mux_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal ms_reg_input_mux_b: std_logic_vector(STATE_SIZE-1 downto 0);
    signal ms_reg_input_mux_comb: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of ms_reg_input_mux_a : signal is "true";
    attribute keep of ms_reg_input_mux_b : signal is "true";

    signal ms_reg_out_a: std_logic_vector(STATE_SIZE-1 downto 0);
    signal ms_reg_out_b: std_logic_vector(STATE_SIZE-1 downto 0);
    signal ms_reg_out_comb: std_logic_vector(STATE_SIZE-1 downto 0);
    attribute keep of ms_reg_out_a : signal is "true";
    attribute keep of ms_reg_out_b : signal is "true";

    signal ms_out_mux1_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal ms_out_mux1_b: std_logic_vector(CCW_SIZE-1 downto 0);
    signal ms_out_mux1_comb: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of ms_out_mux1_a : signal is "true";
    attribute keep of ms_out_mux1_b : signal is "true";

    signal ms_out_mux2_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal ms_out_mux2_b: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of ms_out_mux2_a : signal is "true";
    attribute keep of ms_out_mux2_b : signal is "true";

    signal data_out_mux_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal data_out_mux_b: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of data_out_mux_a : signal is "true";
    attribute keep of data_out_mux_b : signal is "true";

    signal data_bdo_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal data_bdo_b: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of data_bdo_a : signal is "true";
    attribute keep of data_bdo_b : signal is "true";

    signal tag_mux_a: std_logic_vector(CCW_SIZE-1 downto 0);
    signal tag_mux_b: std_logic_vector(CCW_SIZE-1 downto 0);
    signal tag_mux_comb: std_logic_vector(CCW_SIZE-1 downto 0);
    attribute keep of tag_mux_a : signal is "true";
    attribute keep of tag_mux_b : signal is "true";

    signal bdo_comb, bdo_comb_t: std_logic_vector(CCW_SIZE-1 downto 0);
begin
    DEBUG_COMB: if DEBUG = 1 generate
        permout_comb <= permout_a xor permout_b;
        perm_input_comb <= perm_input_a xor perm_input_b;
        lfsr_current_comb <= lfsr_current_a xor lfsr_current_b;
        ms_out_mux1_comb <= ms_out_mux1_a xor ms_out_mux1_b;
        ms_reg_input_mux_comb <= ms_reg_input_mux_a xor ms_reg_input_mux_b;
        ms_reg_out_comb <= ms_reg_out_a xor ms_reg_out_b;
        load_data_input_mux_comb <= load_data_input_mux_a xor load_data_input_mux_b;
        load_data_output_comb <= load_data_output_a xor load_data_output_b;
        npub_out_comb <= npub_out_a xor npub_out_b;
        tag_mux_comb <= tag_mux_a xor tag_mux_b;
        tag_out_comb <= tag_out_a xor tag_out_b;
        bdo_comb_t <= data_out_mux_a xor data_out_mux_b;
        bdo_comb <= reverse_byte(bdo_comb_t);
        padding_bdi_comb <= padding_bdi_a xor padding_bdi_b;
    end generate;
    PERM: entity work.elephant_perm_protected
        port map(
            clk => clk,
            load_lfsr => load_lfsr,
            en_lfsr => en_lfsr,
            input_a => perm_input_a,
            input_b => perm_input_b,
            random => random,
            output_a => permout_a,
            output_b => permout_b
        );
    DATAP_LFSR: entity work.elephant_datapath_lfsr_protected
        port map(
            clk         => clk,
            en          => datap_lfsr_en,
            load_key    => datap_lfsr_load,
            key_in_a      => key_out_a,
            key_in_b      => key_out_b,
            ele_lfsr_output_a => datap_lfsr_out_a,
            ele_lfsr_output_b => datap_lfsr_out_b
        );
    p_ms_reg: process(clk, ms_en)
    begin
        if rising_edge(clk) and  ms_en = '1' then
            ms_reg_out_a <= ms_reg_input_mux_a;
            ms_reg_out_b <= ms_reg_input_mux_b;
        end if;
    end process;
    p_key_reg: process(clk, key_en)
    begin
        if rising_edge(clk) and key_en = '1' then
            key_out_a <= ms_reg_input_mux_a(STATE_SIZE-1 downto 0);
            key_out_b <= ms_reg_input_mux_b(STATE_SIZE-1 downto 0);
        end if;
    end process;

    p_npub_reg: process(clk, npub_en)
    begin
        if rising_edge(clk) and npub_en = '1' then
            npub_out_a <= load_data_output_a(STATE_SIZE-1 downto STATE_SIZE-NPUB_SIZE_BITS);
            npub_out_b <= load_data_output_b(STATE_SIZE-1 downto STATE_SIZE-NPUB_SIZE_BITS);
        end if;
    end process;

    p_tag_reg: process(clk, tag_en)
    begin
        if rising_edge(clk) and tag_en = '1' then
            tag_out_a <= tag_input_a;
            tag_out_b <= tag_input_b;
        end if;
    end process;

    p_load_data: process(clk, load_data_en)
    begin
        if rising_edge(clk) and load_data_en = '1' then
            if load_data_sel = "11" then
                load_data_output_a <= x"0000000000000000" & npub_out_a;
                load_data_output_b <= x"0000000000000000" & npub_out_b;
            else
                load_data_output_a <= load_data_input_mux_a & load_data_output_a(STATE_SIZE-1 downto CCW_SIZE);
                load_data_output_b <= load_data_input_mux_b & load_data_output_b(STATE_SIZE-1 downto CCW_SIZE);
            end if;
        end if;
    end process;

    --Select between process key or bdi
    bdi_or_key_a <= bdi_a when data_type_sel = '0' else  key_a;
    bdi_or_key_b <= bdi_b when data_type_sel = '0' else  key_b;
    bdi_or_key_rev_a <= reverse_byte(bdi_or_key_a);
    bdi_or_key_rev_b <= reverse_byte(bdi_or_key_b);
    bdi_or_bdo_a <= bdi_or_key_rev_a when saving_bdo = '0' else data_bdo_a;
    bdi_or_bdo_b <= bdi_or_key_rev_b when saving_bdo = '0' else data_bdo_b;
    
    
   --Logic for how padding works
    with bdi_size select
        padding_bdi_a <= x"00000001" when "00",
                       x"000001" & bdi_or_bdo_a(7 downto 0) when "01",
                       x"0001" & bdi_or_bdo_a(15 downto 0) when "10",
                       x"01" & bdi_or_bdo_a(23 downto 0) when others;
    with bdi_size select
        padding_bdi_b <= x"00000000" when "00",
                       x"000000" & bdi_or_bdo_b(7 downto 0) when "01",
                       x"0000" & bdi_or_bdo_b(15 downto 0) when "10",
                       x"00" & bdi_or_bdo_b(23 downto 0) when others;

    --Controls the next input into the load_data register
    with load_data_sel select
        load_data_input_mux_a <= x"00000000"  when "00",
                               bdi_or_bdo_a   when "01",
                               padding_bdi_a  when others;
    with load_data_sel select
        load_data_input_mux_b <= x"00000000"  when "00",
                                 bdi_or_bdo_b   when "01",
                                 padding_bdi_b when others;

    --Above and beyond logic see if there is a way to not include ms_reg_out in xor.
    --Would likely required this to happen after mux and => ms_reg would be zero prior
    --to the loading the state.
    lfsr_current_a <= datap_lfsr_out_a(STATE_SIZE+8-1 downto 8);
    lfsr_current_b <= datap_lfsr_out_b(STATE_SIZE+8-1 downto 8);

    lfsr_next_a <= datap_lfsr_out_a(STATE_SIZE+16-1 downto 16);
    lfsr_next_b <= datap_lfsr_out_b(STATE_SIZE+16-1 downto 16);

    lfsr_prev_a <= datap_lfsr_out_a(STATE_SIZE-1 downto 0);
    lfsr_prev_b <= datap_lfsr_out_b(STATE_SIZE-1 downto 0);

    cur_ms_xor_a <= lfsr_current_a xor ms_reg_out_a;
    cur_ms_xor_b <= lfsr_current_b xor ms_reg_out_b;

    prev_next_ms_xor_a <= lfsr_prev_a xor lfsr_next_a xor ms_reg_out_a;
    prev_next_ms_xor_b <= lfsr_prev_b xor lfsr_next_b xor ms_reg_out_b;

    cur_next_ms_xor_a <= lfsr_next_a xor cur_ms_xor_a;
    cur_next_ms_xor_b <= lfsr_next_b xor cur_ms_xor_b;

    with lfsr_mux_sel select
        lfsr_xor_mux_a <= load_data_output_a when "00",
                        cur_ms_xor_a when "01",     
                        prev_next_ms_xor_a when "10",
                        cur_next_ms_xor_a when others;
    with lfsr_mux_sel select
        lfsr_xor_mux_b <= load_data_output_b when "00",
                        cur_ms_xor_b when "01",     
                        prev_next_ms_xor_b when "10",
                        cur_next_ms_xor_b when others;
    --Update Tag
--    tag_input <= reverse_byte(lfsr_xor_mux(TAG_SIZE_BITS-1 downto 0)) xor tag_out when tag_reset = '0' else (others => '0');
    tag_input_a <= lfsr_xor_mux_a(TAG_SIZE_BITS-1 downto 0) xor tag_out_a when tag_reset = '0' else (others => '0');
    tag_input_b <= lfsr_xor_mux_b(TAG_SIZE_BITS-1 downto 0) xor tag_out_b when tag_reset = '0' else (others => '0');

    --Logic for ms_reg_mux and perm
    ms_reg_input_mux_a <= permout_a when perm_sel = '1' else lfsr_xor_mux_a;
    ms_reg_input_mux_b <= permout_b when perm_sel = '1' else lfsr_xor_mux_b;
    perm_input_a <= ms_reg_out_a;
    perm_input_b <= ms_reg_out_b;

    with data_count select
        ms_out_mux2_a <= ms_reg_out_a(CCW-1 downto 0) when "000",
                         ms_reg_out_a((2*CCW)-1 downto CCW) when "001",
                         ms_reg_out_a((3*CCW)-1 downto 2*CCW) when "010",
                         ms_reg_out_a((4*CCW)-1 downto 3*CCW) when "011",
                         ms_reg_out_a((5*CCW)-1 downto 4*CCW) when others;
    with data_count select
        ms_out_mux2_b <= ms_reg_out_b(CCW-1 downto 0) when "000",
                         ms_reg_out_b((2*CCW)-1 downto CCW) when "001",
                         ms_reg_out_b((3*CCW)-1 downto 2*CCW) when "010",
                         ms_reg_out_b((4*CCW)-1 downto 3*CCW) when "011",
                         ms_reg_out_b((5*CCW)-1 downto 4*CCW) when others;

    data_bdo_a <= bdi_or_key_rev_a xor ms_out_mux2_a;
    data_bdo_b <= bdi_or_key_rev_b xor ms_out_mux2_b;
    bdo_a <= reverse_byte(data_out_mux_a);
    bdo_b <= reverse_byte(data_out_mux_b);

    tag_mux_a <= tag_out_a(TAG_SIZE_BITS-1 downto 32) when data_count = "001" else tag_out_a(31 downto 0);
    tag_mux_b <= tag_out_b(TAG_SIZE_BITS-1 downto 32) when data_count = "001" else tag_out_b(31 downto 0);

    data_out_mux_a <= data_bdo_a when bdo_sel ='0' else tag_mux_a;
    data_out_mux_b <= data_bdo_b when bdo_sel ='0' else tag_mux_b;
    
end behavioral;

