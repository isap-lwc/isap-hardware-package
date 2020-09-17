------------------------------------------------------------------------------
--! @file       NIST_LWAPI_pkg.vhd 
--! @brief      NIST lightweight API package
--! @author     Panasayya Yalla & Ekawat (ice) Homsirikamol
--! @copyright  Copyright (c) 2016 Cryptographic Engineering Research Group
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
--! Description
--!
--!
--!
--!
--!
--!
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE NIST_LWAPI_pkg IS

    --! External bus: supported values are 8, 16 and 32 bits
    CONSTANT W : INTEGER := 16;
    CONSTANT SW : INTEGER := W;

    --! Default values for do_data bus
    --! to avoid leaking intermeadiate values if do_valid = '0'.
    CONSTANT do_data_defaults : std_logic_vector(W - 1 DOWNTO 0) := (OTHERS => '0');

    -- DO NOT CHANGE ANYTHING BELOW!
    CONSTANT Wdiv8 : INTEGER := W/8;
    CONSTANT SWdiv8 : INTEGER := SW/8;

    --! INSTRUCTIONS (OPCODES)
    CONSTANT INST_HASH : std_logic_vector(4 - 1 DOWNTO 0) := "1000";
    CONSTANT INST_ENC : std_logic_vector(4 - 1 DOWNTO 0) := "0010";
    CONSTANT INST_DEC : std_logic_vector(4 - 1 DOWNTO 0) := "0011";
    CONSTANT INST_LDKEY : std_logic_vector(4 - 1 DOWNTO 0) := "0100";
    CONSTANT INST_ACTKEY : std_logic_vector(4 - 1 DOWNTO 0) := "0111";
    CONSTANT INST_SUCCESS : std_logic_vector(4 - 1 DOWNTO 0) := "1110";
    CONSTANT INST_FAILURE : std_logic_vector(4 - 1 DOWNTO 0) := "1111";
    --! SEGMENT TYPE ENCODING
    --! Reserved                                                :="0000";
    CONSTANT HDR_AD : std_logic_vector(4 - 1 DOWNTO 0) := "0001";
    CONSTANT HDR_NPUB_AD : std_logic_vector(4 - 1 DOWNTO 0) := "0010";
    CONSTANT HDR_AD_NPUB : std_logic_vector(4 - 1 DOWNTO 0) := "0011";
    CONSTANT HDR_PT : std_logic_vector(4 - 1 DOWNTO 0) := "0100";
    --deprecated! use HDR_PT instead!
    ALIAS HDR_MSG IS HDR_PT;
    CONSTANT HDR_CT : std_logic_vector(4 - 1 DOWNTO 0) := "0101";
    CONSTANT HDR_CT_TAG : std_logic_vector(4 - 1 DOWNTO 0) := "0110";
    CONSTANT HDR_HASH_MSG : std_logic_vector(4 - 1 DOWNTO 0) := "0111";
    CONSTANT HDR_TAG : std_logic_vector(4 - 1 DOWNTO 0) := "1000";
    CONSTANT HDR_HASH_VALUE : std_logic_vector(4 - 1 DOWNTO 0) := "1001";
    --NOT USED in this support package
    CONSTANT Length : std_logic_vector(4 - 1 DOWNTO 0) := "1010";
    --! Reserved                                                :="1011";
    CONSTANT HDR_KEY : std_logic_vector(4 - 1 DOWNTO 0) := "1100";
    CONSTANT HDR_NPUB : std_logic_vector(4 - 1 DOWNTO 0) := "1101";
    --NOT USED in NIST LWC
    CONSTANT HDR_NSEC : std_logic_vector(4 - 1 DOWNTO 0) := "1110";
    --NOT USED in NIST LWC
    CONSTANT HDR_ENSEC : std_logic_vector(4 - 1 DOWNTO 0) := "1111";
    --! Maximum supported length
    --! Length of segment header
    CONSTANT SINGLE_PASS_MAX : INTEGER := 16;
    --! Length of segment header
    CONSTANT TWO_PASS_MAX : INTEGER := 16;

    --! Other
    --! Limit to the segment counter size
    CONSTANT CTR_SIZE_LIM : INTEGER := 16;

    --! =======================================================================
    --! Deprecated parameters from CAESAR-LWAPI! DO NOT CHANGE!
    --! asynchronous reset is not supported
    CONSTANT ASYNC_RSTN : BOOLEAN := FALSE;

    --! =======================================================================
    --! Functions used by LWC Core, PreProcessor and PostProcessor
    --! expands input vector 8 times.
    FUNCTION Byte_To_Bits_EXP (bytes_in : std_logic_vector) RETURN std_logic_vector;

END NIST_LWAPI_pkg;

PACKAGE BODY NIST_LWAPI_pkg IS

    FUNCTION Byte_To_Bits_EXP (
        bytes_in : std_logic_vector
    ) RETURN std_logic_vector IS

        VARIABLE bits : std_logic_vector ((8 * bytes_in'length) - 1 DOWNTO 0);
    BEGIN

        FOR i IN 0 TO bytes_in'length - 1 LOOP
            IF (bytes_in(i) = '1') THEN
                bits(8 * (i + 1) - 1 DOWNTO 8 * i) := (OTHERS => '1');
            ELSE
                bits(8 * (i + 1) - 1 DOWNTO 8 * i) := (OTHERS => '0');
            END IF;
        END LOOP;

        RETURN bits;
    END Byte_To_Bits_EXP;

END NIST_LWAPI_pkg;