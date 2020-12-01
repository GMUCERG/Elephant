--------------------------------------------------------------------------------
--! @file       CryptoCore.vhd
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use work.NIST_LWAPI_pkg.all;
use work.Design_pkg.all;
use work.elephant_constants.all;

entity CryptoCore is
    port (
        clk                 : in   std_logic;
        rst                 : in   std_logic;
        --PreProcessor===============================================
        ----!key----------------------------------------------------
        key_a               : in   std_logic_vector (CCSW    -1 downto 0);
        key_b               : in   std_logic_vector (CCSW    -1 downto 0);
        key_c               : in   std_logic_vector (CCSW    -1 downto 0);
        key_valid           : in   std_logic;
        key_update          : in   std_logic;
        key_ready           : out  std_logic;
        ----!Data----------------------------------------------------
        bdi_a               : in   std_logic_vector (CCW     -1 downto 0);
        bdi_b               : in   std_logic_vector (CCW     -1 downto 0);
        bdi_c               : in   std_logic_vector (CCW     -1 downto 0);
        bdi_valid           : in   std_logic;
        bdi_ready           : out  std_logic;
        bdi_pad_loc         : in   std_logic_vector (CCWdiv8 -1 downto 0);
        bdi_valid_bytes     : in   std_logic_vector (CCWdiv8 -1 downto 0);
        bdi_size            : in   std_logic_vector (3       -1 downto 0);
        bdi_eot             : in   std_logic;
        bdi_eoi             : in   std_logic;
        bdi_type            : in   std_logic_vector (4       -1 downto 0);
        decrypt_in          : in   std_logic;
        hash_in             : in   std_logic;
        --!Post Processor=========================================
        bdo_a               : out  std_logic_vector (CCW     -1 downto 0);
        bdo_b               : out  std_logic_vector (CCW     -1 downto 0);
        bdo_c               : out  std_logic_vector (CCW     -1 downto 0);
        bdo_valid           : out  std_logic;
        bdo_ready           : in   std_logic;
        bdo_type            : out  std_logic_vector (4       -1 downto 0);
        bdo_valid_bytes     : out  std_logic_vector (CCWdiv8 -1 downto 0);
        end_of_block        : out  std_logic;
        msg_auth_valid      : out  std_logic;
        msg_auth_ready      : in   std_logic;
        msg_auth            : out  std_logic;
        --rdi data to seed PRNG
        rdi_valid           : in   std_logic;
        rdi_ready           : out  std_logic; 
        rdi_data            : in   std_logic_vector(RW-1 downto 0)
    );
end CryptoCore;

architecture behavioral of CryptoCore is
    --internal signals for datapath
    signal bdo_sa, bdo_sb, bdo_sc: std_logic_vector(CCW - 1 downto 0);
    signal bdo_sel: std_logic;
    signal saving_bdo: std_logic;
    signal bdi_size_intern: std_logic_vector(1 downto 0);
    signal data_type_sel: std_logic;
    
    signal load_data_en: std_logic;
    signal load_data_sel: std_logic_vector(1 downto 0);
    signal lfsr_mux_sel: std_logic_vector(1 downto 0);
    signal key_en: std_logic;
    signal npub_en: std_logic;
    signal tag_en: std_logic;
    signal tag_reset: std_logic;

    signal ms_en: std_logic;
    
    --Signals for permutation
    signal load_lfsr, en_lfsr:std_logic;
    signal perm_sel: std_logic;
    
    --Signals for datapath lsfr
    signal datap_lfsr_load: std_logic;
    signal datap_lfsr_en: std_logic;
    
    --Signals for data counter
    signal n_data_cnt_int, data_cnt_int : unsigned(4 downto 0);
    
--    signal reset_perm_cnt: std_logic;
    signal perm_cnt_int, n_perm_cnt_int: integer range 0 to PERM_CYCLES;
    
    type ctl_state is (RST_S, LOAD_SEED, START_PRNG, WAIT_PRNG,
                       IDLE, STORE_KEY, PERM_KEY, LOAD_KEY,
                       PRE_PERM, PERM, POST_PERM, AD_S, MDATA_S,
                       MDATA_NPUB, TAG_S);
    signal n_ctl_s, ctl_s, n_calling_state, calling_state: ctl_state;
    signal lfsr_loaded, n_lfsr_loaded: std_logic;
    signal done_state, n_done_state: std_logic;
    signal append_one, n_append_one: std_logic;
    signal decrypt_op, n_decrypt_op: std_logic;
    signal n_tag_verified, tag_verified :std_logic;

    signal en_seed_sipo : std_logic;
    signal reseed, prng_rdi_valid: std_logic;
    signal prng_rdi_data : std_logic_vector(NUM_TRIVIUM_UNITS*64-1 downto 0);
    signal seed : std_logic_vector(NUM_TRIVIUM_UNITS*128-1 downto 0);
    signal bdi_bc, key_bc : std_logic_vector(CCW-1 downto 0);

    --signal tag_comp_a, tag_comp_b, tag_comp_t : std_logic_vector(CCW-1 downto 0);
    signal tag_mux_sel : std_logic;

begin
    key_bc <= key_b xor key_c;
    bdi_bc <= bdi_b xor bdi_c;

    -- bdo shared cannot be sent back to back to the output since the two
    -- shares go through the same output PISO. This leaks the hamming distance
    -- of bdo
    bdo_a <= bdo_sa;
    bdo_b <= (others => '0');
    bdo_c <= bdo_sb;

    --tag_comp_a <= bdo_sa when tag_mux_sel = '1' else (others => '0');
    --tag_comp_b <= bdo_sb when tag_mux_sel = '1' else (others => '0');
    --tag_comp_t <= tag_comp_a xor tag_comp_b xor bdi_a xor bdi_bc;

    ELEPHANT_DATAP: entity work.elephant_datapath_protected
        port map(
            key_a        => key_a,
            key_b        => key_bc,
            bdi_a        => bdi_a,
            bdi_b        => bdi_bc,
            random       => prng_rdi_data(RANDOM_BITS_PER_SBOX*NUMBER_SBOXS - 1 downto 0),
            bdi_size => bdi_size_intern,
            data_type_sel => data_type_sel,
            
            load_data_en  => load_data_en,
            load_data_sel => load_data_sel,
            lfsr_mux_sel => lfsr_mux_sel,
            key_en => key_en,
            npub_en => npub_en,
            tag_en => tag_en,
            tag_reset => tag_reset,
            ms_en => ms_en,

            perm_sel => perm_sel,
            load_lfsr  => load_lfsr,
            en_lfsr    => en_lfsr,
            
            datap_lfsr_load => datap_lfsr_load,
            datap_lfsr_en => datap_lfsr_en,
            
            bdo_a => bdo_sa,
            bdo_b => bdo_sb,
            bdo_sel => bdo_sel,
            saving_bdo => saving_bdo,
            data_count => std_logic_vector(data_cnt_int(2 downto 0)),
            clk        => clk
        );
    trivium_inst : entity work.prng_trivium_enhanced(structural)
    generic map (N => NUM_TRIVIUM_UNITS)
    port map(
        clk => clk,
        rst => rst,
        en_prng => '1',
        seed => seed,
        reseed => reseed,
        reseed_ack => open,
        rdi_data => prng_rdi_data,
        rdi_ready => '1',
        rdi_valid => prng_rdi_valid
    );

    seed_sipo : process(clk)
    begin
        if rising_edge(clk) then
            if en_seed_sipo = '1' then
                seed <= seed(SEED_SIZE - RW -1 downto 0) & rdi_data;
            end if;
        end if;
    end process;

state_control: process(all)
begin
    bdo_valid <= '0';
    bdo_valid_bytes <= bdi_valid_bytes;
    bdo_type <=(others => '0');
    bdo_sel <= '0';
    saving_bdo <= '0';
    msg_auth <= '0';
    msg_auth_valid <= '0';
    end_of_block <= '0';
    
    key_ready <= '0';
    bdi_ready <= '0';
    bdi_size_intern <= bdi_size(1 downto 0);
    data_type_sel <= '0';

    load_data_en <= '0';
    load_data_sel <= "00";
    lfsr_mux_sel <= "00";
    key_en <= '0';
    npub_en <= '0';
    tag_reset <= '0';
    tag_en <= '0';
    ms_en <= '0';    

    load_lfsr <= '0';
    en_lfsr <= '0';
    perm_sel <= '0';
    datap_lfsr_load <= '0';
    datap_lfsr_en <= '0';
    
    -- Signal for data counter
    n_ctl_s <= ctl_s;
    n_calling_state <= calling_state;
    n_lfsr_loaded <= lfsr_loaded;
    n_done_state <= done_state;
    n_append_one <= append_one;
    n_decrypt_op <= decrypt_op;
    n_tag_verified <= tag_verified;
    n_perm_cnt_int <= 0;
    n_data_cnt_int <= data_cnt_int;

    reseed <= '0';
    rdi_ready <= '0';
    en_seed_sipo <= '0';

    tag_mux_sel <= '0';

    case ctl_s is
    when RST_S =>
        n_ctl_s <= LOAD_SEED;
    when LOAD_SEED =>
        rdi_ready <= '1';
        if rdi_valid = '1' then
            en_seed_sipo <= '1';
            if data_cnt_int = to_unsigned((SEED_SIZE / RW) -1, 5) then
                n_ctl_s <= START_PRNG;
            else
                n_ctl_s <= LOAD_SEED;
            end if;
            n_data_cnt_int <= data_cnt_int + 1;
        else
            n_ctl_s <= START_PRNG;
        end if;
    when START_PRNG =>
        reseed <= '1';
        n_ctl_s <= WAIT_PRNG;
    when WAIT_PRNG =>
        if prng_rdi_valid = '1' then
            n_ctl_s <= IDLE;
        else
            n_ctl_s <= WAIT_PRNG;
        end if;
    when IDLE =>
        n_lfsr_loaded <= '0';
        n_tag_verified <= '1';
        tag_reset <= '1';
        tag_en <= '1';
        n_data_cnt_int <= "00000";
        n_done_state <= '0';
        if bdi_valid = '1' or key_valid = '1' then
            if key_update = '1' then
                n_ctl_s <= STORE_KEY;
            else
                n_ctl_s <= LOAD_KEY;
            end if;
        end if;
    when STORE_KEY =>
        if data_cnt_int <= to_unsigned(BLOCK_SIZE,5) then
            if data_cnt_int < to_unsigned(KEY_SIZE,5) then
                if key_valid = '1' then
                    n_data_cnt_int <= data_cnt_int + 1;
                    key_ready <= '1';
                    load_data_en <= '1';
                    data_type_sel <= '1'; --select key type
                    load_data_sel <= "01";
                end if;
            else
                n_data_cnt_int <= data_cnt_int + 1;
                if data_cnt_int <= to_unsigned(KEY_SIZE,5) then
                    load_data_sel <= "00"; --zero pad
                    load_data_en <= '1';
                else
                    ms_en <= '1';
                end if;
            end if;
        else
            n_ctl_s <= PERM_KEY;
            n_data_cnt_int <= "00000";
            load_data_en <= '1'; -- clear input data reg
            load_data_sel <= "11";
            load_lfsr <= '1';
        end if;
    when PERM_KEY =>
        if perm_cnt_int < (2*PERM_CYCLES) then
            perm_sel <= '1';
            n_perm_cnt_int <= perm_cnt_int + 1;
            if perm_cnt_int mod 2 = 1 then
                ms_en <= '1';
                en_lfsr <= '1';
            end if;
            if perm_cnt_int = (2*PERM_CYCLES)-1 then
                --Save the perm key
                key_en <= '1';
                n_ctl_s <= AD_S;
            end if;
        end if;
        --Obtain NPUB
        if data_cnt_int < to_unsigned(ELE_NPUB_SIZE,5) then
            if bdi_valid = '1' then
                n_decrypt_op <= decrypt_in;
                bdi_ready <= '1';
                n_data_cnt_int <= data_cnt_int + 1;
                load_data_en <= '1';
                load_data_sel <= "01";
            end if;
        --Store npub and then shift it all the way to beginning of the register
        elsif data_cnt_int = to_unsigned(ELE_NPUB_SIZE,5) then
            npub_en <= '1';
        end if;
    when LOAD_KEY =>
        --Obtain NPUB
        if data_cnt_int < to_unsigned(ELE_NPUB_SIZE,5) then
            if bdi_valid = '1' then
                n_data_cnt_int <= data_cnt_int + 1;
                n_decrypt_op <= decrypt_in;
                bdi_ready <= '1';
                load_data_en <= '1';
                load_data_sel <= "01";
            end if;
        --Store npub and then shift it all the way to beginning of the register
        elsif data_cnt_int = to_unsigned(ELE_NPUB_SIZE,5) then
            npub_en <= '1';
            n_ctl_s <= AD_S;
        end if;
    when AD_S =>
        n_calling_state <= AD_S;
        if bdi_type = HDR_AD and done_state /= '1'
            and data_cnt_int < to_unsigned(BLOCK_SIZE,5) and append_one /= '1' then

            if bdi_valid = '1' then
                if data_cnt_int < to_unsigned(BLOCK_SIZE,5) then
                    bdi_ready <= '1';
                    n_data_cnt_int <= data_cnt_int + 1;
                    load_data_en <= '1';
                    if bdi_valid_bytes = "1111" then
                        load_data_sel <= "01";
                    else
                        load_data_sel <= "10";
                    end if;
                    --Need to signal to send the tag
                    if bdi_eot = '1' then
                        if (data_cnt_int = to_unsigned(BLOCK_SIZE-1,5) and bdi_valid_bytes = "1111") = False then
                            n_done_state <= '1';
                        end if;
                        if bdi_valid_bytes = "1111" then
                            n_append_one <= '1';
                        end if;
                    end if;
                end if;
                if lfsr_loaded /= '1' then
                    datap_lfsr_en <= '1';
                    if data_cnt_int < to_unsigned(BLOCK_SIZE-1,5) then
                        datap_lfsr_load <= '1';
                    elsif data_cnt_int = to_unsigned(BLOCK_SIZE,5) then
                        n_lfsr_loaded <= '1';
                    end if;
                end if;
            end if;
        else
            n_data_cnt_int <= data_cnt_int + 1;
            load_data_en <= '1';
            if (append_one = '1' or done_state = '0') and data_cnt_int /= to_unsigned(BLOCK_SIZE,5) then
                load_data_sel <= "10";
                bdi_size_intern <= "00";
                n_append_one <= '0';
                n_done_state <= '1';
            else
                load_data_sel <= "00"; --Zero pad
            end if;
            if data_cnt_int = to_unsigned(BLOCK_SIZE,5) then
                n_ctl_s <= PRE_PERM;
                ms_en <= '1';
            end if;
            if lfsr_loaded /= '1' then
                datap_lfsr_en <= '1';
                if data_cnt_int < to_unsigned(BLOCK_SIZE-1,5) then
                    datap_lfsr_load <= '1';
                elsif data_cnt_int = to_unsigned(BLOCK_SIZE,5) then
                    n_lfsr_loaded <= '1';
                end if;
            end if;
        end if;

    when PRE_PERM =>
        --This will handle the logic of XOR with different mask prior to perm
        n_ctl_s <= PERM;
        ms_en <= '1';
        load_lfsr <= '1'; --Resets counter and lfsr
        n_data_cnt_int <= "00000";
        if calling_state = AD_S then
            lfsr_mux_sel <= "10";
        elsif calling_state = MDATA_NPUB then
            lfsr_mux_sel <= "01";
        elsif calling_state = MDATA_S then
            lfsr_mux_sel <= "11";
        end if;
            
    when PERM =>
        if perm_cnt_int < (2*PERM_CYCLES) then
            perm_sel <= '1';
            n_perm_cnt_int <= perm_cnt_int + 1;
            if perm_cnt_int mod 2 = 1 then
                ms_en <= '1';
                en_lfsr <= '1';
            end if;
            if perm_cnt_int = (2*PERM_CYCLES)-1 then
                n_ctl_s <= POST_PERM;
            end if;
        end if;
        --Loading data
        if calling_state = AD_S and done_state = '1' then
            --Okay need to load npub
            load_data_en <= '1';
            load_data_sel <= "11";
        end if;
    when POST_PERM =>
        --Determine if it should move to the next state
        if done_state = '0' then
            if calling_state = AD_S and append_one = '1' then
                n_ctl_s <= calling_state;
            elsif bdi_type = HDR_MSG or bdi_type = HDR_CT then
                if calling_state = MDATA_S then
                    n_ctl_s <= MDATA_NPUB;
                    load_data_en <= '1';
                    load_data_sel <= "11";
                else
                    n_ctl_s <= MDATA_S;
                end if;
            elsif calling_state = MDATA_NPUB and (bdi_type = "0000" or bdi_type = HDR_TAG)  then
                -- Handles case where PT and CT are empty
                n_ctl_s <= MDATA_S;
                n_done_state <= '1';
                n_append_one <= '1';
            else
                n_ctl_s <= calling_state;
            end if;
        else
            if calling_state = AD_S then
                if append_one = '1' then
                    n_ctl_s <= calling_state;
                else
                    n_ctl_s <= MDATA_NPUB;
                end if;
            elsif calling_state = MDATA_S then
                if append_one = '1' then
                    n_ctl_s <= calling_state;
                else
                    n_ctl_s <= TAG_S;
                end if;
            end if;
        end if;
        ms_en <= '1';
        load_lfsr <= '1'; --Resets counter and lfsr
        if calling_state = AD_S or calling_state = MDATA_S then
            datap_lfsr_en <= '1';
            tag_en <= '1';
        end if;
        if calling_state = AD_S then
            lfsr_mux_sel <= "10";
        elsif calling_state = MDATA_NPUB then
            lfsr_mux_sel <= "01";
        elsif calling_state = MDATA_S then
            lfsr_mux_sel <= "11";
        end if;

    when MDATA_NPUB =>
        --Loading padded npub into ms
        n_calling_state <= MDATA_NPUB;
        ms_en <= '1';
        if done_state = '1' then
            n_data_cnt_int <= data_cnt_int + 1;
            datap_lfsr_en <= '1';
            if data_cnt_int = to_unsigned(0,5) then
                datap_lfsr_load <= '1';
            elsif data_cnt_int = to_unsigned(1,5) then
                n_done_state <= '0'; --Switching to processing messages
            end if;
        else
            n_ctl_s <= PRE_PERM;
            ms_en <= '1';
        end if;
    when MDATA_S =>
        if (bdi_type = HDR_MSG or bdi_type = HDR_CT  or bdi_type = "0000") and 
            done_state /= '1' and data_cnt_int < to_unsigned(BLOCK_SIZE,5) and append_one /= '1' then

            if bdi_valid = '1' and bdo_ready = '1' then
                if data_cnt_int < to_unsigned(BLOCK_SIZE,5) then
                    bdi_ready <= '1';
                    bdo_valid_bytes <= bdi_valid_bytes;
                    bdo_valid <= '1';
                    n_data_cnt_int <= data_cnt_int + 1;
                    load_data_en <= '1';
                    if bdi_valid_bytes = "1111" then
                        load_data_sel <= "01";
                    else
                        load_data_sel <= "10";
                    end if;
                    if bdi_type = HDR_MSG then
                        bdo_type <= HDR_CT;
                        saving_bdo <= '1';
                    else
                        bdo_type <= HDR_MSG;
                    end if;
                    --Need to signal to send the tag
                    if bdi_eot = '1' then
                        n_done_state <= '1';
                        if bdi_valid_bytes = "1111" then
                            n_append_one <= '1';
                        end if;
                    end if;
                end if;
            end if;
        else
            n_data_cnt_int <= data_cnt_int + 1;
            if append_one = '1' and data_cnt_int /= to_unsigned(BLOCK_SIZE,5) then
                load_data_sel <= "10";
                bdi_size_intern <= "00";
                n_append_one <= '0';
                n_done_state <= '1';
            else
                load_data_sel <= "00"; --Zero pad
            end if;
            load_data_en <= '1';
            if data_cnt_int = to_unsigned(BLOCK_SIZE,5) then
                n_calling_state <= MDATA_S;
                n_ctl_s <= PRE_PERM;
                ms_en <= '1';
            end if;
        end if;
    when TAG_S =>
        bdo_sel <= '1';
        if decrypt_op /= '1' then
            bdo_valid_bytes <= (others => '1');
            bdo_type <= HDR_TAG;
            if bdo_ready = '1' then
                bdo_valid <= '1';
                n_data_cnt_int <= data_cnt_int + 1;
                if data_cnt_int = to_unsigned(ELE_TAG_SIZE-1,5) then
                    end_of_block <= '1';
                    n_ctl_s <= IDLE;
                end if;
            end if;
        else
            if bdi_valid = '1' and msg_auth_ready = '1' then
                tag_mux_sel <= '1';
                bdi_ready <= '1';
                n_data_cnt_int <= data_cnt_int + 1;
                if data_cnt_int = to_unsigned(ELE_TAG_SIZE-1,5) then
                    n_ctl_s <= IDLE;
                    msg_auth_valid <= '1';
                    --if (tag_comp_t /= x"00000000") then
                    --    msg_auth <= '0';
                    --else
                        msg_auth <= tag_verified;
                    --end if;
                else
                    --if tag_comp_t /= x"00000000" then
                    --    n_tag_verified <= '0';
                    n_tag_verified <= '1';
                    --end if;
                end if;
            end if;
        end if;
    end case;
        
end process;
p_reg: process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
            ctl_s <= RST_S;
            calling_state <= IDLE;
            lfsr_loaded <= '0';
            done_state <= '0';
            decrypt_op <= '0';
            tag_verified <= '0';
            append_one <= '0';
            perm_cnt_int <= 0;
            data_cnt_int <= "00000";
        else
            ctl_s <= n_ctl_s;
            calling_state <= n_calling_state;
            lfsr_loaded <= n_lfsr_loaded;
            done_state <= n_done_state;
            decrypt_op <= n_decrypt_op;
            tag_verified <= n_tag_verified;
            append_one <= n_append_one;
            perm_cnt_int <= n_perm_cnt_int;
            data_cnt_int <= n_data_cnt_int;
        end if;
    end if;
end process;
end behavioral;
