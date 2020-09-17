--------------------------------------------------------------------------------
--! @file       design_pkg.vhd
--! @brief      Package for the Cipher Core.
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
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE Design_pkg IS
    TYPE set_selector IS (lwc_8, lwc_16, lwc_32);

    --! Select variant
--    CONSTANT variant : set_selector :=  lwc_8; -- supported by v1, v2, v3, v4
    CONSTANT variant : set_selector := lwc_16; -- supported by v1, v2, v3, v4
--    CONSTANT variant : set_selector := lwc_32; -- supported by v2, v4

	TYPE isap_t IS (
		ISAPA128A,
		ISAPA128,
		ISAPK128A,
		ISAPK128
	);
 ------------------------------------------------------------------------------------------------------------------
    --  _                   _      _ ____  ___          
    -- (_)___  __ _ _ __   | | __ / |___ \( _ )    __ _ 
    -- | / __|/ _` | '_ \  | |/ / | | __) / _ \   / _` |
    -- | \__ \ (_| | |_) | |   <  | |/ __/ (_) | | (_| |
    -- |_|___/\__,_| .__/  |_|\_\ |_|_____\___/   \__,_|
    --             |_|                                  
    -- v1: isapk128av20                                 
    ------------------------------------------------------------------------------------------------------------------
    
    CONSTANT ISAP_TYPE : isap_t := ISAPK128A;
    CONSTANT p_n : INTEGER := 10#400#; -- 400
    CONSTANT p_k : INTEGER := 10#128#; -- 128
    CONSTANT p_sH : std_logic_vector := X"10"; -- 16
    CONSTANT p_sB : std_logic_vector := X"01"; -- 1
    CONSTANT p_sE : std_logic_vector := X"08"; -- 8
    CONSTANT p_sK : std_logic_vector := X"08"; -- 8
    CONSTANT p_rH : INTEGER := 10#144#; -- 144
    CONSTANT p_rB : INTEGER := 10#1#; -- 1
    CONSTANT p_iv_a : std_logic_vector(63 DOWNTO 0) := X"0180900110010808";
    CONSTANT p_iv_ka : std_logic_vector(63 DOWNTO 0) := X"0280900110010808";
    CONSTANT p_iv_ke : std_logic_vector(63 DOWNTO 0) := X"0380900110010808";
 ------------------------------------------------------------------------------------------------------------------
    --  _                           _ ____  ___          
    -- (_)___  __ _ _ __     __ _  / |___ \( _ )    __ _ 
    -- | / __|/ _` | '_ \   / _` | | | __) / _ \   / _` |
    -- | \__ \ (_| | |_) | | (_| | | |/ __/ (_) | | (_| |
    -- |_|___/\__,_| .__/   \__,_| |_|_____\___/   \__,_|
    --             |_|                                   
    -- v2: isapa128av20                                  
    ------------------------------------------------------------------------------------------------------------------
    
--    CONSTANT ISAP_TYPE : isap_t := ISAPA128A;
--    CONSTANT p_sH : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_sB : std_logic_vector := X"01"; -- 1
--    CONSTANT p_sE : std_logic_vector := X"06"; -- 6
--    CONSTANT p_sK : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_n : INTEGER := 10#320#; -- 320
--    CONSTANT p_k : INTEGER := 10#128#; -- 128
--    CONSTANT p_rH : INTEGER := 10#64#; -- 64
--    CONSTANT p_rB : INTEGER := 10#1#; -- 1
--    CONSTANT p_iv_a : std_logic_vector(63 DOWNTO 0) := X"018040010C01060C";
--    CONSTANT p_iv_ka : std_logic_vector(63 DOWNTO 0) := X"028040010C01060C";
--    CONSTANT p_iv_ke : std_logic_vector(63 DOWNTO 0) := X"038040010C01060C";
 ------------------------------------------------------------------------------------------------------------------
    --  _                   _      _ ____  ___  
    -- (_)___  __ _ _ __   | | __ / |___ \( _ ) 
    -- | / __|/ _` | '_ \  | |/ / | | __) / _ \ 
    -- | \__ \ (_| | |_) | |   <  | |/ __/ (_) |
    -- |_|___/\__,_| .__/  |_|\_\ |_|_____\___/ 
    --             |_|                          
    -- v3: isapk128v20                          
    ------------------------------------------------------------------------------------------------------------------
    
--    CONSTANT ISAP_TYPE : isap_t := ISAPK128;
--    CONSTANT p_n : INTEGER := 10#400#; -- 400
--    CONSTANT p_k : INTEGER := 10#128#; -- 128
--    CONSTANT p_sH : std_logic_vector := X"14"; -- 20
--    CONSTANT p_sB : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_sE : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_sK : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_rH : INTEGER := 10#144#; -- 144
--    CONSTANT p_rB : INTEGER := 10#1#; -- 1
--    CONSTANT p_iv_a : std_logic_vector(63 DOWNTO 0) := X"01809001140C0C0C";
--    CONSTANT p_iv_ka : std_logic_vector(63 DOWNTO 0) := X"02809001140C0C0C";
--    CONSTANT p_iv_ke : std_logic_vector(63 DOWNTO 0) := X"03809001140C0C0C";
     ------------------------------------------------------------------------------------------------------------------
    --  _                           _ ____  ___  
    -- (_)___  __ _ _ __     __ _  / |___ \( _ ) 
    -- | / __|/ _` | '_ \   / _` | | | __) / _ \ 
    -- | \__ \ (_| | |_) | | (_| | | |/ __/ (_) |
    -- |_|___/\__,_| .__/   \__,_| |_|_____\___/ 
    --             |_|                           
    -- v4: isapa128v20                              
    ------------------------------------------------------------------------------------------------------------------
    
--    CONSTANT ISAP_TYPE : isap_t := ISAPA128;
--    CONSTANT p_sH : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_sB : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_sE : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_sK : std_logic_vector := X"0C"; -- 12
--    CONSTANT p_n : INTEGER := 10#320#; -- 320
--    CONSTANT p_k : INTEGER := 10#128#; -- 128
--    CONSTANT p_rH : INTEGER := 10#64#; -- 64
--    CONSTANT p_rB : INTEGER := 10#1#; -- 1
--    CONSTANT p_iv_a : std_logic_vector(63 DOWNTO 0) := X"018040010C0C0C0C";
--    CONSTANT p_iv_ka : std_logic_vector(63 DOWNTO 0) := X"028040010C0C0C0C";
--    CONSTANT p_iv_ke : std_logic_vector(63 DOWNTO 0) := X"038040010C0C0C0C";

    --------------------------------------------------------------------------------
    ------------------------- DO NOT CHANGE ANYTHING BELOW -------------------------
    --------------------------------------------------------------------------------
    
    --! design parameters needed by the Pre- and Postprocessor
    CONSTANT TAG_SIZE : INTEGER := 128; --! Tag size
    CONSTANT HASH_VALUE_SIZE : INTEGER := 256; --! Hash value size

    CONSTANT CCSW : INTEGER; --! variant dependent design parameters are assigned in body!
    CONSTANT CCW : INTEGER; --! variant dependent design parameters are assigned in body!
    CONSTANT CCWdiv8 : INTEGER; --! derived from parameters above, assigned in body.
    
    CONSTANT FIFO_ENTRIES : INTEGER;

    --! Functions
    --! Calculate the number of I/O words for a particular size
    FUNCTION get_words(size : INTEGER; iowidth : INTEGER) RETURN INTEGER;
    --! Calculate log2 and round up.
    FUNCTION log2_ceil (N : NATURAL) RETURN NATURAL;
    --! Reverse the Byte order of the input word.
    FUNCTION reverse_byte(vec : std_logic_vector) RETURN std_logic_vector;
    --! Reverse the Bit order of the input vector.
    FUNCTION reverse_bit(vec : std_logic_vector) RETURN std_logic_vector;
    --! Padding the current word.
    FUNCTION padd(bdi, bdi_valid_bytes : std_logic_vector) RETURN std_logic_vector;
    --! Padding the current word.
    FUNCTION mask_zero(bdi, bdi_valid_bytes : std_logic_vector) RETURN std_logic_vector;
    --! Return max value
    FUNCTION max(a, b : INTEGER) RETURN INTEGER;

END Design_pkg;
PACKAGE BODY Design_pkg IS
    -- Package body is not visible to clients of the package.
    -- Variant dependent parameters are assigned here.

    TYPE vector_of_constants_t IS ARRAY (1 TO 2) OF INTEGER; -- two variant dependent constants
    TYPE set_of_vector_of_constants_t IS ARRAY (set_selector) OF vector_of_constants_t;

    CONSTANT set_of_vector_of_constants : set_of_vector_of_constants_t :=
    --   CCW
    --   |   CCSW
    --   |   |
    ((8, 8), -- supported by v1, v2, v3, v4
    (16, 16), -- supported by v1, v2, v3, v4
    (32, 32) -- supported by v2, v4
    );

    ALIAS vector_of_constants IS set_of_vector_of_constants(variant);

    CONSTANT CCW : INTEGER := vector_of_constants(1); --! bdo/bdi width
    CONSTANT CCSW : INTEGER := vector_of_constants(2); --! key width

    -- derived from parameters above
    CONSTANT CCWdiv8 : INTEGER := CCW/8;

    CONSTANT FIFO_ENTRIES : INTEGER := 65536/CCWdiv8; -- 2^16 bytes

    --! Calculate the number of words
    FUNCTION get_words(size : INTEGER; iowidth : INTEGER) RETURN INTEGER IS
    BEGIN
        IF (size MOD iowidth) > 0 THEN
            RETURN size/iowidth + 1;
        ELSE
            RETURN size/iowidth;
        END IF;
    END FUNCTION get_words;

    --! Log of base 2
    FUNCTION log2_ceil (N : NATURAL) RETURN NATURAL IS
    BEGIN
        IF (N = 0) THEN
            RETURN 0;
        ELSIF N <= 2 THEN
            RETURN 1;
        ELSE
            IF (N MOD 2 = 0) THEN
                RETURN 1 + log2_ceil(N/2);
            ELSE
                RETURN 1 + log2_ceil((N + 1)/2);
            END IF;
        END IF;
    END FUNCTION log2_ceil;

    --! Reverse the Byte order of the input word.
    FUNCTION reverse_byte(vec : std_logic_vector) RETURN std_logic_vector IS
        VARIABLE res : std_logic_vector(vec'length - 1 DOWNTO 0);
        CONSTANT n_bytes : INTEGER := vec'length/8;
    BEGIN

        -- Check that vector length is actually byte aligned.
        ASSERT (vec'length MOD 8 = 0)
        REPORT "Vector size must be in multiple of Bytes!" SEVERITY failure;

        -- Loop over every byte of vec and reorder it in res.
        FOR i IN 0 TO (n_bytes - 1) LOOP
            res(8 * (i + 1) - 1 DOWNTO 8 * i) := vec(8 * (n_bytes - i) - 1 DOWNTO 8 * (n_bytes - i - 1));
        END LOOP;

        RETURN res;
    END FUNCTION reverse_byte;

    --! Reverse the Bit order of the input vector.
    FUNCTION reverse_bit(vec : std_logic_vector) RETURN std_logic_vector IS
        VARIABLE res : std_logic_vector(vec'length - 1 DOWNTO 0);
    BEGIN

        -- Loop over every bit in vec and reorder it in res.
        FOR i IN 0 TO (vec'length - 1) LOOP
            res(i) := vec(vec'length - i - 1);
        END LOOP;

        RETURN res;
    END FUNCTION reverse_bit;

    --! Padd the data with 0x80 Byte if pad_loc is set.
    FUNCTION padd(bdi, bdi_valid_bytes : std_logic_vector) RETURN std_logic_vector IS
        VARIABLE res : std_logic_vector(bdi'length - 1 DOWNTO 0) := (OTHERS => '0');
    BEGIN

        FOR i IN 0 TO (bdi_valid_bytes'length - 1) LOOP
            IF (i = 0) THEN
                IF (bdi_valid_bytes(i) = '0') THEN
                    res(8 * (i + 1) - 1 DOWNTO 8 * i) := x"80";
                ELSE
                    res(8 * (i + 1) - 1 DOWNTO 8 * i) := bdi(8 * (i + 1) - 1 DOWNTO 8 * i);
                END IF;
            ELSIF (bdi_valid_bytes(i) = '0' AND bdi_valid_bytes(i - 1) = '1') THEN
                res(8 * (i + 1) - 1 DOWNTO 8 * i) := x"80";
            ELSE
                res(8 * (i + 1) - 1 DOWNTO 8 * i) := bdi(8 * (i + 1) - 1 DOWNTO 8 * i);
            END IF;
        END LOOP;

        RETURN res;
    END FUNCTION;

    --! Set invalid bytes to zero.
    FUNCTION mask_zero(bdi, bdi_valid_bytes : std_logic_vector) RETURN std_logic_vector IS
        VARIABLE res : std_logic_vector(bdi'length - 1 DOWNTO 0) := (OTHERS => '0');
    BEGIN

        FOR i IN 0 TO (bdi_valid_bytes'length - 1) LOOP
            IF (bdi_valid_bytes(i) = '1') THEN
                res(8 * (i + 1) - 1 DOWNTO 8 * i) := bdi(8 * (i + 1) - 1 DOWNTO 8 * i);
            ELSE
                res(8 * (i + 1) - 1 DOWNTO 8 * i) := x"00";
            END IF;
        END LOOP;

        RETURN res;
    END FUNCTION;

    --! Return max value.
    FUNCTION max(a, b : INTEGER) RETURN INTEGER IS
    BEGIN
        IF (a >= b) THEN
            RETURN a;
        ELSE
            RETURN b;
        END IF;
    END FUNCTION;

END PACKAGE BODY Design_pkg;
