--------------------------------------------------------------------------------
--! @file       PreProcessor.vhd
--! @brief      Pre-processor for NIST LWC API
--!
--! @author     Robert Primas <rprimas@gmail.com>
--! @copyright  Copyright (c) 2020 IAIK, Graz University of Technology, AUSTRIA
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.          
--!             The license and distribution terms for this file may be         
--!             found in the file LICENSE in this distribution or at            
--!             http://www.gnu.org/licenses/gpl-3.0.txt                         
--! @note       This is publicly available encryption source code that falls    
--!             under the License Exception TSU (Technology and software-       
--!             unrestricted)                                                  
----------------------------------------------------------------------------------------------------------------------------
--! Description
--!
--! 
--!
--!
--!
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.math_real."ceil";
USE IEEE.math_real."log2";
USE work.NIST_LWAPI_pkg.ALL;
USE work.design_pkg.ALL;
ENTITY PreProcessor IS
    PORT (
        clk : IN std_logic;
        rst : IN std_logic;
        --! Public Data input (pdi) ========================================
        pdi_data : IN STD_LOGIC_VECTOR(W - 1 DOWNTO 0);
        pdi_valid : IN std_logic;
        pdi_ready : OUT std_logic;
        --! Secret Data input (sdi) ========================================
        sdi_data : IN STD_LOGIC_VECTOR(SW - 1 DOWNTO 0);
        sdi_valid : IN std_logic;
        sdi_ready : OUT std_logic;

        --! Crypto Core ====================================================
        key : OUT std_logic_vector(CCSW - 1 DOWNTO 0);
        key_valid : OUT std_logic;
        key_ready : IN std_logic;
        bdi : OUT std_logic_vector(CCW - 1 DOWNTO 0);
        bdi_valid : OUT std_logic;
        bdi_ready : IN std_logic;
        bdi_pad_loc : OUT std_logic_vector(CCWdiv8 - 1 DOWNTO 0);
        bdi_valid_bytes : OUT std_logic_vector(CCWdiv8 - 1 DOWNTO 0);
        bdi_size : OUT std_logic_vector(2 DOWNTO 0);
        bdi_eot : OUT std_logic;
        bdi_eoi : OUT std_logic;
        bdi_type : OUT std_logic_vector(3 DOWNTO 0);
        decrypt : OUT std_logic;
        hash : OUT std_logic;
        key_update : OUT std_logic;
        ---! Header FIFO ===================================================
        cmd : OUT std_logic_vector(W - 1 DOWNTO 0);
        cmd_valid : OUT std_logic;
        cmd_ready : IN std_logic
    );
END ENTITY PreProcessor;

ARCHITECTURE PreProcessor OF PreProcessor IS

    --! Segment counter
    SIGNAL len_SegLenCnt : std_logic;
    SIGNAL en_SegLenCnt : std_logic;
    SIGNAL last_flit_of_segment : std_logic;
    SIGNAL dout_SegLenCnt : std_logic_vector(15 DOWNTO 0);
    SIGNAL load_SegLenCnt : std_logic_vector(15 DOWNTO 0);

    --! Multiplexer
    SIGNAL sel_sdi_length : BOOLEAN;

    --! Flags
    SIGNAL bdi_valid_bytes_p : std_logic_vector(3 DOWNTO 0);
    SIGNAL bdi_pad_loc_p : std_logic_vector(3 DOWNTO 0);

    --!for simulation only
    SIGNAL received_wrong_header : BOOLEAN;

    --Registers
    SIGNAL eoi_flag, nx_eoi_flag : std_logic;
    SIGNAL eot_flag, nx_eot_flag : std_logic;
    SIGNAL hash_internal, nx_hash_internal : std_logic;
    SIGNAL decrypt_internal, nx_decrypt_internal : std_logic;
    --Controller
    SIGNAL bdi_eoi_internal : std_logic;
    SIGNAL bdi_eot_internal : std_logic;
    CONSTANT zero_data : std_logic_vector(W - 1 DOWNTO 0) := (OTHERS => '0');
    ---STATES
    TYPE t_state32 IS (S_INT_MODE, S_INT_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_NPUB, S_LD_NPUB,
        S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG, S_LD_TAG,
        S_HDR_HASH, S_LD_HASH, S_EMPTY_HASH);

    TYPE t_state16 IS (S_INT_MODE, S_INT_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_NPUB, S_LD_NPUB,
        S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG, S_LD_TAG,
        S_HDR_HASH, S_LD_HASH, S_EMPTY_HASH,

        S_HDR_KEYLEN, S_HDR_NPUBLEN, S_HDR_ADLEN, S_HDR_MSGLEN,
        S_HDR_TAGLEN, S_HDR_HASHLEN);

    TYPE t_state8 IS (S_INT_MODE, S_INT_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_NPUB, S_LD_NPUB,
        S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG, S_LD_TAG,
        S_HDR_HASH, S_LD_HASH, S_EMPTY_HASH,

        S_HDR_RESKEY, S_HDR_KEYLEN_MSB, S_HDR_KEYLEN_LSB,
        S_HDR_RESNPUB, S_HDR_NPUBLEN_MSB, S_HDR_NPUBLEN_LSB,
        S_HDR_RESAD, S_HDR_ADLEN_MSB, S_HDR_ADLEN_LSB,
        S_HDR_RESMSG, S_HDR_MSGLEN_MSB, S_HDR_MSGLEN_LSB,
        S_HDR_RESTAG, S_HDR_TAGLEN_MSB, S_HDR_TAGLEN_LSB,
        S_HDR_RESHASH, S_HDR_HASHLEN_MSB, S_HDR_HASHLEN_LSB);

BEGIN

    --! for simulation only
    PROCESS (clk) BEGIN
        IF (rising_edge(clk)) THEN
            ASSERT NOT (received_wrong_header = true)
            REPORT "Received unexpected header" SEVERITY failure;
        END IF;
    END PROCESS;

    --! Segment Length Counter
    SegLen : ENTITY work.StepDownCountLd(StepDownCountLd)
        GENERIC MAP(
            N => 16,
            step => Wdiv8
        )
        PORT MAP
        (
            clk => clk,
            len => len_SegLenCnt,
            load => load_SegLenCnt,
            ena => en_SegLenCnt,
            count => dout_SegLenCnt
        );

    -- if there are Wdiv8 or less bytes left, we processthe last flit
    last_flit_of_segment <= '1' WHEN
        (to_integer(unsigned(dout_SegLenCnt)) <= Wdiv8) ELSE
        '0';

    -- set valid bytes
    WITH (to_integer(unsigned(dout_SegLenCnt))) SELECT
    bdi_valid_bytes_p <= "1110" WHEN 3,
        "1100" WHEN 2,
        "1000" WHEN 1,
        "0000" WHEN 0,
        "1111" WHEN OTHERS;

    -- set padding location
    WITH (to_integer(unsigned(dout_SegLenCnt))) SELECT
    bdi_pad_loc_p <= "0001" WHEN 3,
        "0010" WHEN 2,
        "0100" WHEN 1,
        "1000" WHEN 0,
        "0000" WHEN OTHERS;

    --! Registers
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            hash_internal <= nx_hash_internal;
            decrypt_internal <= nx_decrypt_internal;
            eoi_flag <= nx_eoi_flag;
            eot_flag <= nx_eot_flag;
        END IF;
    END PROCESS;
    --! output assignment
    hash <= hash_internal;
    decrypt <= decrypt_internal;
    cmd <= pdi_data;
    -- ====================================================================================================
    --! 32 bit specific FSM -------------------------------------------------------------------------------
    -- ====================================================================================================

    FSM_32BIT : IF (W = 32) GENERATE

        --! 32 Bit specific declarations
        SIGNAL nx_state, pr_state : t_state32;
        SIGNAL bdi_valid_p : std_logic;
        SIGNAL bdi_ready_p : std_logic;
        SIGNAL key_valid_p : std_logic;
        SIGNAL key_ready_p : std_logic;
        SIGNAL bdi_size_p : std_logic_vector(2 DOWNTO 0);

        ---ALIAS
        ALIAS pdi_opcode : std_logic_vector(3 DOWNTO 0) IS pdi_data(31 DOWNTO 28);
        ALIAS sdi_opcode : std_logic_vector(3 DOWNTO 0) IS sdi_data(31 DOWNTO 28);
        ALIAS pdi_seg_length : std_logic_vector(15 DOWNTO 0) IS pdi_data(15 DOWNTO 0);
        ALIAS sdi_seg_length : std_logic_vector(15 DOWNTO 0) IS sdi_data(15 DOWNTO 0);

    BEGIN
        --! Multiplexer
        load_SegLenCnt <= sdi_seg_length WHEN (sel_sdi_length = True) ELSE
            pdi_seg_length;

        --set size: internally we deal with 32 bits only
        bdi_size_p <= dout_SegLenCnt(2 DOWNTO 0) WHEN last_flit_of_segment = '1' ELSE
            "100";

        -- use preserved eoi and eot flags for bdi port
        bdi_eoi_internal <= eoi_flag AND last_flit_of_segment;
        bdi_eot_internal <= eot_flag AND last_flit_of_segment;
        --! KEY PISO
        -- for ccsw > SW: a piso is used for width conversion
        keyPISO : ENTITY work.key_piso(behavioral) PORT MAP
            (
            clk => clk,
            rst => rst,

            data_s => key,
            data_valid_s => key_valid,
            data_ready_s => key_ready,

            data_p => sdi_data,
            data_valid_p => key_valid_p,
            data_ready_p => key_ready_p
            );

        --! DATA PISO
        -- for ccw > W: a piso is used for width conversion
        bdiPISO : ENTITY work.data_piso(behavioral) PORT MAP
            (
            clk => clk,
            rst => rst,

            data_size_p => bdi_size_p,
            data_size_s => bdi_size,

            data_s => bdi,
            data_valid_s => bdi_valid,
            data_ready_s => bdi_ready,

            data_p => pdi_data,
            data_valid_p => bdi_valid_p,
            data_ready_p => bdi_ready_p,

            valid_bytes_s => bdi_valid_bytes,
            valid_bytes_p => bdi_valid_bytes_p,

            pad_loc_s => bdi_pad_loc,
            pad_loc_p => bdi_pad_loc_p,

            eoi_s => bdi_eoi,
            eoi_p => bdi_eoi_internal,

            eot_s => bdi_eot,
            eot_p => bdi_eot_internal
            );
        --! State register
        PROCESS (clk)
        BEGIN
            IF (rising_edge(clk)) THEN
                IF (rst = '1') THEN
                    pr_state <= S_INT_MODE;
                ELSE
                    pr_state <= nx_state;
                END IF;
            END IF;
        END PROCESS;

        --! next state function
        PROCESS (pr_state, sdi_valid, last_flit_of_segment, decrypt_internal,
            pdi_valid, key_ready_p, bdi_ready_p, eot_flag, pdi_seg_length,
            pdi_opcode, sdi_opcode)

        BEGIN

            -- for simulation only
            received_wrong_header <= false;

            CASE pr_state IS

                    -- Set mode
                WHEN S_INT_MODE =>
                    IF (pdi_valid = '1') THEN
                        IF (pdi_opcode = INST_ACTKEY) THEN
                            nx_state <= S_INT_KEY;
                        ELSIF (pdi_opcode = INST_ENC OR pdi_opcode = INST_DEC) THEN
                            nx_state <= S_HDR_NPUB;
                        ELSIF (pdi_opcode = INST_HASH) THEN
                            nx_state <= S_HDR_HASH;
                        ELSE
                            nx_state <= S_INT_MODE;
                        END IF;
                    ELSE
                        nx_state <= S_INT_MODE;
                    END IF;

                    -- KEY
                WHEN S_INT_KEY =>
                    IF (sdi_valid = '1') THEN
                        received_wrong_header <= sdi_opcode /= INST_LDKEY;
                        nx_state <= S_HDR_KEY;
                    ELSE
                        nx_state <= S_INT_KEY;
                    END IF;

                WHEN S_HDR_KEY =>
                    IF (sdi_valid = '1') THEN
                        received_wrong_header <= sdi_opcode /= HDR_KEY;
                        nx_state <= S_LD_KEY;
                    ELSE
                        nx_state <= S_HDR_KEY;
                    END IF;

                WHEN S_LD_KEY => --We don't allow for parallel key loading in a lightweight enviroment
                    IF (sdi_valid = '1' AND key_ready_p = '1' AND last_flit_of_segment = '1') THEN
                        nx_state <= S_INT_MODE;
                    ELSE
                        nx_state <= S_LD_KEY;
                    END IF;

                    -- NPUB
                WHEN S_HDR_NPUB =>
                    IF (pdi_valid = '1') THEN
                        received_wrong_header <= pdi_opcode /= HDR_NPUB;
                        nx_state <= S_LD_NPUB;
                    ELSE
                        nx_state <= S_HDR_NPUB;
                    END IF;

                WHEN S_LD_NPUB =>
                    IF (pdi_valid = '1' AND bdi_ready_p = '1' AND last_flit_of_segment = '1') THEN
                        IF (decrypt_internal = '1') THEN
                            nx_state <= S_HDR_AD;
                        ELSE
                            nx_state <= S_HDR_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_NPUB;
                    END IF;

                    -- AD
                WHEN S_HDR_AD =>
                    IF (pdi_valid = '1') THEN
                        received_wrong_header <= pdi_opcode /= HDR_AD;
                        IF (pdi_seg_length = x"0000" AND eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_MSG;
                            ELSE
                                nx_state <= S_INT_MODE;
                            END IF;
                        ELSE
                            nx_state <= S_LD_AD;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_AD;
                    END IF;

                WHEN S_LD_AD =>
                    IF (pdi_valid = '1' AND bdi_ready_p = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_MSG;
                            ELSE
                                nx_state <= S_INT_MODE;
                            END IF;
                        ELSE
                            nx_state <= S_HDR_AD;
                        END IF;
                    ELSE
                        nx_state <= S_LD_AD;
                    END IF;

                    -- Plaintext or Ciphertext
                WHEN S_HDR_MSG =>
                    IF (pdi_valid = '1') THEN
                        received_wrong_header <= (pdi_opcode /= HDR_PT AND pdi_opcode /= HDR_CT);
                        IF (pdi_seg_length = x"0000" AND eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_TAG;
                            ELSE
                                nx_state <= S_HDR_AD;
                            END IF;
                        ELSE
                            nx_state <= S_LD_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_MSG;
                    END IF;

                WHEN S_LD_MSG =>
                    IF (pdi_valid = '1' AND bdi_ready_p = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_TAG;
                            ELSE
                                nx_state <= S_HDR_AD;
                            END IF;
                        ELSE
                            nx_state <= S_HDR_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_MSG;
                    END IF;

                    -- TAG for AEAD
                WHEN S_HDR_TAG =>
                    IF (pdi_valid = '1') THEN
                        received_wrong_header <= pdi_opcode /= HDR_TAG;
                        nx_state <= S_LD_TAG;
                    ELSE
                        nx_state <= S_HDR_TAG;
                    END IF;

                WHEN S_LD_TAG =>
                    IF (pdi_valid = '1' AND last_flit_of_segment = '1') THEN
                        IF (bdi_ready_p = '1') THEN
                            nx_state <= S_INT_MODE;
                        ELSE
                            nx_state <= S_LD_TAG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_TAG;
                    END IF;

                    --HASH
                WHEN S_HDR_HASH =>
                    IF (pdi_valid = '1') THEN
                        received_wrong_header <= pdi_opcode /= HDR_HASH_MSG;
                        IF (pdi_seg_length = x"0000") THEN
                            nx_state <= S_EMPTY_HASH;
                        ELSE
                            nx_state <= S_LD_HASH;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_HASH;
                    END IF;

                WHEN S_EMPTY_HASH =>
                    IF (bdi_ready_p = '1') THEN
                        nx_state <= S_INT_MODE;
                    ELSE
                        nx_state <= S_EMPTY_HASH;
                    END IF;

                WHEN S_LD_HASH =>
                    IF (pdi_valid = '1' AND bdi_ready_p = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN
                            nx_state <= S_INT_MODE;
                        ELSE
                            nx_state <= S_HDR_HASH;
                        END IF;
                    ELSE
                        nx_state <= S_LD_HASH;
                    END IF;

                WHEN OTHERS =>
                    nx_state <= S_INT_MODE;

            END CASE;
        END PROCESS;
        --! output state function
        PROCESS (pr_state, sdi_valid, pdi_valid, eoi_flag, eot_flag, hash_internal,
            key_ready_p, bdi_ready_p, cmd_ready, decrypt_internal, pdi_data)
        BEGIN
            -- DEFAULT Values
            -- external interface
            sdi_ready <= '0';
            pdi_ready <= '0';
            -- LWC core
            key_valid_p <= '0';
            key_update <= '0';
            bdi_valid_p <= '0';
            bdi_type <= "0000";
            -- header-FIFO
            cmd_valid <= '0';
            -- counter
            len_SegLenCnt <= '0';
            en_SegLenCnt <= '0';
            -- register
            nx_eoi_flag <= eoi_flag;
            nx_eot_flag <= eot_flag;
            nx_hash_internal <= hash_internal;
            nx_decrypt_internal <= decrypt_internal;
            -- multiplexer
            sel_sdi_length <= false;

            CASE pr_state IS

                    -- Set MODE
                WHEN S_INT_MODE =>
                    pdi_ready <= '1';
                    nx_hash_internal <= '0';

                    IF (pdi_opcode = INST_ENC OR pdi_opcode = INST_DEC) THEN
                        IF (pdi_valid = '1') THEN
                            -- pdi_data(28) is 1 if INST_DEC, else it is '0' if INST_ENC
                            nx_decrypt_internal <= pdi_data(28);
                            cmd_valid <= '1'; --Forward instruction
                        END IF;

                    ELSIF (pdi_opcode = INST_HASH) THEN
                        IF (pdi_valid = '1') THEN
                            nx_hash_internal <= '1';
                            cmd_valid <= '1'; --Forward instruction
                        END IF;
                    END IF;
                    -- KEY
                WHEN S_INT_KEY =>
                    sdi_ready <= '1';
                    key_update <= '0';

                WHEN S_HDR_KEY =>
                    sdi_ready <= '1';
                    len_SegLenCnt <= sdi_valid;
                    sel_sdi_length <= true;

                WHEN S_LD_KEY =>
                    sdi_ready <= key_ready_p;
                    key_valid_p <= sdi_valid;
                    key_update <= '1';
                    en_SegLenCnt <= sdi_valid AND key_ready_p;

                    -- NPUB
                WHEN S_HDR_NPUB =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;
                    IF (pdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(26);
                        nx_eot_flag <= pdi_data(25);
                    END IF;

                WHEN S_LD_NPUB =>
                    pdi_ready <= bdi_ready_p;
                    bdi_valid_p <= pdi_valid;
                    bdi_type <= HDR_NPUB;
                    en_SegLenCnt <= pdi_valid AND bdi_ready_p;

                    -- AD
                WHEN S_HDR_AD =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;
                    IF (pdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(26);
                        nx_eot_flag <= pdi_data(25);
                    END IF;

                WHEN S_LD_AD =>
                    pdi_ready <= bdi_ready_p;
                    bdi_valid_p <= pdi_valid;
                    bdi_type <= HDR_AD;
                    en_SegLenCnt <= pdi_valid AND bdi_ready_p;

                    -- Plaintext or Ciphertext
                WHEN S_HDR_MSG =>
                    cmd_valid <= pdi_valid;
                    pdi_ready <= cmd_ready;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;
                    IF (pdi_valid = '1' AND cmd_ready = '1') THEN
                        nx_eoi_flag <= pdi_data(26);
                        nx_eot_flag <= pdi_data(25);
                    END IF;

                WHEN S_LD_MSG =>
                    pdi_ready <= bdi_ready_p;
                    bdi_valid_p <= pdi_valid;
                    IF (decrypt_internal = '1') THEN
                        bdi_type <= HDR_CT;
                    ELSE
                        bdi_type <= HDR_PT;
                    END IF;
                    en_SegLenCnt <= pdi_valid AND bdi_ready_p;

                    -- TAG for AEAD
                WHEN S_HDR_TAG =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid AND cmd_ready;

                WHEN S_LD_TAG =>
                    bdi_type <= HDR_TAG;

                    IF (decrypt_internal = '1') THEN
                        bdi_valid_p <= pdi_valid;
                        pdi_ready <= bdi_ready_p;
                        en_SegLenCnt <= pdi_valid AND bdi_ready_p;
                    END IF;

                    -- HASH
                WHEN S_HDR_HASH =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;
                    IF (pdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(26);
                        nx_eot_flag <= pdi_data(25);
                    END IF;

                WHEN S_LD_HASH =>
                    pdi_ready <= bdi_ready_p;
                    bdi_valid_p <= pdi_valid;
                    bdi_type <= HDR_HASH_MSG;
                    en_SegLenCnt <= pdi_valid AND bdi_ready_p;

                WHEN S_EMPTY_HASH =>
                    bdi_valid_p <= '1';
                    bdi_type <= HDR_HASH_MSG;

                WHEN OTHERS =>
                    NULL;
            END CASE;
        END PROCESS;

    END GENERATE;

    -- ====================================================================================================
    --! 16 bit specific FSM -------------------------------------------------------------------------------
    -- ====================================================================================================

    FSM_16BIT : IF (W = 16) GENERATE

        --! 16 Bit specific declarations
        SIGNAL data_seg_length : std_logic_vector(W - 1 DOWNTO 0);
        SIGNAL bdi_size_not_last : std_logic_vector(2 DOWNTO 0);
        --Registers
        SIGNAL nx_state, pr_state : t_state16;

    BEGIN

        --! Logics

        bdi_size <= dout_SegLenCnt(2 DOWNTO 0) WHEN last_flit_of_segment = '1' ELSE
            bdi_size_not_last;

        WITH Wdiv8 SELECT
            bdi_size_not_last <= "100" WHEN 4,
            "010" WHEN 2,
            "001" WHEN 1,
            "000" WHEN OTHERS;

        bdi_pad_loc (Wdiv8 - 1 DOWNTO 0) <= bdi_pad_loc_p(3 DOWNTO 4 - Wdiv8);
        bdi_valid_bytes(Wdiv8 - 1 DOWNTO 0) <= bdi_valid_bytes_p(3 DOWNTO 4 - Wdiv8);
        data_seg_length <= sdi_data WHEN sel_sdi_length = true ELSE
            pdi_data;
        load_SegLenCnt <= data_seg_length(W - 1 DOWNTO W - 8 * Wdiv8);

        bdi_eoi_internal <= eoi_flag AND last_flit_of_segment;
        bdi_eot_internal <= eot_flag AND last_flit_of_segment;
        bdi_eoi <= bdi_eoi_internal;
        bdi_eot <= bdi_eot_internal;

        --! Assigning Data to buses
        bdi <= pdi_data;
        key <= sdi_data;

        --! State register
        PROCESS (clk)
        BEGIN
            IF (rising_edge(clk)) THEN
                IF (rst = '1') THEN
                    pr_state <= S_INT_MODE;
                ELSE
                    pr_state <= nx_state;
                END IF;
            END IF;
        END PROCESS;
        --!next state function
        PROCESS (pr_state, sdi_valid, pdi_valid, sdi_data, pdi_data,
            last_flit_of_segment, decrypt_internal, key_ready, bdi_ready,
            cmd_ready, bdi_eot_internal,
            bdi_eoi_internal, eot_flag, eoi_flag)

        BEGIN
            CASE pr_state IS

                    ---MODE SET-
                WHEN S_INT_MODE =>
                    IF (pdi_valid = '1') THEN
                        IF (pdi_data(W - 1 DOWNTO W - 4) = INST_ACTKEY) THEN
                            nx_state <= S_INT_KEY;
                        ELSIF (pdi_data(W - 1 DOWNTO W - 3) = INST_ENC(3 DOWNTO 1)) AND (cmd_ready = '1') THEN
                            nx_state <= S_HDR_NPUB;
                        ELSIF (pdi_data(W - 1 DOWNTO W - 4) = INST_HASH) THEN
                            nx_state <= S_HDR_HASH;
                        ELSE
                            nx_state <= S_INT_MODE;
                        END IF;
                    ELSE
                        nx_state <= S_INT_MODE;
                    END IF;

                    ---load key
                WHEN S_INT_KEY =>
                    IF (sdi_valid = '1' AND sdi_data(W - 1 DOWNTO W - 4) = INST_LDKEY) THEN
                        nx_state <= S_HDR_KEY;
                    ELSE
                        nx_state <= S_INT_KEY;
                    END IF;

                WHEN S_HDR_KEY =>
                    IF (sdi_valid = '1' AND sdi_data(W - 1 DOWNTO W - 4) = HDR_KEY) THEN
                        nx_state <= S_HDR_KEYLEN;
                    ELSE
                        nx_state <= S_HDR_KEY;
                    END IF;

                WHEN S_HDR_KEYLEN =>
                    IF (sdi_valid = '1') THEN
                        nx_state <= S_LD_KEY;
                    ELSE
                        nx_state <= S_HDR_KEYLEN;
                    END IF;

                WHEN S_LD_KEY =>
                    IF (sdi_valid = '1' AND key_ready = '1' AND last_flit_of_segment = '1') THEN
                        nx_state <= S_INT_MODE;
                    ELSE
                        nx_state <= S_LD_KEY;
                    END IF;

                    ---NPUB
                WHEN S_HDR_NPUB =>
                    IF (pdi_valid = '1' AND pdi_data(W - 1 DOWNTO W - 4) = HDR_NPUB) THEN
                        nx_state <= S_HDR_NPUBLEN;
                    ELSE
                        nx_state <= S_HDR_NPUB;
                    END IF;

                WHEN S_HDR_NPUBLEN =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_LD_NPUB;
                    ELSE
                        nx_state <= S_HDR_NPUBLEN;
                    END IF;

                WHEN S_LD_NPUB =>
                    IF (pdi_valid = '1' AND bdi_ready = '1' AND last_flit_of_segment = '1') THEN
                        IF (decrypt_internal = '1') THEN
                            nx_state <= S_HDR_AD;
                        ELSE
                            nx_state <= S_HDR_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_NPUB;
                    END IF;

                    --AD
                WHEN S_HDR_AD =>
                    IF (pdi_valid = '1' AND pdi_data(W - 1 DOWNTO W - 4) = HDR_AD) THEN
                        nx_state <= S_HDR_ADLEN;
                    ELSE
                        nx_state <= S_HDR_AD;
                    END IF;

                WHEN S_HDR_ADLEN =>
                    IF (pdi_valid = '1') THEN
                        IF (pdi_data = zero_data) THEN
                            IF (bdi_eoi_internal = '1') THEN
                                IF (decrypt_internal = '1') THEN
                                    nx_state <= S_HDR_MSG;
                                ELSE
                                    nx_state <= S_INT_MODE;
                                END IF;
                            ELSE
                                IF (decrypt_internal = '1') THEN
                                    nx_state <= S_HDR_MSG;
                                ELSE
                                    nx_state <= S_INT_MODE;
                                END IF;
                            END IF;
                        ELSE
                            nx_state <= S_LD_AD;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_ADLEN;
                    END IF;

                WHEN S_LD_AD =>
                    IF (pdi_valid = '1' AND bdi_ready = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_MSG;
                            ELSE
                                nx_state <= S_INT_MODE;
                            END IF;
                        ELSE
                            nx_state <= S_HDR_AD;
                        END IF;
                    ELSE
                        nx_state <= S_LD_AD;
                    END IF;

                    --MSG OR CIPHER TEXT
                WHEN S_HDR_MSG =>
                    IF (pdi_valid = '1' AND (pdi_data(W - 1 DOWNTO W - 4) = HDR_PT
                        OR pdi_data(W - 1 DOWNTO W - 4) = HDR_CT)) THEN
                        nx_state <= S_HDR_MSGLEN;
                    ELSE
                        nx_state <= S_HDR_MSG;
                    END IF;

                WHEN S_HDR_MSGLEN =>
                    IF (pdi_valid = '1' AND cmd_ready = '1') THEN
                        IF (pdi_data = zero_data AND eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_TAG;
                            ELSE
                                nx_state <= S_HDR_AD;
                            END IF;
                        ELSE
                            nx_state <= S_LD_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_MSGLEN;
                    END IF;

                WHEN S_LD_MSG =>
                    IF (pdi_valid = '1' AND bdi_ready = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_TAG;
                            ELSE
                                nx_state <= S_HDR_AD;
                            END IF;
                        ELSE
                            nx_state <= S_HDR_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_MSG;
                    END IF;

                    --TAG
                WHEN S_HDR_TAG =>
                    IF (pdi_valid = '1' AND pdi_data(W - 1 DOWNTO W - 4) = HDR_TAG) THEN
                        nx_state <= S_HDR_TAGLEN;
                    ELSE
                        nx_state <= S_HDR_TAG;
                    END IF;

                WHEN S_HDR_TAGLEN =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_LD_TAG;
                    ELSE
                        nx_state <= S_HDR_TAGLEN;
                    END IF;

                WHEN S_LD_TAG =>
                    IF (pdi_valid = '1' AND last_flit_of_segment = '1') THEN
                        IF (bdi_ready = '1') THEN
                            nx_state <= S_INT_MODE;
                        ELSE
                            nx_state <= S_LD_TAG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_TAG;
                    END IF;

                    --HASH
                WHEN S_HDR_HASH =>
                    IF (pdi_valid = '1' AND pdi_data(W - 1 DOWNTO W - 3) = HDR_HASH_MSG(3 DOWNTO 1)) THEN
                        nx_state <= S_HDR_HASHLEN;
                    ELSE
                        nx_state <= S_HDR_HASH;
                    END IF;

                WHEN S_HDR_HASHLEN =>
                    IF (pdi_valid = '1'AND cmd_ready = '1') THEN
                        IF (pdi_data = zero_data AND eot_flag = '1') THEN
                            nx_state <= S_EMPTY_HASH;
                        ELSE
                            nx_state <= S_LD_HASH;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_HASHLEN;
                    END IF;

                WHEN S_EMPTY_HASH =>
                    IF (bdi_ready = '1') THEN
                        nx_state <= S_INT_MODE;
                    ELSE
                        nx_state <= S_EMPTY_HASH;
                    END IF;

                WHEN S_LD_HASH =>
                    IF (pdi_valid = '1' AND bdi_ready = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN
                            nx_state <= S_INT_MODE;
                        ELSE
                            nx_state <= S_HDR_HASH;
                        END IF;
                    ELSE
                        nx_state <= S_LD_HASH;
                    END IF;

                WHEN OTHERS =>
                    nx_state <= S_INT_MODE;

            END CASE;
        END PROCESS;

        --!output state function
        PROCESS (pr_state, sdi_valid, pdi_valid, key_ready, bdi_ready, cmd_ready,
            pdi_data, decrypt_internal, hash_internal, eoi_flag, eot_flag)

        BEGIN
            --DEFAULT Values
            --external interface
            sdi_ready <= '0';
            pdi_ready <= '0';
            -- CryptoCore
            key_valid <= '0';
            bdi_valid <= '0';
            bdi_type <= "0000";
            key_update <= '0';
            -- Header-FIFO
            cmd_valid <= '0';
            -- Segment counter
            len_SegLenCnt <= '0';
            en_SegLenCnt <= '0';
            -- Register
            nx_hash_internal <= hash_internal;
            nx_decrypt_internal <= decrypt_internal;
            nx_eoi_flag <= eoi_flag;
            nx_eot_flag <= eot_flag;
            -- Multiplexer
            sel_sdi_length <= false;

            CASE pr_state IS

                    ---MODE
                WHEN S_INT_MODE =>
                    nx_hash_internal <= '0';
                    IF (pdi_data(W - 1 DOWNTO W - 3) = INST_ENC(3 DOWNTO 1)) THEN
                        IF (pdi_valid = '1') THEN
                            nx_decrypt_internal <= pdi_data(W - 4);
                        END IF;
                        cmd_valid <= pdi_valid;
                        pdi_ready <= cmd_ready;
                        nx_hash_internal <= '0';
                    ELSIF (pdi_data(W - 1 DOWNTO W - 4) = INST_ACTKEY) THEN
                        pdi_ready <= '1';
                        nx_hash_internal <= '0';

                    ELSIF (pdi_data(W - 1 DOWNTO W - 4) = INST_HASH) THEN
                        nx_hash_internal <= '1';
                        IF (pdi_valid = '1') THEN

                            IF (pdi_valid = '1') THEN
                                nx_decrypt_internal <= pdi_data(W - 4);
                            END IF;
                            cmd_valid <= pdi_valid;
                            pdi_ready <= cmd_ready;
                        END IF;
                    END IF;

                WHEN S_INT_KEY =>
                    sdi_ready <= '1';
                    key_update <= '0';

                WHEN S_HDR_KEY =>
                    sdi_ready <= '1';
                    len_SegLenCnt <= sdi_valid;
                    sel_sdi_length <= true;
                    IF (sdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_KEYLEN =>
                    sdi_ready <= '1';
                    len_SegLenCnt <= sdi_valid;
                    sel_sdi_length <= true;

                WHEN S_LD_KEY =>
                    sdi_ready <= key_ready;
                    key_valid <= sdi_valid;
                    key_update <= '1';
                    en_SegLenCnt <= sdi_valid AND key_ready;

                    ---NPUB
                WHEN S_HDR_NPUB =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;
                    IF (pdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_NPUBLEN =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;

                WHEN S_LD_NPUB =>
                    pdi_ready <= bdi_ready;
                    bdi_valid <= pdi_valid;
                    bdi_type <= HDR_NPUB;
                    en_SegLenCnt <= pdi_valid AND bdi_ready;

                    ---AD
                WHEN S_HDR_AD =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;
                    IF (pdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_ADLEN =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;

                WHEN S_LD_AD =>
                    pdi_ready <= bdi_ready;
                    bdi_valid <= pdi_valid;
                    bdi_type <= HDR_AD;
                    en_SegLenCnt <= pdi_valid AND bdi_ready;

                    --MSG
                WHEN S_HDR_MSG =>
                    IF (pdi_data(W - 1 DOWNTO W - 4) = HDR_PT OR pdi_data(W - 1 DOWNTO W - 4) = HDR_CT) THEN
                        cmd_valid <= pdi_valid;
                    END IF;
                    pdi_ready <= cmd_ready;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;
                    IF ((pdi_valid = '1') AND (cmd_ready = '1')) THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_MSGLEN =>
                    pdi_ready <= cmd_ready;
                    cmd_valid <= pdi_valid;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;

                WHEN S_LD_MSG =>
                    pdi_ready <= bdi_ready;
                    bdi_valid <= pdi_valid;
                    IF (decrypt_internal = '1') THEN
                        bdi_type <= HDR_CT;
                    ELSE
                        bdi_type <= HDR_PT;
                    END IF;
                    en_SegLenCnt <= pdi_valid AND bdi_ready;

                    --HASH
                WHEN S_HDR_HASH =>
                    pdi_ready <= cmd_ready;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;
                    IF ((pdi_valid = '1') AND (cmd_ready = '1')) THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_HASHLEN =>
                    pdi_ready <= cmd_ready;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;

                WHEN S_EMPTY_HASH =>
                    bdi_valid <= '1';
                    bdi_type <= HDR_HASH_MSG;

                WHEN S_LD_HASH =>
                    pdi_ready <= bdi_ready;
                    bdi_valid <= pdi_valid;
                    bdi_type <= HDR_HASH_MSG;
                    en_SegLenCnt <= pdi_valid AND bdi_ready;

                    --TAG
                WHEN S_HDR_TAG =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid AND cmd_ready;

                WHEN S_HDR_TAGLEN =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid AND cmd_ready;

                WHEN S_LD_TAG =>
                    bdi_type <= HDR_TAG;
                    IF (decrypt_internal = '1') THEN
                        bdi_valid <= pdi_valid;
                        pdi_ready <= bdi_ready;
                        en_SegLenCnt <= pdi_valid AND bdi_ready;
                    END IF;

                WHEN OTHERS =>
                    NULL;

            END CASE;
        END PROCESS;

    END GENERATE;

    -- ====================================================================================================
    --! 08 bit specific FSM -------------------------------------------------------------------------------
    -- ====================================================================================================

    FSM_8BIT : IF (W = 8) GENERATE
        --! 8 Bit specific declarations
        SIGNAL nx_state, pr_state : t_state8;
        SIGNAL bdi_size_not_last : std_logic_vector(2 DOWNTO 0);
        -- Registers
        SIGNAL data_seg_length : std_logic_vector(W - 1 DOWNTO 0);
        SIGNAL dout_LenReg, nx_dout_LenReg : std_logic_vector(7 DOWNTO 0);

    BEGIN

        --! Logics
        load_SegLenCnt <= dout_LenReg(7 DOWNTO 0) & data_seg_length(W - 1 DOWNTO W - 8);
        bdi_size <= dout_SegLenCnt(2 DOWNTO 0) WHEN last_flit_of_segment = '1' ELSE
            bdi_size_not_last;

        WITH Wdiv8 SELECT
            bdi_size_not_last <= "100" WHEN 4,
            "010" WHEN 2,
            "001" WHEN 1,
            "000" WHEN OTHERS;

        bdi_pad_loc (Wdiv8 - 1 DOWNTO 0) <= bdi_pad_loc_p(3 DOWNTO 4 - Wdiv8);

        bdi_valid_bytes(Wdiv8 - 1 DOWNTO 0) <= bdi_valid_bytes_p(3 DOWNTO 4 - Wdiv8);

        data_seg_length <= sdi_data WHEN sel_sdi_length = true ELSE
            pdi_data;
        bdi_eoi_internal <= eoi_flag AND last_flit_of_segment;
        bdi_eot_internal <= eot_flag AND last_flit_of_segment;
        bdi_eoi <= bdi_eoi_internal;
        bdi_eot <= bdi_eot_internal;

        ---!Assigning Data to buses
        bdi <= pdi_data;
        key <= sdi_data;

        --! Length register
        LenReg : PROCESS (clk)
        BEGIN
            IF rising_edge(clk) THEN
                dout_LenReg <= nx_dout_LenReg;
            END IF;
        END PROCESS;
        --! State register
        PROCESS (clk)
        BEGIN
            IF (rising_edge(clk)) THEN
                IF (rst = '1') THEN
                    pr_state <= S_INT_MODE;
                ELSE
                    pr_state <= nx_state;
                END IF;
            END IF;
        END PROCESS;
        --!next state function
        PROCESS (pr_state, sdi_valid, pdi_valid, sdi_data, pdi_data,
            last_flit_of_segment, decrypt_internal, key_ready, bdi_ready,
            cmd_ready, bdi_eot_internal, dout_lenreg,
            bdi_eoi_internal, eot_flag, eoi_flag)

        BEGIN
            CASE pr_state IS

                    ---MODE SET
                WHEN S_INT_MODE =>
                    IF (pdi_valid = '1') THEN
                        IF (pdi_data(W - 1 DOWNTO W - 4) = INST_ACTKEY) THEN
                            nx_state <= S_INT_KEY;
                        ELSIF (pdi_data(W - 1 DOWNTO W - 3) = INST_ENC(3 DOWNTO 1)) AND (cmd_ready = '1') THEN
                            nx_state <= S_HDR_NPUB;
                        ELSIF (pdi_data(W - 1 DOWNTO W - 4) = INST_HASH) THEN
                            nx_state <= S_HDR_HASH;
                        ELSE
                            nx_state <= S_INT_MODE;
                        END IF;
                    ELSE
                        nx_state <= S_INT_MODE;
                    END IF;

                    ---load key
                WHEN S_INT_KEY =>
                    IF (sdi_valid = '1' AND sdi_data(W - 1 DOWNTO W - 4) = INST_LDKEY) THEN
                        nx_state <= S_HDR_KEY;
                    ELSE
                        nx_state <= S_INT_KEY;
                    END IF;

                WHEN S_HDR_KEY =>
                    IF (sdi_valid = '1' AND sdi_data(W - 1 DOWNTO W - 4) = HDR_KEY) THEN
                        nx_state <= S_HDR_RESKEY;
                    ELSE
                        nx_state <= S_HDR_KEY;
                    END IF;

                WHEN S_HDR_RESKEY =>
                    IF (sdi_valid = '1') THEN
                        nx_state <= S_HDR_KEYLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESKEY;
                    END IF;

                WHEN S_HDR_KEYLEN_MSB =>
                    IF (sdi_valid = '1') THEN
                        nx_state <= S_HDR_KEYLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_KEYLEN_MSB;
                    END IF;

                WHEN S_HDR_KEYLEN_LSB =>
                    IF (sdi_valid = '1') THEN
                        nx_state <= S_LD_KEY;
                    ELSE
                        nx_state <= S_HDR_KEYLEN_LSB;
                    END IF;

                WHEN S_LD_KEY =>
                    IF (sdi_valid = '1' AND key_ready = '1' AND last_flit_of_segment = '1') THEN
                        nx_state <= S_INT_MODE;
                    ELSE
                        nx_state <= S_LD_KEY;
                    END IF;

                    ---NPUB
                WHEN S_HDR_NPUB =>
                    IF (pdi_valid = '1' AND pdi_data(W - 1 DOWNTO W - 4) = HDR_NPUB) THEN
                        nx_state <= S_HDR_RESNPUB;
                    ELSE
                        nx_state <= S_HDR_NPUB;
                    END IF;

                WHEN S_HDR_RESNPUB =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_HDR_NPUBLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESNPUB;
                    END IF;

                WHEN S_HDR_NPUBLEN_MSB =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_HDR_NPUBLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_NPUBLEN_MSB;
                    END IF;

                WHEN S_HDR_NPUBLEN_LSB =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_LD_NPUB;
                    ELSE
                        nx_state <= S_HDR_NPUBLEN_LSB;
                    END IF;

                WHEN S_LD_NPUB =>
                    IF (pdi_valid = '1' AND bdi_ready = '1' AND last_flit_of_segment = '1') THEN
                        IF (decrypt_internal = '1') THEN
                            nx_state <= S_HDR_AD;
                        ELSE
                            nx_state <= S_HDR_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_NPUB;
                    END IF;

                    --AD
                WHEN S_HDR_AD =>
                    IF (pdi_valid = '1' AND pdi_data(W - 1 DOWNTO W - 4) = HDR_AD) THEN
                        nx_state <= S_HDR_RESAD;
                    ELSE
                        nx_state <= S_HDR_AD;
                    END IF;

                WHEN S_HDR_RESAD =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_HDR_ADLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESAD;
                    END IF;

                WHEN S_HDR_ADLEN_MSB =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_HDR_ADLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_ADLEN_MSB;
                    END IF;

                WHEN S_HDR_ADLEN_LSB =>
                    IF (pdi_valid = '1') THEN
                        IF (dout_LenReg = x"00" AND pdi_data(7 DOWNTO 0) = x"00" AND eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_MSG;
                            ELSE
                                nx_state <= S_INT_MODE;
                            END IF;
                        ELSE
                            nx_state <= S_LD_AD;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_ADLEN_LSB;
                    END IF;

                WHEN S_LD_AD =>
                    IF (pdi_valid = '1' AND bdi_ready = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN --eot
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_MSG;
                            ELSE
                                nx_state <= S_INT_MODE;
                            END IF;
                        ELSE
                            nx_state <= S_HDR_TAG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_AD;
                    END IF;

                    --MSG OR CIPHER TEXT
                WHEN S_HDR_MSG =>
                    IF (pdi_valid = '1' AND cmd_ready = '1' AND (pdi_data(W - 1 DOWNTO W - 4) = HDR_PT
                        OR pdi_data(W - 1 DOWNTO W - 4) = HDR_CT)) THEN
                        nx_state <= S_HDR_RESMSG;
                    ELSE
                        nx_state <= S_HDR_MSG;
                    END IF;

                WHEN S_HDR_RESMSG =>
                    IF (pdi_valid = '1' AND cmd_ready = '1') THEN
                        nx_state <= S_HDR_MSGLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESMSG;
                    END IF;

                WHEN S_HDR_MSGLEN_MSB =>
                    IF (pdi_valid = '1'AND cmd_ready = '1') THEN
                        nx_state <= S_HDR_MSGLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_MSGLEN_MSB;
                    END IF;

                WHEN S_HDR_MSGLEN_LSB =>
                    IF (pdi_valid = '1'AND cmd_ready = '1') THEN
                        IF (dout_LenReg = x"00" AND pdi_data(7 DOWNTO 0) = x"00" AND eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_TAG;
                            ELSE
                                nx_state <= S_HDR_AD;
                            END IF;
                        ELSE
                            nx_state <= S_LD_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_MSGLEN_LSB;
                    END IF;

                WHEN S_LD_MSG =>
                    IF (pdi_valid = '1' AND bdi_ready = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN
                            IF (decrypt_internal = '1') THEN
                                nx_state <= S_HDR_TAG;
                            ELSE
                                nx_state <= S_HDR_AD;
                            END IF;
                        ELSE
                            nx_state <= S_HDR_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_MSG;
                    END IF;

                    --TAG
                WHEN S_HDR_TAG =>
                    IF (pdi_valid = '1' AND pdi_data(W - 1 DOWNTO W - 4) = HDR_TAG) THEN
                        nx_state <= S_HDR_RESTAG;
                    ELSE
                        nx_state <= S_HDR_TAG;
                    END IF;

                WHEN S_HDR_RESTAG =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_HDR_TAGLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESTAG;
                    END IF;

                WHEN S_HDR_TAGLEN_MSB =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_HDR_TAGLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_TAGLEN_MSB;
                    END IF;

                WHEN S_HDR_TAGLEN_LSB =>
                    IF (pdi_valid = '1') THEN
                        nx_state <= S_LD_TAG;
                    ELSE
                        nx_state <= S_HDR_TAGLEN_LSB;
                    END IF;

                WHEN S_LD_TAG =>
                    IF (pdi_valid = '1' AND last_flit_of_segment = '1') THEN
                        IF (bdi_ready = '1') THEN
                            nx_state <= S_INT_MODE;
                        ELSE
                            nx_state <= S_LD_TAG;
                        END IF;
                    ELSE
                        nx_state <= S_LD_TAG;
                    END IF;

                    --HASH
                WHEN S_HDR_HASH =>
                    IF (pdi_valid = '1' AND pdi_data(W - 1 DOWNTO W - 3) = HDR_HASH_MSG(3 DOWNTO 1)) THEN
                        nx_state <= S_HDR_RESHASH;
                    ELSE
                        nx_state <= S_HDR_HASH;
                    END IF;

                WHEN S_HDR_RESHASH =>
                    IF (pdi_valid = '1' AND cmd_ready = '1') THEN
                        nx_state <= S_HDR_HASHLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESHASH;
                    END IF;

                WHEN S_HDR_HASHLEN_MSB =>
                    IF (pdi_valid = '1'AND cmd_ready = '1') THEN
                        nx_state <= S_HDR_HASHLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_HASHLEN_MSB;
                    END IF;

                WHEN S_HDR_HASHLEN_LSB =>
                    IF (pdi_valid = '1'AND cmd_ready = '1') THEN
                        IF (dout_LenReg = x"00" AND pdi_data(7 DOWNTO 0) = x"00") THEN
                            nx_state <= S_EMPTY_HASH;
                        ELSE
                            nx_state <= S_LD_HASH;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_HASHLEN_LSB;
                    END IF;

                WHEN S_EMPTY_HASH =>
                    IF (bdi_ready = '1') THEN
                        nx_state <= S_INT_MODE;
                    ELSE
                        nx_state <= S_EMPTY_HASH;
                    END IF;

                WHEN S_LD_HASH =>
                    IF (pdi_valid = '1' AND bdi_ready = '1' AND last_flit_of_segment = '1') THEN
                        IF (eot_flag = '1') THEN
                            nx_state <= S_INT_MODE;
                        ELSE
                            nx_state <= S_HDR_HASH;
                        END IF;
                    ELSE
                        nx_state <= S_LD_HASH;
                    END IF;

                WHEN OTHERS =>
                    nx_state <= S_INT_MODE;

            END CASE;
        END PROCESS;
        --!output state function
        PROCESS (pr_state, sdi_valid, pdi_valid, key_ready, bdi_ready, cmd_ready,
            pdi_data, decrypt_internal, hash_internal, data_seg_length, dout_LenReg,
            eoi_flag, eot_flag)

        BEGIN
            -- DEFAULT Values
            -- external interface
            sdi_ready <= '0';
            pdi_ready <= '0';
            -- CryptoCore
            key_valid <= '0';
            key_update <= '0';
            bdi_valid <= '0';
            bdi_type <= "0000";
            -- Header-FIFO
            cmd_valid <= '0';
            -- segment counter
            len_SegLenCnt <= '0';
            en_SegLenCnt <= '0';
            --Register
            nx_hash_internal <= hash_internal;
            nx_decrypt_internal <= decrypt_internal;
            nx_dout_LenReg <= dout_LenReg;
            nx_eoi_flag <= eoi_flag;
            nx_eot_flag <= eot_flag;
            -- Multiplexer
            sel_sdi_length <= false;

            CASE pr_state IS

                    ---MODE
                WHEN S_INT_MODE =>
                    nx_hash_internal <= '0';
                    IF (pdi_data(W - 1 DOWNTO W - 3) = INST_ENC(3 DOWNTO 1)) THEN
                        IF (pdi_valid = '1') THEN
                            nx_decrypt_internal <= pdi_data(W - 4);
                        END IF;
                        cmd_valid <= pdi_valid;
                        pdi_ready <= cmd_ready;
                        nx_hash_internal <= '0';
                    ELSIF (pdi_data(W - 1 DOWNTO W - 4) = INST_ACTKEY) THEN
                        pdi_ready <= '1';
                        nx_hash_internal <= '0';
                    ELSIF (pdi_data(W - 1 DOWNTO W - 4) = INST_HASH) THEN
                        IF (pdi_valid = '1') THEN
                            nx_hash_internal <= '1';
                            IF (pdi_valid = '1') THEN
                                nx_decrypt_internal <= pdi_data(W - 4);
                            END IF;
                            cmd_valid <= pdi_valid;
                            pdi_ready <= cmd_ready;
                        END IF;
                    END IF;

                WHEN S_INT_KEY =>
                    sdi_ready <= '1';
                    key_update <= '0';

                WHEN S_HDR_KEY =>
                    sdi_ready <= '1';
                    len_SegLenCnt <= sdi_valid;
                    sel_sdi_length <= true;
                    IF (sdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_RESKEY =>
                    sdi_ready <= '1';
                    sel_sdi_length <= true;

                WHEN S_HDR_KEYLEN_MSB =>
                    sdi_ready <= '1';
                    sel_sdi_length <= true;
                    IF (sdi_valid = '1') THEN
                        nx_dout_LenReg <= data_seg_length(W - 1 DOWNTO W - 8);
                    END IF;

                WHEN S_HDR_KEYLEN_LSB =>
                    sdi_ready <= '1';
                    len_SegLenCnt <= sdi_valid;
                    sel_sdi_length <= true;

                WHEN S_LD_KEY =>
                    sdi_ready <= key_ready;
                    key_valid <= sdi_valid;
                    key_update <= '1';
                    en_SegLenCnt <= sdi_valid AND key_ready;

                    ---NPUB
                WHEN S_HDR_NPUB =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;
                    IF (pdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_RESNPUB =>
                    pdi_ready <= '1';

                WHEN S_HDR_NPUBLEN_MSB =>
                    pdi_ready <= '1';
                    IF (pdi_valid = '1') THEN
                        nx_dout_LenReg <= data_seg_length(W - 1 DOWNTO W - 8);
                    END IF;

                WHEN S_HDR_NPUBLEN_LSB =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;

                WHEN S_LD_NPUB =>
                    pdi_ready <= bdi_ready;
                    bdi_valid <= pdi_valid;
                    bdi_type <= HDR_NPUB;
                    en_SegLenCnt <= pdi_valid AND bdi_ready;

                    ---AD
                WHEN S_HDR_AD =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;
                    IF (pdi_valid = '1') THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_RESAD =>
                    pdi_ready <= '1';

                WHEN S_HDR_ADLEN_MSB =>
                    pdi_ready <= '1';
                    IF (pdi_valid = '1') THEN
                        nx_dout_LenReg <= data_seg_length(W - 1 DOWNTO W - 8);
                    END IF;

                WHEN S_HDR_ADLEN_LSB =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;

                WHEN S_LD_AD =>
                    pdi_ready <= bdi_ready;
                    bdi_valid <= pdi_valid;
                    bdi_type <= HDR_AD;
                    en_SegLenCnt <= pdi_valid AND bdi_ready;

                    --MSG
                WHEN S_HDR_MSG =>
                    IF (pdi_data(W - 1 DOWNTO W - 4) = HDR_PT OR
                        pdi_data(W - 1 DOWNTO W - 4) = HDR_CT) THEN
                        cmd_valid <= pdi_valid;
                    END IF;
                    pdi_ready <= cmd_ready;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;
                    IF ((pdi_valid = '1') AND (cmd_ready = '1')) THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_RESMSG =>
                    pdi_ready <= cmd_ready;
                    cmd_valid <= pdi_valid;

                WHEN S_HDR_MSGLEN_MSB =>
                    pdi_ready <= cmd_ready;
                    IF ((pdi_valid = '1') AND (cmd_ready = '1')) THEN
                        nx_dout_LenReg <= data_seg_length(W - 1 DOWNTO W - 8);
                    END IF;
                    cmd_valid <= pdi_valid;

                WHEN S_HDR_MSGLEN_LSB =>
                    pdi_ready <= cmd_ready;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;
                    cmd_valid <= pdi_valid;
                WHEN S_LD_MSG =>
                    pdi_ready <= bdi_ready;
                    bdi_valid <= pdi_valid;
                    IF (decrypt_internal = '1') THEN
                        bdi_type <= HDR_CT;
                    ELSE
                        bdi_type <= HDR_PT;
                    END IF;
                    en_SegLenCnt <= pdi_valid AND bdi_ready;

                    --HASH
                WHEN S_HDR_HASH =>
                    pdi_ready <= cmd_ready;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;
                    IF ((pdi_valid = '1') AND (cmd_ready = '1')) THEN
                        nx_eoi_flag <= pdi_data(W - 6);
                        nx_eot_flag <= pdi_data(W - 7);
                    END IF;

                WHEN S_HDR_RESHASH =>
                    pdi_ready <= cmd_ready;

                WHEN S_HDR_HASHLEN_MSB =>
                    pdi_ready <= cmd_ready;
                    IF ((pdi_valid = '1') AND (cmd_ready = '1')) THEN
                        nx_dout_LenReg <= data_seg_length(W - 1 DOWNTO W - 8);
                    END IF;

                WHEN S_HDR_HASHLEN_LSB =>
                    pdi_ready <= cmd_ready;
                    len_SegLenCnt <= pdi_valid AND cmd_ready;

                WHEN S_EMPTY_HASH =>
                    bdi_valid <= '1';
                    bdi_type <= HDR_HASH_MSG;

                WHEN S_LD_HASH =>
                    pdi_ready <= bdi_ready;
                    bdi_valid <= pdi_valid;
                    bdi_type <= HDR_HASH_MSG;
                    en_SegLenCnt <= pdi_valid AND bdi_ready;

                    --TAG
                WHEN S_HDR_TAG =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid AND cmd_ready;

                WHEN S_HDR_RESTAG =>
                    pdi_ready <= '1';

                WHEN S_HDR_TAGLEN_MSB =>
                    pdi_ready <= '1';
                    IF (pdi_valid = '1') THEN
                        nx_dout_LenReg <= data_seg_length(W - 1 DOWNTO W - 8);
                    END IF;

                WHEN S_HDR_TAGLEN_LSB =>
                    pdi_ready <= '1';
                    len_SegLenCnt <= pdi_valid;

                WHEN S_LD_TAG =>
                    bdi_type <= HDR_TAG;
                    IF (decrypt_internal = '1') THEN
                        bdi_valid <= pdi_valid;
                        pdi_ready <= bdi_ready;
                        en_SegLenCnt <= pdi_valid AND bdi_ready;
                    END IF;

                WHEN OTHERS =>
                    NULL;
            END CASE;
        END PROCESS;

    END GENERATE;

END PreProcessor;