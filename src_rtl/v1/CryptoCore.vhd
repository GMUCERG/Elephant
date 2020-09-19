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
    Port (
        clk             : in   STD_LOGIC;
        rst             : in   STD_LOGIC;
        --PreProcessor===============================================
        ----!key----------------------------------------------------
        key             : in   STD_LOGIC_VECTOR (CCSW     -1 downto 0);
        key_valid       : in   STD_LOGIC;
        key_ready       : out  STD_LOGIC;
        ----!Data----------------------------------------------------
        bdi             : in   STD_LOGIC_VECTOR (CCW     -1 downto 0);
        bdi_valid       : in   STD_LOGIC;
        bdi_ready       : out  STD_LOGIC;
        bdi_pad_loc     : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        bdi_valid_bytes : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        bdi_size        : in   STD_LOGIC_VECTOR (3       -1 downto 0);
        bdi_eot         : in   STD_LOGIC;
        bdi_eoi         : in   STD_LOGIC;
        bdi_type        : in   STD_LOGIC_VECTOR (4       -1 downto 0);
        decrypt_in      : in   STD_LOGIC;
        key_update      : in   STD_LOGIC;
        hash_in         : in   std_logic;
        --!Post Processor=========================================
        bdo             : out  STD_LOGIC_VECTOR (CCW      -1 downto 0);
        bdo_valid       : out  STD_LOGIC;
        bdo_ready       : in   STD_LOGIC;
        bdo_type        : out  STD_LOGIC_VECTOR (4       -1 downto 0);
        bdo_valid_bytes : out  STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        end_of_block    : out  STD_LOGIC;
        msg_auth_valid  : out  STD_LOGIC;
        msg_auth_ready  : in   STD_LOGIC;
        msg_auth        : out  STD_LOGIC
    );
end CryptoCore;

architecture behavioral of CryptoCore is
    --internal signals for datapath
    signal bdo_s: std_logic_vector(CCW - 1 downto 0);
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
    signal load_lfsr:std_logic;
    signal perm_en: std_logic;
    
    --Signals for datapath lsfr
    signal datap_lfsr_load: std_logic;
    signal datap_lfsr_en: std_logic;
    
    --Signals for data counter
    signal reset_data_cnt, en_data_cnt: std_logic;
    signal data_cnt_out: std_logic_vector(2 downto 0);
    signal data_cnt_int :integer;--(BLOCK_SIZE-1 downto 0);
    
--    signal reset_perm_cnt: std_logic;
    signal perm_cnt_out: std_logic_vector(PERM_CYCLES_BITS-1 downto 0);
    signal perm_cnt_int :integer;
    
    type ctl_state is (IDLE, STORE_KEY, PERM_KEY, LOAD_KEY,
                       PRE_PERM, PERM, POST_PERM, AD_S, MDATA_S, MDATA_NPUB, TAG_S);
    signal n_ctl_s, ctl_s, n_calling_state, calling_state: ctl_state;
    signal lfsr_loaded, n_lfsr_loaded: std_logic;
    signal done_state, n_done_state: std_logic;
    signal append_one, n_append_one: std_logic;
    signal decrypt_op, n_decrypt_op: std_logic;
    signal n_tag_verified, tag_verified :std_logic;
    
begin
    ELEPHANT_DATAP: entity work.elephant_datapath
        port map(
            key        => key,
            bdi        => bdi,
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

            perm_en => perm_en,            
            load_lfsr  => load_lfsr,
            
            datap_lfsr_load => datap_lfsr_load,
            datap_lfsr_en => datap_lfsr_en,
            
            bdo => bdo_s,
            bdo_sel => bdo_sel,
            saving_bdo => saving_bdo,
            data_count => data_cnt_out,
            perm_count => perm_cnt_out(4 downto 0),
            clk        => clk
        );
    CTR_1: entity work.counter
        generic map(
            num_bits => 3
        )
        port map(
            clk    => clk,
            reset  => reset_data_cnt,
            enable => en_data_cnt,
            q      => data_cnt_out
        );
    data_cnt_int <= to_integer(unsigned(data_cnt_out));
    CTR_2: entity work.counter
        generic map(
            num_bits => PERM_CYCLES_BITS
        )
        port map(
            clk    => clk,
            reset  => load_lfsr,
            enable => perm_en,
            q      => perm_cnt_out
        );
    perm_cnt_int <= to_integer(unsigned(perm_cnt_out));

    
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
    bdo <= bdo_s;
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
    perm_en <= '0';
    datap_lfsr_load <= '0';
    datap_lfsr_en <= '0';
    
    -- Signal for data counter
    en_data_cnt <= '0';
    reset_data_cnt <= '0';
    n_ctl_s <= ctl_s;
    n_calling_state <= calling_state;
    n_lfsr_loaded <= lfsr_loaded;
    n_done_state <= done_state;
    n_append_one <= append_one;
    n_decrypt_op <= decrypt_op;
    n_tag_verified <= tag_verified;

    case ctl_s is
    when IDLE =>
        n_lfsr_loaded <= '0';
        n_tag_verified <= '1';
        tag_reset <= '1';
        tag_en <= '1';
        load_data_en <= '1';
        load_data_sel <= "11";  --clear reg
        reset_data_cnt <= '1';
        n_done_state <= '0';
        if bdi_valid = '1' or key_valid = '1' then
            if key_update = '1' then
                n_ctl_s <= STORE_KEY;
            else
                n_ctl_s <= LOAD_KEY;
            end if;
        end if;
    when STORE_KEY =>
        if data_cnt_int <= BLOCK_SIZE then
            if key_valid = '1' then
                key_ready <= '1';
                en_data_cnt <= '1';
                load_data_en <= '1';
                data_type_sel <= '1'; --select key type
                load_data_sel <= "01";
            else
                en_data_cnt <= '1';
                if data_cnt_int <= KEY_SIZE then
                    load_data_sel <= "00"; --zero pad
                    load_data_en <= '1';
                else
                    ms_en <= '1';
                end if;
            end if;
        else
            n_ctl_s <= PERM_KEY;
            reset_data_cnt <= '1';
            load_data_en <= '1'; -- clear input data reg
            load_data_sel <= "11";
            load_lfsr <= '1';
            perm_en <= '0'; 
        end if;
    when PERM_KEY =>
        if perm_cnt_int < PERM_CYCLES then
            perm_en <= '1';
            ms_en <= '1';
            if perm_cnt_int = PERM_CYCLES-1 then
                --Save the perm key
                key_en <= '1';
                n_ctl_s <= AD_S;
            end if;
        end if;
        --Obtain NPUB
        if data_cnt_int < ELE_NPUB_SIZE then
            if bdi_valid = '1' then
                n_decrypt_op <= decrypt_in;
                bdi_ready <= '1';
                en_data_cnt <= '1';
                load_data_en <= '1';
                load_data_sel <= "01";
            end if;
        --Store npub and then shift it all the way to beginning of the register
        elsif data_cnt_int = ELE_NPUB_SIZE then
            npub_en <= '1';
        end if;
    when LOAD_KEY =>
        --Obtain NPUB
        if data_cnt_int < ELE_NPUB_SIZE then
            if bdi_valid = '1' then
                n_decrypt_op <= decrypt_in;
                bdi_ready <= '1';
                en_data_cnt <= '1';
                load_data_en <= '1';
                load_data_sel <= "01";
            end if;
        --Store npub and then shift it all the way to beginning of the register
        elsif data_cnt_int = ELE_NPUB_SIZE then
            npub_en <= '1';
            n_ctl_s <= AD_S;
        end if;
    when AD_S =>
        n_calling_state <= AD_S;
        if bdi_type = HDR_AD and done_state /= '1'
            and data_cnt_int < BLOCK_SIZE and append_one /= '1' then

            if bdi_valid = '1' then
                if data_cnt_int < BLOCK_SIZE then
                    bdi_ready <= '1';
                    en_data_cnt <= '1';
                    load_data_en <= '1';
                    if bdi_valid_bytes = "1111" then
                        load_data_sel <= "01";
                    else
                        load_data_sel <= "10";
                    end if;
                    --Need to signal to send the tag
                    if bdi_eot = '1' then
                        if (data_cnt_int = BLOCK_SIZE-1 and bdi_valid_bytes = "1111") = False then
                            n_done_state <= '1';
                        end if;
                        if bdi_valid_bytes = "1111" then
                            n_append_one <= '1';
                        end if;
                    end if;
                end if;
            end if;
        else
            en_data_cnt <= '1';
            load_data_en <= '1';
            if (append_one = '1' or done_state = '0') and data_cnt_int /= BLOCK_SIZE then
                load_data_sel <= "10";
                bdi_size_intern <= "00";
                n_append_one <= '0';
                n_done_state <= '1';
            else
                load_data_sel <= "00"; --Zero pad
            end if;
            if data_cnt_int = BLOCK_SIZE then
                n_ctl_s <= PRE_PERM;
                ms_en <= '1';
            end if;
        end if;
        if lfsr_loaded /= '1' then
            datap_lfsr_en <= '1';
            if data_cnt_int < BLOCK_SIZE-1 then
                datap_lfsr_load <= '1';
            elsif data_cnt_int = BLOCK_SIZE then
                n_lfsr_loaded <= '1';
            end if;
        end if;
    when PRE_PERM =>
        --This will handle the logic of XOR with different mask prior to perm
        n_ctl_s <= PERM;
        ms_en <= '1';
        perm_en <= '0';
        load_lfsr <= '1'; --Resets counter and lfsr
        reset_data_cnt <= '1';
        if calling_state = AD_S then
            lfsr_mux_sel <= "10";
        elsif calling_state = MDATA_NPUB then
            lfsr_mux_sel <= "01";
        elsif calling_state = MDATA_S then
            lfsr_mux_sel <= "11";
        end if;
            
    when PERM =>
        if perm_cnt_int < PERM_CYCLES then
            perm_en <= '1';
            ms_en <= '1';
            if perm_cnt_int = PERM_CYCLES-1 then
                n_ctl_s <= POST_PERM;
            end if;
        end if;
        --Loading data
        if calling_state = AD_S and done_state /= '1' then
            null;
        elsif calling_state = AD_S and done_state = '1' then
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
        perm_en <= '0';
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
            en_data_cnt <= '1';
            datap_lfsr_en <= '1';
            if data_cnt_int = 0 then
                datap_lfsr_load <= '1';
            elsif data_cnt_int = 1 then
                n_done_state <= '0'; --Switching to processing messages
            end if;
        else
            n_ctl_s <= PRE_PERM;
            ms_en <= '1';
        end if;
    when MDATA_S =>
        if (bdi_type = HDR_MSG or bdi_type = HDR_CT  or bdi_type = "0000") and 
            done_state /= '1' and data_cnt_int < BLOCK_SIZE and append_one /= '1' then

            if bdi_valid = '1' and bdo_ready = '1' then
                if data_cnt_int < BLOCK_SIZE then
                    bdi_ready <= '1';
                    bdo_valid_bytes <= bdi_valid_bytes;
                    bdo_valid <= '1';
                    en_data_cnt <= '1';
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
            en_data_cnt <= '1';
            if append_one = '1' and data_cnt_int /= BLOCK_SIZE then
                load_data_sel <= "10";
                bdi_size_intern <= "00";
                n_append_one <= '0';
                n_done_state <= '1';
            else
                load_data_sel <= "00"; --Zero pad
            end if;
            load_data_en <= '1';
            if data_cnt_int = BLOCK_SIZE then
                n_calling_state <= MDATA_S;
                n_ctl_s <= PRE_PERM;
                ms_en <= '1';
            end if;
        end if;
    when TAG_S =>
        bdo_sel <= '1';
        if decrypt_op /= '1' then
            bdo_valid <= '1';
            bdo_valid_bytes <= (others => '1');
            bdo_type <= HDR_TAG;
            if bdo_ready = '1' then
                en_data_cnt <= '1';
            end if;
            if data_cnt_int = ELE_TAG_SIZE-1 then
                end_of_block <= '1';
                n_ctl_s <= IDLE;
            end if;
        else
            if bdi_valid = '1' and msg_auth_ready = '1' then
                bdi_ready <= '1';
                en_data_cnt <= '1';
                if data_cnt_int = ELE_TAG_SIZE-1 then
                    n_ctl_s <= IDLE;
                    msg_auth_valid <= '1';
                    if (bdi /= bdo_s) then
                        msg_auth <= '0';
                    else
                        msg_auth <= tag_verified;
                    end if;
                else
                    if bdi /= bdo_s then
                        n_tag_verified <= '0';
                    end if;
                end if;
            end if;
        end if;
    end case;
        
end process;
p_reg: process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
            ctl_s <= IDLE;
            calling_state <= IDLE;
            lfsr_loaded <= '0';
            done_state <= '0';
            decrypt_op <= '0';
            tag_verified <= '0';
            append_one <= '0';
        else
            ctl_s <= n_ctl_s;
            calling_state <= n_calling_state;
            lfsr_loaded <= n_lfsr_loaded;
            done_state <= n_done_state;
            decrypt_op <= n_decrypt_op;
            tag_verified <= n_tag_verified;
            append_one <= n_append_one;
        end if;
    end if;
end process;
end behavioral;
