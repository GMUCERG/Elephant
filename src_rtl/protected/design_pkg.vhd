--------------------------------------------------------------------------------
--! @file       Design_pkg.vhd
--! @brief      Package for the Cipher Core.
--!
--! @author     Michael Tempelmeier <michael.tempelmeier@tum.de>
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.elephant_constants.all;
use ieee.math_real.all;

package Design_pkg is
    --! Adjust the bit counter widths to reduce ressource consumption.
    -- Range definition must not change.
    constant AD_CNT_WIDTH    : integer range 4 to 64 := 32;  --! Width of AD Bit counter
    constant MSG_CNT_WIDTH   : integer range 4 to 64 := 32;  --! Width of MSG (PT/CT) Bit counter
    constant NUM_TRIVIUM_UNITS : integer := integer(ceil(real(RANDOM_BITS_PER_SBOX*NUMBER_SBOXS)/real(64))); --360 bits 6  X*64
    constant SEED_SIZE         : integer := NUM_TRIVIUM_UNITS * 128;

    --! Asynchronous and active-low reset.
    --! Can be set to `True` when targeting ASICs given that your CryptoCore supports it.
    --constant ASYNC_RSTN      : boolean := false;

    --! design parameters needed by the Pre- and Postprocessor
    constant TAG_SIZE        : integer := TAG_SIZE_BITS; --! Tag size
    constant HASH_VALUE_SIZE : integer := 128; --! Hash value size
    
    constant CCSW            : integer :=32; --! variant dependent design parameters are assigned in body!
    constant CCW             : integer :=32; --! variant dependent design parameters are assigned in body!
    constant CCWdiv8         : integer :=32/8; --! derived from parameters above, assigned in body.
    
    --constant RW              : integer := 32; --! This variable is used for random values (protected LWC)

    --! design parameters exclusivly used by the LWC core implementations
    constant NPUB_SIZE       : integer := 96;  --! Npub size
    constant DBLK_SIZE       : integer := 128; --! Block size

    --! Functions
    --! Reverse the Byte order of the input word.
    function reverse_byte( vec : std_logic_vector ) return std_logic_vector;
    --! Reverse the Bit order of the input vector.
end Design_pkg;


package body Design_pkg is
    function reverse_byte( vec : std_logic_vector ) return std_logic_vector is
        variable res : std_logic_vector(vec'length - 1 downto 0);
        constant n_bytes  : integer := vec'length/8;
    begin

        -- Check that vector length is actually byte aligned.
        assert (vec'length mod 8 = 0)
            report "Vector size must be in multiple of Bytes!" severity failure;

        -- Loop over every byte of vec and reorder it in res.
        for i in 0 to (n_bytes - 1) loop
            res(8*(i+1) - 1 downto 8*i) := vec(8*(n_bytes - i) - 1 downto 8*(n_bytes - i - 1));
        end loop;

        return res;
    end function reverse_byte;


end package body Design_pkg;
