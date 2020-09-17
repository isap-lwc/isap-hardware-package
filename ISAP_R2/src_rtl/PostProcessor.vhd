--------------------------------------------------------------------------------
--! @file       PostProcessor.vhd
--! @brief      Post-processor for NIST LWC API
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
--------------------------------------------------------------------------------
--! Description
--!
--!  bdo_type is not used at the moment.
--!  However, we encourage authors to provide it, as it helps to adapt the
--!  CryptoCore to different use cases. Additionally, it might get needed in a
--!  future version of the PostProcessor.
--!
--!  There is no penalty in terms of area, as this signal gets trimmed during
--!  synthesis.
--!
--!
--------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.math_real."ceil";
USE IEEE.math_real."log2";
USE ieee.std_logic_unsigned.ALL;
USE work.NIST_LWAPI_pkg.ALL;
USE work.design_pkg.ALL;

ENTITY PostProcessor IS

    PORT (
        clk : IN std_logic;
        rst : IN std_logic;
        --! Crypto Core ====================================================
        bdo : IN std_logic_vector(CCW - 1 DOWNTO 0);
        bdo_valid : IN std_logic;
        bdo_ready : OUT std_logic;
        end_of_block : IN std_logic;
        bdo_type : IN std_logic_vector(3 DOWNTO 0); -- not used atm
        bdo_valid_bytes : IN std_logic_vector(CCWdiv8 - 1 DOWNTO 0);
        msg_auth : IN std_logic;
        msg_auth_ready : OUT std_logic;
        msg_auth_valid : IN std_logic;
        ---! Header FIFO ===================================================
        cmd : IN std_logic_vector(W - 1 DOWNTO 0);
        cmd_valid : IN std_logic;
        cmd_ready : OUT std_logic;
        --! Data Output (do) ===============================================
        do_data : OUT std_logic_vector(W - 1 DOWNTO 0);
        do_valid : OUT std_logic;
        do_last : OUT std_logic;
        do_ready : IN std_logic
    );

END PostProcessor;

ARCHITECTURE PostProcessor OF PostProcessor IS

    --Signals
    SIGNAL do_data_internal : std_logic_vector(W - 1 DOWNTO 0);
    SIGNAL do_valid_internal : std_logic;
    SIGNAL bdo_cleared : std_logic_vector(CCW - 1 DOWNTO 0);
    SIGNAL len_SegLenCnt : std_logic;
    SIGNAL en_SegLenCnt : std_logic;
    SIGNAL dout_SegLenCnt : std_logic_vector(15 DOWNTO 0);
    SIGNAL load_SegLenCnt : std_logic_vector(15 DOWNTO 0);
    SIGNAL last_flit_of_segment : std_logic;
    --Registers
    SIGNAL decrypt, nx_decrypt : std_logic;
    SIGNAL eot, nx_eot : std_logic;

    --Aliases
    ALIAS cmd_opcode : std_logic_vector(3 DOWNTO 0) IS cmd(W - 1 DOWNTO W - 4);
    ALIAS cmd_seg_length : std_logic_vector((W/2) - 1 DOWNTO 0) IS cmd((W/2) - 1 DOWNTO 0);

    --Constants
    CONSTANT HASHdiv8 : INTEGER := HASH_VALUE_SIZE/8;
    CONSTANT TAGdiv8 : INTEGER := TAG_SIZE/8;
    CONSTANT zero_data : std_logic_vector(W - 1 DOWNTO 0) := (OTHERS => '0');

    --State types for different I/O sizes
    --! State for W=SW=32
    TYPE t_state32 IS (
        S_INIT, S_HDR_HASH_VALUE, S_OUT_HASH_VALUE,
        S_HDR_MSG, S_OUT_MSG, S_HDR_TAG, S_OUT_TAG, S_VER_TAG,
        S_STATUS_FAIL, S_STATUS_SUCCESS
    );

    --! State for W=SW=16               
    TYPE t_state16 IS (
        S_INIT, S_HDR_HASH, S_HDR_HASHLEN, S_OUT_HASH,
        S_HDR_MSG, S_HDR_MSGLEN, S_OUT_MSG,
        S_HDR_TAG, S_HDR_TAGLEN, S_OUT_TAG,
        S_VER_TAG_IN, S_STATUS_FAIL, S_STATUS_SUCCESS
    );

    --! State for W=SW=8
    TYPE t_state8 IS (
        S_INIT, S_HDR_HASH, S_HDR_RESHASH, S_HDR_HASHLEN_MSB,
        S_HDR_HASHLEN_LSB, S_OUT_HASH, S_HDR_MSG, S_HDR_RESMSG,
        S_HDR_MSGLEN_MSB, S_HDR_MSGLEN_LSB, S_OUT_MSG, S_HDR_TAG,
        S_HDR_RESTAG, S_HDR_TAGLEN_MSB, S_HDR_TAGLEN_LSB, S_OUT_TAG,
        S_VER_TAG_IN, S_STATUS_FAIL, S_STATUS_SUCCESS
    );
BEGIN

    -- set unused bytes to zero
    bdo_cleared <= bdo AND Byte_To_Bits_EXP(bdo_valid_bytes);

    -- make sure we do not output intermeadiate data
    do_valid <= do_valid_internal;
    do_data <= do_data_internal WHEN (do_valid_internal = '1') ELSE
        do_data_defaults;
    --! Segment Length Counter
    -- This counter can be saved, if we do not want to support multiple segments
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

    last_flit_of_segment <= '1' WHEN (to_integer(unsigned(dout_SegLenCnt)) <= Wdiv8) ELSE
        '0';

    --! Registers
    -- state register depends on W and is set in the corresponding if generate
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            eot <= nx_eot;
            decrypt <= nx_decrypt;
        END IF;
    END PROCESS;

    -- ====================================================================================================
    --! 32 bit specific FSM -------------------------------------------------------------------------------
    -- ====================================================================================================

    FSM_32BIT : IF (W = 32) GENERATE

        --! 32 Bit specific declarations
        ALIAS do_data_internal_opcode : std_logic_vector(3 DOWNTO 0) IS do_data_internal(31 DOWNTO 28);
        ALIAS do_data_internal_flags : std_logic_vector(3 DOWNTO 0) IS do_data_internal(27 DOWNTO 24);
        ALIAS do_data_internal_reserved : std_logic_vector(7 DOWNTO 0) IS do_data_internal(23 DOWNTO 16);
        ALIAS do_data_internal_length : std_logic_vector(15 DOWNTO 0) IS do_data_internal(15 DOWNTO 0);

        --sipo
        SIGNAL bdo_valid_p : std_logic;
        SIGNAL bdo_ready_p : std_logic;
        SIGNAL bdo_p : std_logic_vector(31 DOWNTO 0);

        SIGNAL nx_state, pr_state : t_state32;

    BEGIN

        load_SegLenCnt <= cmd_seg_length;

        --! SIPO
        -- for ccw < W: a sipo is used for width conversion
        bdoSIPO : ENTITY work.data_sipo(behavioral) PORT MAP
            (
            clk => clk,
            rst => rst,
            -- no need for conversion, as our last serial_in element is also the
            -- last parallel_out element
            end_of_input => end_of_block,
            -- end_of_bock should only be evaluated if bdo_valid_p = '1'
            data_s => bdo_cleared,
            data_valid_s => bdo_valid,
            data_ready_s => bdo_ready,

            data_p => bdo_p,
            data_valid_p => bdo_valid_p,
            data_ready_p => bdo_ready_p
            );

        --! State register
        PROCESS (clk)
        BEGIN
            IF rising_edge(clk) THEN
                IF (rst = '1') THEN
                    pr_state <= S_INIT;
                ELSE
                    pr_state <= nx_state;
                END IF;
            END IF;
        END PROCESS;
        --! Next state function
        PROCESS (pr_state, bdo_valid_p, do_ready, end_of_block, decrypt,
            cmd_valid, msg_auth_valid, msg_auth, last_flit_of_segment,
            cmd_opcode, eot, nx_decrypt)

        BEGIN
            CASE pr_state IS

                WHEN S_INIT =>
                    IF (cmd_valid = '1') THEN
                        IF (cmd_opcode = INST_HASH) THEN
                            nx_state <= S_HDR_HASH_VALUE;
                        ELSE
                            IF (nx_decrypt = '1') THEN
                                nx_state <= S_VER_TAG;
                            ELSE
                                nx_state <= S_HDR_MSG;
                            END IF;
                        END IF;
                    ELSE
                        nx_state <= S_INIT;
                    END IF;

                    --Hash
                WHEN S_HDR_HASH_VALUE =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_OUT_HASH_VALUE;
                    ELSE
                        nx_state <= S_HDR_HASH_VALUE;
                    END IF;

                WHEN S_OUT_HASH_VALUE =>
                    IF (bdo_valid_p = '1' AND do_ready = '1' AND end_of_block = '1') THEN
                        nx_state <= S_STATUS_SUCCESS;
                    ELSE
                        nx_state <= S_OUT_HASH_VALUE;
                    END IF;

                    --MSG
                WHEN S_HDR_MSG =>
                    IF (cmd_valid = '1' AND do_ready = '1') THEN
                        IF (cmd_seg_length = x"0000") THEN
                            IF (decrypt = '1') THEN
                                nx_state <= S_STATUS_SUCCESS;
                            ELSE
                                nx_state <= S_HDR_TAG;
                            END IF;
                        ELSE
                            nx_state <= S_OUT_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_MSG;
                    END IF;

                WHEN S_OUT_MSG =>
                    IF (bdo_valid_p = '1' AND do_ready = '1') THEN
                        -- This line is needed, if the input (and therefore) the
                        -- output is splitted in multiple segments.
                        IF (last_flit_of_segment = '1') THEN
                            -- This line can be used instead, if there is only one 
                            -- input segment and there is no ciphertext expansion.
                            -- This saves us the output counter.
                            --if (end_of_block = '1') then

                            -- this is the last segment
                            IF (eot = '1') THEN
                                IF (decrypt = '1') THEN
                                    nx_state <= S_STATUS_SUCCESS;
                                ELSE
                                    nx_state <= S_HDR_TAG;
                                END IF;
                            ELSE
                                -- this is not the last segment, we have multiple segments
                                nx_state <= S_HDR_MSG;
                            END IF;
                        ELSE
                            -- more output in current segment
                            nx_state <= S_OUT_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_OUT_MSG;
                    END IF;

                    --TAG
                WHEN S_HDR_TAG =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_OUT_TAG;
                    ELSE
                        nx_state <= S_HDR_TAG;
                    END IF;

                WHEN S_OUT_TAG =>
                    IF (bdo_valid_p = '1' AND end_of_block = '1' AND do_ready = '1') THEN
                        nx_state <= S_STATUS_SUCCESS;
                    ELSE
                        nx_state <= S_OUT_TAG;
                    END IF;

                WHEN S_VER_TAG =>
                    IF (msg_auth_valid = '1') THEN
                        IF (msg_auth = '1') THEN
                            nx_state <= S_HDR_MSG;
                        ELSE
                            nx_state <= S_STATUS_FAIL;
                        END IF;
                    ELSE
                        nx_state <= S_VER_TAG;
                    END IF;

                    -- STATUS
                WHEN S_STATUS_FAIL =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_INIT;
                    ELSE
                        nx_state <= S_STATUS_FAIL;
                    END IF;

                WHEN S_STATUS_SUCCESS =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_INIT;
                    ELSE
                        nx_state <= S_STATUS_SUCCESS;
                    END IF;

                WHEN OTHERS =>
                    nx_state <= pr_state;
            END CASE;
        END PROCESS;
        --! Output state function
        PROCESS (pr_state, bdo_valid_p, bdo_p, decrypt, eot, cmd, cmd_valid, do_ready)
        BEGIN
            -- DEFAULT SIGNALS
            -- external interface
            do_last <= '0';
            do_data_internal <= (OTHERS => '-');
            do_valid_internal <= '0';
            -- CryptoCore
            bdo_ready_p <= '0';
            msg_auth_ready <= '0';
            -- Header-FIFO
            cmd_ready <= '0';
            -- Segment counter
            len_SegLenCnt <= '0';
            en_SegLenCnt <= '0';
            -- Registers
            nx_decrypt <= decrypt;
            nx_eot <= eot;

            CASE pr_state IS
                WHEN S_INIT =>

                    IF (cmd_valid = '1') THEN
                        -- We reiceive either INST_HASH, or INST_ENC or INST_DEC
                        -- The LSB of INST_ENC and INST_DEC is '1' for Decryption
                        -- For Hash, this bit is '0', however we never evaluate
                        -- "decrypt" for Hash.
                        nx_decrypt <= cmd(28);
                    END IF;

                    cmd_ready <= '1';

                    --MSG
                WHEN S_HDR_MSG =>
                    cmd_ready <= do_ready;
                    len_SegLenCnt <= do_ready AND cmd_valid;
                    do_valid_internal <= cmd_valid;
                    -- preserve EOT flag to support multi segment MSGs
                    nx_eot <= cmd(25);

                    IF (decrypt = '1') THEN
                        -- header is plaintext
                        do_data_internal_opcode <= HDR_PT;

                        -- last: no TAG is sent after decryption.
                        -- If cmd(25) = '0' (EOT ='0') then we have multiple segments,
                        -- and this is not the last one.
                        do_data_internal_flags(0) <= '1' AND cmd(25);
                    ELSE
                        -- header is ciphertext
                        do_data_internal_opcode <= HDR_CT;
                        -- last: we will send a TAG afterwards, this is never
                        -- the last segment.
                        do_data_internal_flags(0) <= '0';
                    END IF;

                    do_data_internal_flags(3) <= '0'; -- Partial = '0',
                    -- XXX: The definition for EOI is not intuitive for data out.
                    --      At the moment, EOI is defined to be '0'.
                    --      However, this might be change to '1' in the future!
                    do_data_internal_flags(2) <= '0'; --EOI
                    do_data_internal_flags(1) <= cmd(25); --EOT

                    -- reserved not used.
                    do_data_internal_reserved <= (OTHERS => '0');
                    -- length forwarded from the cmd FIFO
                    do_data_internal_length <= cmd(15 DOWNTO 0);

                WHEN S_OUT_MSG =>
                    bdo_ready_p <= do_ready;
                    do_valid_internal <= bdo_valid_p;
                    do_data_internal <= bdo_p;
                    en_SegLenCnt <= bdo_valid_p AND do_ready;

                    --TAG
                WHEN S_HDR_TAG =>
                    do_valid_internal <= '1';
                    do_data_internal_opcode <= HDR_TAG;
                    -- Partial = '0', EOI ='0', EOT = '1', Last = '1':
                    -- No tag is larger than 2^(16-1) bytes
                    do_data_internal_flags <= "0011";
                    do_data_internal_reserved <= (OTHERS => '0'); --reserved not used.
                    do_data_internal_length <= std_logic_vector(to_unsigned(TAGdiv8, 16));

                WHEN S_OUT_TAG =>
                    bdo_ready_p <= do_ready;
                    do_valid_internal <= bdo_valid_p;
                    do_data_internal <= bdo_p;

                WHEN S_VER_TAG =>
                    msg_auth_ready <= '1';

                    --HASH-VALUE
                WHEN S_HDR_HASH_VALUE =>
                    do_valid_internal <= '1';
                    do_data_internal_opcode <= HDR_HASH_VALUE;
                    -- Partial = '0', EOI ='0', EOT = '1', LAST = '1':
                    -- No tag is larger than 2^(16-1) bytes
                    do_data_internal_flags <= "0011";
                    do_data_internal_reserved <= (OTHERS => '0'); -- reserved not used
                    do_data_internal_length <= std_logic_vector(to_unsigned(HASHdiv8, 16));

                WHEN S_OUT_HASH_VALUE =>
                    bdo_ready_p <= do_ready;
                    do_valid_internal <= bdo_valid_p;
                    do_data_internal <= bdo_p;

                    --STATUS
                WHEN S_STATUS_FAIL =>
                    do_valid_internal <= '1';
                    -- do_last must only be asserted together with do_valid(_internal)
                    do_last <= '1';
                    do_data_internal_opcode <= INST_FAILURE;
                    do_data_internal(27 DOWNTO 0) <= (OTHERS => '0');

                WHEN S_STATUS_SUCCESS =>
                    do_valid_internal <= '1';
                    -- do_last must only be asserted together with do_valid(_internal)
                    do_last <= '1';
                    do_data_internal_opcode <= INST_SUCCESS;
                    do_data_internal(27 DOWNTO 0) <= (OTHERS => '0');

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
        SIGNAL nx_state, pr_state : t_state16;
        SIGNAL HDR_TAG_internal : std_logic_vector(31 DOWNTO 0);
        SIGNAL data_seg_length : std_logic_vector(W - 1 DOWNTO 0);
        SIGNAL tag_size_bytes : std_logic_vector(16 - 1 DOWNTO 0);

    BEGIN

        --! Logics
        data_seg_length <= cmd;
        tag_size_bytes <= std_logic_vector(to_unsigned(TAGdiv8, 16));
        load_SegLenCnt <= data_seg_length(W - 1 DOWNTO W - 8 * Wdiv8);
        HDR_TAG_internal <= HDR_TAG & x"300" & tag_size_bytes(15 DOWNTO 0);

        --! State register
        PROCESS (clk)
        BEGIN
            IF rising_edge(clk) THEN
                IF (rst = '1') THEN
                    pr_state <= S_INIT;
                ELSE
                    pr_state <= nx_state;
                END IF;
            END IF;
        END PROCESS;

        --! Next state function
        PROCESS (pr_state, bdo_valid, do_ready, end_of_block, decrypt,
            cmd_valid, cmd, msg_auth_valid, msg_auth, last_flit_of_segment,
            eot, tag_size_bytes, nx_decrypt)

        BEGIN
            CASE pr_state IS

                WHEN S_INIT =>
                    IF (cmd_valid = '1') THEN
                        IF (cmd(W - 1 DOWNTO W - 4) = INST_HASH) THEN
                            nx_state <= S_HDR_HASH;
                        ELSE
                            --nx_state <= S_HDR_MSG;
                            IF (nx_decrypt = '1') THEN
                                -- During dec start with tag verification 
                                nx_state <= S_VER_TAG_IN;
                            ELSE
                                -- During enc start with msg verification 
                                nx_state <= S_HDR_MSG;
                            END IF;
                        END IF;
                    ELSE
                        nx_state <= S_INIT;
                    END IF;

                WHEN S_HDR_HASH =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_HDR_HASHLEN;
                    ELSE
                        nx_state <= S_HDR_HASH;
                    END IF;

                WHEN S_HDR_HASHLEN =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_OUT_HASH;
                    ELSE
                        nx_state <= S_HDR_HASHLEN;
                    END IF;

                WHEN S_OUT_HASH =>
                    IF (bdo_valid = '1' AND do_ready = '1' AND end_of_block = '1') THEN
                        nx_state <= S_STATUS_SUCCESS;
                    ELSE
                        nx_state <= S_OUT_HASH;
                    END IF;

                WHEN S_HDR_MSG =>
                    IF (cmd_valid = '1' AND do_ready = '1') THEN
                        nx_state <= S_HDR_MSGLEN;
                    ELSE
                        nx_state <= S_HDR_MSG;
                    END IF;

                WHEN S_HDR_MSGLEN =>
                    IF (cmd = zero_data AND cmd_valid = '1' AND do_ready = '1') THEN
                        IF (decrypt = '1') THEN
                            nx_state <= S_STATUS_SUCCESS;
                        ELSE
                            nx_state <= S_HDR_TAG;
                        END IF;
                    ELSIF (cmd_valid = '1' AND do_ready = '1') THEN
                        nx_state <= S_OUT_MSG;
                    ELSE
                        nx_state <= S_HDR_MSGLEN;
                    END IF;

                WHEN S_OUT_MSG =>
                    IF (bdo_valid = '1' AND do_ready = '1') THEN
                        IF (last_flit_of_segment = '1') THEN
                            IF (eot = '1') THEN
                                IF (decrypt = '1') THEN -- fix me: decrypt or nx_decrypt
                                    nx_state <= S_STATUS_SUCCESS; -- fix me: correct?
                                ELSE
                                    nx_state <= S_HDR_TAG;
                                END IF;
                            ELSE
                                nx_state <= S_HDR_MSG;
                            END IF;
                        ELSE
                            nx_state <= S_OUT_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_OUT_MSG;
                    END IF;

                    --TAG
                WHEN S_HDR_TAG =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_HDR_TAGLEN;
                    ELSE
                        nx_state <= S_HDR_TAG;
                    END IF;

                WHEN S_HDR_TAGLEN =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_OUT_TAG;
                    ELSE
                        nx_state <= S_HDR_TAGLEN;
                    END IF;

                WHEN S_OUT_TAG =>
                    IF (bdo_valid = '1' AND end_of_block = '1' AND do_ready = '1') THEN
                        nx_state <= S_STATUS_SUCCESS;
                    ELSE
                        nx_state <= S_OUT_TAG;
                    END IF;

                WHEN S_VER_TAG_IN =>
                    IF (msg_auth_valid = '1') THEN
                        IF (msg_auth = '1') THEN
                            IF (nx_decrypt = '1') THEN
                                nx_state <= S_HDR_MSG;
                            ELSE
                                nx_state <= S_STATUS_SUCCESS;-- fix me ? go to out tag? does this even happen?
                            END IF;
                        ELSE
                            nx_state <= S_STATUS_FAIL;
                        END IF;
                    ELSE
                        nx_state <= S_VER_TAG_IN;
                    END IF;

                WHEN S_STATUS_FAIL =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_INIT;
                    ELSE
                        nx_state <= S_STATUS_FAIL;
                    END IF;

                WHEN S_STATUS_SUCCESS =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_INIT;
                    ELSE
                        nx_state <= S_STATUS_SUCCESS;
                    END IF;

                WHEN OTHERS =>
                    nx_state <= S_INIT;
            END CASE;
        END PROCESS;

        --! Output state function
        PROCESS (pr_state, bdo_valid, end_of_block, msg_auth_valid, msg_auth,
            decrypt, cmd, cmd_valid, do_ready, eot, tag_size_bytes, HDR_TAG_internal,
            bdo_cleared)
        BEGIN
            -- DEFAULT Values
            -- external interface
            do_last <= '0';
            do_valid_internal <= '0';
            do_data_internal <= (OTHERS => '-');
            -- CryptoCore
            bdo_ready <= '0';
            msg_auth_ready <= '0';
            -- Header-FIFO
            cmd_ready <= '0';
            -- Segment counter
            len_SegLenCnt <= '0';
            en_SegLenCnt <= '0';
            --Registers
            nx_eot <= eot;
            nx_decrypt <= decrypt;

            CASE pr_state IS

                WHEN S_INIT =>
                    IF (cmd_valid = '1') THEN
                        nx_decrypt <= cmd(W - 4);
                    END IF;
                    cmd_ready <= '1';
                    nx_eot <= '0';

                    --HASH
                WHEN S_HDR_HASH =>
                    do_valid_internal <= '1';
                    do_data_internal(W - 1 DOWNTO W - 4) <= HDR_HASH_VALUE;
                    do_data_internal(W - 5 DOWNTO W - 7) <= "001";
                    do_data_internal(W - 8) <= '1';
                    do_data_internal(W - 9 DOWNTO 0) <= x"00";
                WHEN S_HDR_HASHLEN =>
                    do_valid_internal <= '1';
                    do_data_internal <= std_logic_vector(to_unsigned(HASHdiv8, 16));

                WHEN S_OUT_HASH =>
                    bdo_ready <= do_ready;
                    do_valid_internal <= bdo_valid;
                    do_data_internal <= bdo_cleared;

                    --MSG
                WHEN S_HDR_MSG =>
                    cmd_ready <= do_ready;
                    do_valid_internal <= cmd_valid;
                    len_SegLenCnt <= do_ready AND cmd_valid;
                    nx_eot <= cmd(W - 7);

                    IF (decrypt = '1') THEN
                        --header is msg
                        do_data_internal(W - 1 DOWNTO W - 4) <= HDR_PT;
                        do_data_internal(W - 8) <= '1' AND cmd(W - 7);
                    ELSE
                        ---header is ciphertext
                        do_data_internal(W - 1 DOWNTO W - 4) <= HDR_CT;
                        do_data_internal(W - 8) <= '0';
                    END IF;

                    do_data_internal(W - 5) <= '0';
                    do_data_internal(W - 6) <= '0';
                    do_data_internal(W - 7) <= cmd(W - 7);
                    do_data_internal(W - 1 - Wdiv8 * 4 DOWNTO 0) <= cmd(W - 1 - Wdiv8 * 4 DOWNTO 0);

                WHEN S_HDR_MSGLEN =>
                    cmd_ready <= do_ready;
                    len_SegLenCnt <= do_ready AND cmd_valid;
                    do_valid_internal <= cmd_valid;
                    do_data_internal <= cmd;

                WHEN S_OUT_MSG =>
                    bdo_ready <= do_ready;
                    do_valid_internal <= bdo_valid;
                    en_SegLenCnt <= bdo_valid AND do_ready;
                    do_data_internal <= bdo_cleared;

                    --TAG
                WHEN S_HDR_TAG =>
                    do_valid_internal <= '1';
                    do_data_internal(W - 1 DOWNTO 0) <= HDR_TAG_internal(31 DOWNTO 32 - W);

                WHEN S_HDR_TAGLEN =>
                    do_valid_internal <= '1';
                    do_data_internal(W - 1 DOWNTO W - Wdiv8 * 8) <= tag_size_bytes(W - 1 DOWNTO W - Wdiv8 * 8);

                WHEN S_OUT_TAG =>
                    bdo_ready <= do_ready;
                    do_valid_internal <= bdo_valid;
                    do_data_internal <= bdo_cleared;

                WHEN S_VER_TAG_IN =>
                    msg_auth_ready <= '1';

                WHEN S_STATUS_FAIL =>
                    do_valid_internal <= '1';
                    do_last <= '1';
                    do_data_internal(W - 1 DOWNTO W - 4) <= "1111";
                    do_data_internal(W - 5 DOWNTO 0) <= (OTHERS => '0');

                WHEN S_STATUS_SUCCESS =>
                    do_valid_internal <= '1';
                    do_last <= '1';
                    do_data_internal(W - 1 DOWNTO W - 4) <= "1110";
                    do_data_internal(W - 5 DOWNTO 0) <= (OTHERS => '0');
                WHEN OTHERS =>
                    NULL;

            END CASE;
        END PROCESS;

    END GENERATE;

    -- ====================================================================================================
    --!  8 bit specific FSM -------------------------------------------------------------------------------
    -- ====================================================================================================

    FSM_8BIT : IF (W = 8) GENERATE

        --! 8 Bit specific declarations
        SIGNAL HDR_TAG_internal : std_logic_vector(31 DOWNTO 0);
        SIGNAL data_seg_length : std_logic_vector(W - 1 DOWNTO 0);
        SIGNAL tag_size_bytes : std_logic_vector(16 - 1 DOWNTO 0);
        SIGNAL do_data_t16 : std_logic_vector(16 - 1 DOWNTO 0);
        --Registers
        SIGNAL nx_state, pr_state : t_state8;
        SIGNAL dout_LenReg, nx_dout_LenReg : std_logic_vector(8 - 1 DOWNTO 0);
    BEGIN

        --! Logics
        data_seg_length <= cmd;
        tag_size_bytes <= std_logic_vector(to_unsigned(TAGdiv8, 16));
        load_SegLenCnt <= dout_LenReg(7 DOWNTO 0) & data_seg_length(W - 1 DOWNTO W - 8);
        do_data_t16 <= std_logic_vector(to_unsigned(HASHdiv8, 16));
        HDR_TAG_internal <= HDR_TAG & x"300" & tag_size_bytes(15 DOWNTO 0);

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
            IF rising_edge(clk) THEN
                IF (rst = '1') THEN
                    pr_state <= S_INIT;
                ELSE
                    pr_state <= nx_state;
                END IF;
            END IF;
        END PROCESS;

        --! Next state function
        PROCESS (pr_state, bdo_valid, do_ready, end_of_block, decrypt,
            cmd_valid, cmd, msg_auth_valid, msg_auth, last_flit_of_segment,
            dout_LenReg, eot, nx_decrypt)

        BEGIN

            CASE pr_state IS

                WHEN S_INIT =>
                    IF (cmd_valid = '1') THEN
                        IF (cmd(W - 1 DOWNTO W - 4) = INST_HASH) THEN
                            nx_state <= S_HDR_HASH;
                        ELSE
                            --nx_state <= S_HDR_MSG;
                            IF (nx_decrypt = '1') THEN
                                -- During dec start with tag verification 
                                nx_state <= S_VER_TAG_IN;
                            ELSE
                                -- During enc start with msg verification 
                                nx_state <= S_HDR_MSG;
                            END IF;
                        END IF;
                    ELSE
                        nx_state <= S_INIT;
                    END IF;

                WHEN S_HDR_HASH =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_HDR_RESHASH;
                    ELSE
                        nx_state <= S_HDR_HASH;
                    END IF;

                WHEN S_HDR_RESHASH =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_HDR_HASHLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESHASH;
                    END IF;

                WHEN S_HDR_HASHLEN_MSB =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_HDR_HASHLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_HASHLEN_MSB;
                    END IF;

                WHEN S_HDR_HASHLEN_LSB =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_OUT_HASH;
                    ELSE
                        nx_state <= S_HDR_HASHLEN_LSB;
                    END IF;

                WHEN S_OUT_HASH =>
                    IF (bdo_valid = '1' AND do_ready = '1' AND end_of_block = '1') THEN
                        nx_state <= S_STATUS_SUCCESS;
                    ELSE
                        nx_state <= S_OUT_HASH;
                    END IF;

                WHEN S_HDR_MSG =>
                    IF (cmd_valid = '1' AND do_ready = '1') THEN
                        nx_state <= S_HDR_RESMSG;
                    ELSE
                        nx_state <= S_HDR_MSG;
                    END IF;

                WHEN S_HDR_RESMSG =>
                    IF (cmd_valid = '1' AND do_ready = '1') THEN
                        nx_state <= S_HDR_MSGLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESMSG;
                    END IF;

                WHEN S_HDR_MSGLEN_MSB =>
                    IF (cmd_valid = '1' AND do_ready = '1') THEN
                        nx_state <= S_HDR_MSGLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_MSGLEN_MSB;
                    END IF;

                WHEN S_HDR_MSGLEN_LSB =>
                    IF (dout_LenReg = x"00" AND cmd(7 DOWNTO 0) = x"00" AND do_ready = '1' AND cmd_valid = '1') THEN
                        IF (decrypt = '1') THEN
                            nx_state <= S_STATUS_SUCCESS;---- fix me?
                        ELSE
                            nx_state <= S_HDR_TAG;
                        END IF;
                    ELSIF (cmd_valid = '1' AND do_ready = '1') THEN
                        IF (decrypt = '1') THEN
                            nx_state <= S_OUT_MSG;
                        ELSE
                            nx_state <= S_OUT_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_HDR_MSGLEN_LSB;
                    END IF;

                WHEN S_OUT_MSG =>
                    IF (bdo_valid = '1' AND do_ready = '1') THEN
                        IF (last_flit_of_segment = '1') THEN
                            IF (eot = '1') THEN
                                IF (decrypt = '1') THEN
                                    --nx_state <= S_VER_TAG_IN;
                                    nx_state <= S_STATUS_SUCCESS; -- fix me: correct?
                                ELSE
                                    nx_state <= S_HDR_TAG;
                                END IF;
                            ELSE
                                nx_state <= S_HDR_MSG;
                            END IF;
                        ELSE
                            nx_state <= S_OUT_MSG;
                        END IF;
                    ELSE
                        nx_state <= S_OUT_MSG;
                    END IF;

                    --TAG
                WHEN S_HDR_TAG =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_HDR_RESTAG;
                    ELSE
                        nx_state <= S_HDR_TAG;
                    END IF;

                WHEN S_HDR_RESTAG =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_HDR_TAGLEN_MSB;
                    ELSE
                        nx_state <= S_HDR_RESTAG;
                    END IF;

                WHEN S_HDR_TAGLEN_MSB =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_HDR_TAGLEN_LSB;
                    ELSE
                        nx_state <= S_HDR_TAGLEN_MSB;
                    END IF;

                WHEN S_HDR_TAGLEN_LSB =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_OUT_TAG;
                    ELSE
                        nx_state <= S_HDR_TAGLEN_LSB;
                    END IF;

                WHEN S_OUT_TAG =>
                    IF (bdo_valid = '1' AND end_of_block = '1' AND do_ready = '1') THEN
                        nx_state <= S_STATUS_SUCCESS;
                    ELSE
                        nx_state <= S_OUT_TAG;
                    END IF;

                WHEN S_VER_TAG_IN =>
                    IF (msg_auth_valid = '1') THEN
                        IF (msg_auth = '1') THEN
                            --nx_state <= S_STATUS_SUCCESS;
                            IF (decrypt = '1') THEN
                                nx_state <= S_HDR_MSG;
                            ELSE
                                nx_state <= S_STATUS_SUCCESS;-- fix me ? go to out tag? does this even happen?
                            END IF;
                        ELSE
                            nx_state <= S_STATUS_FAIL;
                        END IF;
                    ELSE
                        nx_state <= S_VER_TAG_IN;
                    END IF;

                WHEN S_STATUS_FAIL =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_INIT;
                    ELSE
                        nx_state <= S_STATUS_FAIL;
                    END IF;

                WHEN S_STATUS_SUCCESS =>
                    IF (do_ready = '1') THEN
                        nx_state <= S_INIT;
                    ELSE
                        nx_state <= S_STATUS_SUCCESS;
                    END IF;
                WHEN OTHERS =>
                    nx_state <= S_INIT;
            END CASE;
        END PROCESS;

        --! Output state function
        PROCESS (pr_state, bdo_valid, end_of_block, msg_auth_valid, msg_auth,
            decrypt, cmd, cmd_valid, do_ready, eot, dout_LenReg, bdo_cleared,
            do_data_t16, HDR_TAG_internal, tag_size_bytes, data_seg_length)
        BEGIN
            -- DEFAULT Values
            -- external interface
            do_last <= '0';
            do_valid_internal <= '0';
            do_data_internal <= (OTHERS => '-');
            -- Ciphercore
            bdo_ready <= '0';
            msg_auth_ready <= '0';
            --Header/tag-FIFO
            cmd_ready <= '0';
            -- Segment counter
            len_SegLenCnt <= '0';
            en_SegLenCnt <= '0';
            -- Registers
            nx_eot <= eot;
            nx_decrypt <= decrypt;
            nx_dout_LenReg <= dout_LenReg;

            CASE pr_state IS

                WHEN S_INIT =>
                    IF (cmd_valid = '1') THEN
                        nx_decrypt <= cmd(W - 4);
                    END IF;
                    cmd_ready <= '1';
                    nx_eot <= '0';

                    --HASH
                WHEN S_HDR_HASH =>
                    do_valid_internal <= '1';
                    do_data_internal(W - 1 DOWNTO W - 4) <= HDR_HASH_VALUE;
                    do_data_internal(W - 5 DOWNTO W - 7) <= "001";
                    do_data_internal(W - 8) <= '1';

                WHEN S_HDR_RESHASH =>
                    do_valid_internal <= '1';
                    do_data_internal <= x"00";

                WHEN S_HDR_HASHLEN_MSB =>
                    do_valid_internal <= '1';
                    do_data_internal <= do_data_t16(15 DOWNTO 8);

                WHEN S_HDR_HASHLEN_LSB =>
                    do_valid_internal <= '1';
                    do_data_internal <= do_data_t16(7 DOWNTO 0);

                WHEN S_OUT_HASH =>
                    bdo_ready <= do_ready;
                    do_valid_internal <= bdo_valid;
                    do_data_internal <= bdo_cleared;

                    --!MSG/CT
                WHEN S_HDR_MSG =>
                    cmd_ready <= do_ready;
                    do_valid_internal <= cmd_valid;
                    len_SegLenCnt <= do_ready AND cmd_valid;
                    nx_eot <= cmd(W - 7);
                    IF (decrypt = '1') THEN
                        --header is msg
                        do_data_internal(W - 1 DOWNTO W - 4) <= HDR_PT;
                        do_data_internal(W - 8) <= '1' AND cmd(W - 7);
                    ELSE
                        ---header is ciphertext
                        do_data_internal(W - 1 DOWNTO W - 4) <= HDR_CT;
                        do_data_internal(W - 8) <= '0';
                    END IF;
                    do_data_internal(W - 5) <= '0';
                    do_data_internal(W - 6) <= '0';
                    do_data_internal(W - 7) <= cmd(W - 7);

                WHEN S_HDR_RESMSG =>
                    cmd_ready <= do_ready;
                    do_valid_internal <= cmd_valid;
                    do_data_internal <= cmd;

                WHEN S_HDR_MSGLEN_MSB =>
                    cmd_ready <= do_ready;
                    IF ((do_ready = '1') AND (cmd_valid = '1')) THEN
                        nx_dout_LenReg <= data_seg_length(W - 1 DOWNTO W - 8);
                    END IF;
                    do_valid_internal <= cmd_valid;
                    do_data_internal <= cmd;

                WHEN S_HDR_MSGLEN_LSB =>
                    cmd_ready <= do_ready;
                    len_SegLenCnt <= do_ready AND cmd_valid;
                    do_valid_internal <= cmd_valid;
                    do_data_internal <= cmd;

                WHEN S_OUT_MSG =>
                    bdo_ready <= do_ready;
                    do_valid_internal <= bdo_valid;
                    en_SegLenCnt <= bdo_valid AND do_ready;
                    do_data_internal <= bdo_cleared;

                    --TAG
                WHEN S_HDR_TAG =>
                    do_valid_internal <= '1';
                    do_data_internal(W - 1 DOWNTO 0) <= HDR_TAG_internal(31 DOWNTO 32 - W);

                WHEN S_HDR_RESTAG =>
                    do_valid_internal <= '1';
                    do_data_internal <= (OTHERS => '0');

                WHEN S_HDR_TAGLEN_MSB =>
                    do_valid_internal <= '1';
                    do_data_internal(W - 1 DOWNTO W - 8) <= tag_size_bytes(15 DOWNTO 8);

                WHEN S_HDR_TAGLEN_LSB =>
                    do_valid_internal <= '1';
                    do_data_internal(W - 1 DOWNTO W - 8) <= tag_size_bytes(7 DOWNTO 0);

                WHEN S_OUT_TAG =>
                    bdo_ready <= do_ready;
                    do_valid_internal <= bdo_valid;
                    do_data_internal <= bdo_cleared;

                WHEN S_VER_TAG_IN =>
                    msg_auth_ready <= '1';

                WHEN S_STATUS_FAIL =>
                    do_valid_internal <= '1';
                    do_last <= '1';
                    do_data_internal(W - 1 DOWNTO W - 4) <= "1111";
                    do_data_internal(W - 5 DOWNTO 0) <= (OTHERS => '0');

                WHEN S_STATUS_SUCCESS =>
                    do_valid_internal <= '1';
                    do_last <= '1';
                    do_data_internal(W - 1 DOWNTO W - 4) <= "1110";
                    do_data_internal(W - 5 DOWNTO 0) <= (OTHERS => '0');

                WHEN OTHERS =>
                    NULL;

            END CASE;
        END PROCESS;

    END GENERATE;

END PostProcessor;