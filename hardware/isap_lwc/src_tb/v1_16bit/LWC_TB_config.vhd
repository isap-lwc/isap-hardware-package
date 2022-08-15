--===============================================================================================--
--! @file       LWC_config.vhd
--! @brief      LWC testbench configuration.
--!
--! @author     Robert Primas
--!
--! @copyright  Copyright (c) 2022 IAIK, Graz University of Technology, AUSTRIA
--!             All rights Reserved.
--!
--! @license    This project is released under the GNU Public License.          
--!             The license and distribution terms for this file may be         
--!             found in the file LICENSE in this distribution or at            
--!             http://www.gnu.org/licenses/gpl-3.0.txt        
--!
--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package LWC_TB_config is

    CONSTANT G_FNAME_PDI : string   := "KAT/v1_16bit/pdi.txt"; -- ! Path to the input file containing cryptotvgen PDI testvector data
    CONSTANT G_FNAME_SDI : string   := "KAT/v1_16bit/sdi.txt"; -- ! Path to the input file containing cryptotvgen SDI testvector data
    CONSTANT G_FNAME_DO  : string   := "KAT/v1_16bit/do.txt"; -- ! Path to the input file containing cryptotvgen DO testvector data
    CONSTANT G_FNAME_RDI : string   := "KAT/v1_16bit/rdi.txt"; -- ! Path to the input file containing random data

end package;
