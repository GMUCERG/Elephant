---------------------------------------------------------------------------------
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
    signal bdi_or_key: std_logic_vector(CCW-1 downto 0);
    
    signal key_en: std_logic;
    signal npub_en: std_logic;
    signal tag_en, tag_rst: std_logic;

    signal ms_en: std_logic;
    
    --Signals for permutation
    signal load_lfsr:std_logic;
    signal ms_sel: std_logic;
    
    --Signals for datapath lsfr
    signal datap_lfsr_load: std_logic;
    signal datap_lfsr_en: std_logic;
    
    --Signals for data counter
    signal n_sipo_cnt, sipo_cnt, n_sipo_cnt_saved, sipo_cnt_saved :integer range 0 to BLOCK_SIZE+1;
    signal n_piso_cnt, piso_cnt :integer range 0 to BLOCK_SIZE+1;
    
--    signal reset_perm_cnt: std_logic;
    signal perm_cnt_int, n_perm_cnt_int: integer range 0 to PERM_CYCLES;
    
    type ctl_state is (IDLE, STORE_KEY, PERM, LOAD_KEY,
                       LOAD_LFSR_AD,
                       AD_FULL, AD_PRE_PERM, AD_POST_PERM,
                       M_PRE_PERM, M_POST_PERM,
                       CT_DELAY, CT_FULL,
                       TAG_S, TAG_WAIT);
    signal n_ctl_s, ctl_s: ctl_state;
    type calling_perm_state is (KEY_PRE, AD_PRE, M_PRE);
    signal n_calling_state, calling_state: calling_perm_state;
    type sipo_state is (IDLE, SIPO_KEY, NPUB, AD, PT, CT, TAG);
    signal n_sipo_s, sipo_s: sipo_state;
    signal done_state, n_done_state: std_logic;
    signal append_one, n_append_one: std_logic;
    signal decrypt_op, n_decrypt_op: std_logic;
    signal n_tag_verified, tag_verified :std_logic;

    signal adcreg_en: std_logic;
    signal adcreg_sel: std_logic_vector(1 downto 0);
    signal adcreg_valid, n_adcreg_valid :std_logic;
    signal ad_valid_bytes, ad_pad_loc :   std_logic_vector (CCWdiv8 -1 downto 0);

    signal sipo: std_logic_vector(STATE_SIZE-1 downto 0);
    signal sipo_en, sipo_rst, sipo_rst_cnt, sipo_save_en: std_logic;
    signal sipo_valid_bytes, n_sipo_valid_bytes,sipo_pad_loc, n_sipo_pad_loc :   std_logic_vector (CCWdiv8 -1 downto 0);
    signal sipo_valid_bytes_saved, n_sipo_valid_bytes_saved :   std_logic_vector (CCWdiv8 -1 downto 0);
    signal piso_en, piso_load: std_logic;
    signal piso_sel: std_logic;
    signal piso_valid_bytes, n_piso_valid_bytes :   std_logic_vector (CCWdiv8 -1 downto 0);
    signal bdi_padd: std_logic_vector(CCW-1 downto 0);
    signal bdi_padd_value: std_logic_vector(7 downto 0);
    signal n_ct_done_state, ct_done_state: std_logic;
    signal bdi_bdo_equal: std_logic;
    signal sel_prev: std_logic;
    signal bdo_tag : std_logic;
    
begin
    bdi_padd <= reverse_byte(padd(bdi, ad_valid_bytes, ad_pad_loc, bdi_padd_value));
p_sipo: process(all)
    begin
        if rising_edge(clk) then
            if sipo_rst = '1' then
                sipo <= (others => '0');
            elsif sipo_en = '1' then
                if sipo_cnt = 0 then
                   sipo(CCW*1-1 downto CCW*0) <= bdi_or_key; 
                elsif sipo_cnt = 1 then
                   sipo(CCW*2-1 downto CCW*1) <= bdi_or_key; 
                elsif sipo_cnt = 2 then
                   sipo(CCW*3-1 downto CCW*2) <= bdi_or_key; 
                elsif sipo_cnt = 3 then
                   sipo(CCW*4-1 downto CCW*3) <= bdi_or_key; 
                elsif sipo_cnt = 4 then
                   sipo(CCW*5-1 downto CCW*4) <= bdi_or_key; 
                end if;
            end if;
        end if;
    end process;
sipo_control: process(all)
begin
    sipo_en <= '0';
    sipo_rst <= '0';
    npub_en <= '0';
    key_ready <= '0';
    bdi_ready <= '0';
    n_sipo_cnt <= sipo_cnt;
    bdi_or_key <= bdi_padd;
    n_done_state <= done_state;
    n_append_one <= append_one;
    n_sipo_valid_bytes <= sipo_valid_bytes;
    n_sipo_valid_bytes_saved <= sipo_valid_bytes_saved;
    n_sipo_pad_loc <= sipo_pad_loc;
    n_sipo_cnt_saved <= sipo_cnt_saved;
    ad_valid_bytes <= bdi_valid_bytes;
    ad_pad_loc <= bdi_pad_loc;
    bdi_padd_value <= x"01";
    case sipo_s is
    when IDLE =>
        n_sipo_cnt <= 0;
        sipo_rst <= '1';
        n_append_one <= '0';
        n_done_state <= '0';
        n_sipo_valid_bytes <= (others => '0');
        n_sipo_valid_bytes_saved <= (others => '0');
        n_sipo_pad_loc <= (others => '0');
    when SIPO_KEY =>
        bdi_or_key <= reverse_byte(key);
        n_sipo_cnt <= sipo_cnt + 1;
        if sipo_cnt < KEY_SIZE then
            if key_valid = '1' then
                key_ready <= '1';
                sipo_en <= '1';
            end if;
        else
            sipo_rst <= '1';
            n_sipo_cnt <= 0;
        end if;
    when NPUB =>
        --Obtain NPUB
        if sipo_cnt < ELE_NPUB_SIZE then
            if bdi_valid = '1' then
                n_sipo_cnt <= sipo_cnt + 1;
                bdi_ready <= '1';
                sipo_en <= '1';
            end if;
        else
            npub_en <= '1';
        end if;
    when AD =>
        if bdi_type /= HDR_AD then
            ad_valid_bytes <= (others => '0');
            ad_pad_loc <= "1000";
        end if;
        if sipo_rst_cnt = '1' then 
            n_sipo_cnt <= 0;
            sipo_rst <= '1';
        elsif bdi_type = HDR_AD and sipo_cnt < BLOCK_SIZE then
            if bdi_valid = '1' then
                bdi_ready <= '1';
                n_sipo_cnt <= sipo_cnt + 1;
                sipo_en <= '1';
                if bdi_eot = '1' then
                    if bdi_valid_bytes = "1111" then
                        n_append_one <= '1';
                    else
                        n_done_state <= '1';
                    end if;
                end if;
            end if;
        elsif append_one = '1' then
            if sipo_cnt < BLOCK_SIZE then
                sipo_en <= '1';
                n_append_one <= '0';
                n_done_state <= '1';
            end if;
        elsif bdi_eot = '1' and bdi_type = "0000" and done_state = '0' then
            bdi_ready <= '1';
            sipo_en <= '1';
            n_done_state <= '1';
        end if;
    when PT =>
        if decrypt_op = '1' then
            bdi_padd_value <= x"01";
        else
            bdi_padd_value <= x"00";
        end if;
        if bdi_type = HDR_TAG then
            ad_valid_bytes <= (others => '0');
            ad_pad_loc <= "1000";
        end if;
        if sipo_rst_cnt = '1' then 
            n_sipo_cnt <= 0;
            sipo_rst <= '1';
            n_sipo_cnt_saved <= sipo_cnt;
            n_sipo_valid_bytes_saved <= sipo_valid_bytes;
            if ((bdi_valid = '0' or bdi_type = HDR_TAG or bdi_type = HDR_NPUB) and
                append_one = '1') then
                n_sipo_pad_loc <= "1000";
                n_sipo_valid_bytes <= (others => '0');
            end if;
        elsif (bdi_type = HDR_PT or bdi_type = HDR_CT) and sipo_cnt < BLOCK_SIZE then
            if bdi_valid = '1' then
                bdi_ready <= '1';
                n_sipo_cnt <= sipo_cnt + 1;
                sipo_en <= '1';
                n_sipo_valid_bytes <= bdi_valid_bytes;
                n_sipo_pad_loc <= bdi_pad_loc;
                if bdi_eot = '1' then
                    if bdi_valid_bytes = "1111" then
                        n_append_one <= '1';
                    else
                        n_done_state <= '1';
                    end if;
                end if;
            end if;
        elsif append_one = '1' then
            if sipo_cnt < BLOCK_SIZE then
                sipo_en <= '1';
                n_append_one <= '0';
                n_done_state <= '1';
            end if;
        elsif bdi_eot = '1' and bdi_type = "0000" and done_state = '0' then
            bdi_ready <= '1';
            sipo_en <= '1';
            n_done_state <= '1';
            n_sipo_valid_bytes <= bdi_valid_bytes;
            n_sipo_pad_loc <= bdi_pad_loc;
        end if;
    when TAG =>
        if bdi_type = HDR_TAG then
            if bdi_valid = '1' and msg_auth_ready = '1' then
                bdi_ready <= '1';
            end if;
        end if;
    when others =>
        null;
    end case;
end process;

    ELEPHANT_DATAP: entity work.elephant_datapath
        port map(
            sipo => sipo,
            sipo_cnt => sipo_cnt_saved,
            sipo_valid_bytes => sipo_valid_bytes_saved,
            sipo_pad_loc => sipo_pad_loc,

            piso_en => piso_en,
            piso_sel => piso_sel,
            

            key_en => key_en,
            npub_en => npub_en,
            tag_rst => tag_rst,
            tag_en => tag_en,
            sipo_save_en => sipo_save_en,

            ms_en => ms_en,
            ms_sel => ms_sel,
            ms_next_current => decrypt_op,
            
            datap_lfsr_load => datap_lfsr_load,
            datap_lfsr_en => datap_lfsr_en,
            
            adcreg_en => adcreg_en,
            adcreg_sel => adcreg_sel,
            sel_prev => sel_prev,
            
            bdo => bdo_s,
            bdo_tag => bdo_tag,

            load_lfsr  => load_lfsr,
            perm_count => perm_cnt_int,
            clk        => clk
        );

    bdo <= reverse_byte(bdo_s);

state_control: process(all)
begin
    
    n_adcreg_valid <= adcreg_valid; 

    key_en <= '0';
    tag_rst <= '0';
    tag_en <= '0';
    ms_en <= '0';
    ms_sel <= '0';
    adcreg_en <= '0';
    adcreg_sel <= "00";

    load_lfsr <= '0';

    datap_lfsr_load <= '0';
    datap_lfsr_en <= '0';
    
    -- Signal for data counter
    n_ctl_s <= ctl_s;
    n_sipo_s <= sipo_s;
    sipo_rst_cnt <= '0';
    n_ct_done_state <= ct_done_state;
    n_decrypt_op <= decrypt_op;
    n_perm_cnt_int <= 0;
    piso_load <= '0';
    sel_prev <= '1';
    bdo_tag <= '0';
    sipo_save_en <= '0';
    n_calling_state <= calling_state;
    

    case ctl_s is
    when IDLE =>
        tag_rst <= '1';
        n_ct_done_state <= '0';
        if bdi_valid = '1' or key_valid = '1' then
            if key_update = '1' then
                n_ctl_s <= STORE_KEY;
                n_sipo_s <= SIPO_KEY;
            else
                n_ctl_s <= LOAD_KEY;
                n_sipo_s <= NPUB;
            end if;
        end if;
    when STORE_KEY =>
        if sipo_cnt = KEY_SIZE then
            n_ctl_s <= PERM;
            n_calling_state <= KEY_PRE;
            n_sipo_s <= NPUB;
            adcreg_en <= '1';
            adcreg_sel <= "01";
        end if;
    when PERM =>
        adcreg_en <= '1';
        adcreg_sel <= "00";
        ms_sel <= '1';
        ms_en <= '1';
        if perm_cnt_int = PERM_CYCLES-1 then
            --Save the perm key
             if calling_state = KEY_PRE then
                 key_en <= '1';
                 n_ctl_s <= LOAD_LFSR_AD;
             elsif calling_state = AD_PRE then
                 n_ctl_s <= AD_POST_PERM;
             else
                if decrypt_op = '0' then
                    sipo_save_en <= '1';
                    sipo_rst_cnt <= '1';
                end if;
                n_ctl_s <= M_POST_PERM;
             end if;
        else
            n_perm_cnt_int <= perm_cnt_int + 1;
        end if;
        if sipo_cnt = ELE_NPUB_SIZE and calling_state = KEY_PRE then 
            n_sipo_s <= AD;
        end if;

    when LOAD_LFSR_AD =>
        n_decrypt_op <= decrypt_in;
        if perm_cnt_int = 0 then
            datap_lfsr_load <= '1';
        elsif perm_cnt_int = 2 then
            n_ctl_s <= AD_FULL;
        end if;
        n_perm_cnt_int <= perm_cnt_int + 1;
        datap_lfsr_en <= '1';
    when LOAD_KEY =>
        if sipo_cnt = ELE_NPUB_SIZE then
            n_ctl_s <= LOAD_LFSR_AD;
            n_sipo_s <= AD;
        end if;
    when AD_FULL =>
        if sipo_cnt >= BLOCK_SIZE-1 or done_state = '1' then
            adcreg_en <= '1';
            adcreg_sel <= "01";
            sipo_rst_cnt <= '1';
            n_adcreg_valid <= done_state;
            n_ctl_s <= AD_PRE_PERM;
        end if;
    when AD_PRE_PERM =>
        adcreg_en <= '1';
        adcreg_sel <= "11";
        --reset perm
        load_lfsr <= '1';
        n_ctl_s <= PERM;
        n_calling_state <= AD_PRE;
    when AD_POST_PERM =>
        adcreg_sel <= "11";
        adcreg_en <= '1';
        tag_en <= '1';
        datap_lfsr_en <= '1';
        if adcreg_valid = '1' then
            if append_one = '1' then
                n_ctl_s <= AD_FULL;
            else
                n_sipo_s <= IDLE;
                if decrypt_op = '1' then
                    n_ctl_s <= CT_DELAY;
                else
                    n_ctl_s <= M_PRE_PERM;
                end if;
                datap_lfsr_load <= '1';
                datap_lfsr_en <= '1';
                n_adcreg_valid <= '0';
            end if;
        else
            n_ctl_s <= AD_FULL;
        end if;
    when CT_DELAY =>
        n_adcreg_valid <= '1';
        n_sipo_s <= PT;
        datap_lfsr_en <= '1';
        n_ctl_s <= CT_FULL;
    when CT_FULL =>
        if sipo_cnt >= BLOCK_SIZE or done_state = '1' then
            adcreg_en <= '1';
            adcreg_sel <= "01";
            n_adcreg_valid <= '1';
            n_ctl_s <= M_PRE_PERM;
        end if;
    when M_PRE_PERM =>
        n_sipo_s <= PT;
        ms_en <= '1';
        ms_sel <= '0';
        adcreg_en <= '1';
        adcreg_sel <= "11";
        sel_prev <= '0';
        --reset perm
        load_lfsr <= '1';
        n_ctl_s <= PERM;
        n_calling_state <= M_PRE;
        if decrypt_op /= '0' then
            sipo_save_en <= '1';
            sipo_rst_cnt <= '1';
        end if;
        if decrypt_op /= '0' and done_state = '1' and decrypt_op = '1' then
            n_ct_done_state <= '1';
        end if;
    when M_POST_PERM =>
        adcreg_sel <= "10";
        adcreg_en <= '1';
        sel_prev <= '0';
        n_adcreg_valid <= '1';
        piso_load <= '1';
        datap_lfsr_en <= '1';
        if ct_done_state = '0' then
            if decrypt_op = '0' then
                n_ctl_s <= M_PRE_PERM;
                if done_state = '1' then
                    n_ct_done_state <= '1';
                end if;
            else
                n_ctl_s <= CT_FULL;
            end if;
        else
            n_ctl_s <= TAG_S;
        end if;
        if adcreg_valid = '1' then
            tag_en <= '1';
        end if;

    when TAG_S =>
        if piso_cnt = 0 then
            piso_load <= '1';
            n_ctl_s <= TAG_WAIT;
            n_sipo_s <= TAG;
        end if;
    when TAG_WAIT =>
        bdo_tag <= '1';
        if decrypt_op /= '1' then
            if bdo_ready = '1' then
                tag_rst <= '1';
                if piso_cnt = 1 then
                    n_ctl_s <= IDLE;
                    n_sipo_s <= IDLE;
                end if;
            end if;
        else
            if bdi_valid = '1' and msg_auth_ready = '1' then 
                tag_rst <= '1';
                if piso_cnt = 1 then
                    n_ctl_s <= IDLE;
                    n_sipo_s <= IDLE;
                end if;
            end if;
        end if;
    end case;
        
end process;


p_piso: process(all)
    begin
        end_of_block <= '0';
        bdo_type <=(others => '0');
        bdo_valid <= '0';
        bdo_valid_bytes <= (others => '0');
        n_piso_cnt <= piso_cnt;
        piso_en <= '0';
        n_piso_valid_bytes <= piso_valid_bytes;
        bdi_bdo_equal <= '1';
        msg_auth_valid <= '0';
        msg_auth <= '0';
        n_tag_verified <= tag_verified;
        piso_sel <= '0';
        if piso_load = '1' then
            piso_en <= '1';
            n_piso_valid_bytes <= sipo_valid_bytes_saved;
            n_tag_verified <= '1';
            if ctl_s = TAG_S then
                n_piso_cnt <= 2;
            else
                piso_sel <= '1';
                n_piso_cnt <= sipo_cnt_saved;
            end if;
        elsif piso_cnt > 0 then
            piso_sel <= '0';
            if ctl_s = TAG_WAIT or ctl_s = IDLE then
                if decrypt_op /= '1' then
                    if bdo_ready = '1' then
                        piso_en <= '1';
                        n_piso_cnt <= piso_cnt - 1;
                        bdo_valid <= '1';
                        if ctl_s = TAG_WAIT or ctl_s = IDLE then 
                            bdo_valid_bytes <= (others => '1');
                            bdo_type <= HDR_TAG; 
                            if piso_cnt-1 = 0 then
                                end_of_block <= '1';
                            end if;
                        end if;
                    end if;
                else
                    if bdi_valid = '1' and msg_auth_ready = '1' then
                        piso_en <= '1';
                        n_piso_cnt <= piso_cnt - 1;
                        if reverse_byte(bdi) /= bdo_s then
                            bdi_bdo_equal <= '0';
                        end if;
                        n_tag_verified <= tag_verified and bdi_bdo_equal;
                        if piso_cnt - 1 = 0 then
                            msg_auth_valid <= '1';
                            msg_auth <= n_tag_verified;
                        end if;
                    end if;
                end if;
            else
                if bdo_ready = '1' then
                    piso_en <= '1';
                    n_piso_cnt <= piso_cnt - 1;
                    bdo_valid <= '1';
                    if decrypt_op = '1' then
                        bdo_type <= HDR_CT;
                    else
                        bdo_type <= HDR_PT;
                    end if;
                    if piso_cnt-1 = 0  then
                        bdo_valid_bytes <= piso_valid_bytes;
                    else
                        bdo_valid_bytes <= (others => '1');
                    end if;
                end if;
            end if;
        end if;
    end process;

p_reg: process(clk)
begin
    if rising_edge(clk) then
        perm_cnt_int <= n_perm_cnt_int;
        sipo_cnt <= n_sipo_cnt;
        sipo_cnt_saved <= n_sipo_cnt_saved;
        piso_cnt <= n_piso_cnt;
        calling_state <= n_calling_state;
        sipo_valid_bytes <= n_sipo_valid_bytes;
        sipo_valid_bytes_saved <= n_sipo_valid_bytes_saved;
        piso_valid_bytes <= n_piso_valid_bytes;
        sipo_pad_loc <= n_sipo_pad_loc;
        done_state <= n_done_state;
        decrypt_op <= n_decrypt_op;
        tag_verified <= n_tag_verified;
        append_one <= n_append_one;
        adcreg_valid <= n_adcreg_valid;
        ct_done_state <= n_ct_done_state;
        if rst = '1' then
            ctl_s <= IDLE;
            sipo_s <= IDLE;
        else
            ctl_s <= n_ctl_s;
            sipo_s <= n_sipo_s;
        end if;
    end if;
end process;
end behavioral;
