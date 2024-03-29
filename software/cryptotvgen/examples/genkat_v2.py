#!/usr/bin/env python3

import os
import sys
from pathlib import Path

from cryptotvgen import cli

script_dir = Path(__file__).parent.resolve()

if __name__ == '__main__':
    blocks_per_segment = None
    ccw = 16
    print(
        f'Generating test-vectors for io={ccw}' +
        (f" and max_block_per_sgmt={blocks_per_segment}" if blocks_per_segment else "") + "..."
    )
    dest_dir = f'testvectors/v2_{ccw}'
    
    # ========================================================================
    # Create the list of arguments for cryptotvgen
    args = [
        '--lib_path', str(script_dir.parents[1] / 'isap_ref' / 'lib'),  # Library path
        # Library name of AEAD algorithm (<algorithm_name>)
        '--aead', 'isapk128av20',
        # Library name of Hash algorithm (<algorithm_name>)
        # '--hash', 'asconhashv12',
        '--io', str(ccw), str(ccw),                        # I/O width: PDI/DO and SDI width, respectively.
        '--key_size', '128',                               # Key size
        '--npub_size', '128',                              # Npub size
        '--nsec_size', '0',                                # Nsec size
        '--message_digest_size', '256',                    # Hash tag
        '--tag_size', '128',                               # Tag size
        '--block_size',    '144',                          # Data block size
        '--block_size_ad', '144',                          # AD block size
        # '--ciph_exp',                                    # Ciphertext expansion
        # '--add_partial',                                 # ciph_exp option: add partial bit
        # '--ciph_exp_noext',                              # ciph_exp option: no block extension when a message is a multiple of a block size
        # '--offline',                                     # Offline cipher (Adds Length segment as the first input segment)
        '--dest', dest_dir,                                # destination folder
        '--max_ad', '80',                                  # Maximum random AD size
        '--max_d', '80',                                   # Maximum random message size
        '--max_io_per_line', '8',                          # Max number of w-bit I/O word per line
        '--human_readable',                                # Generate a human readable text file
        '--verify_lib',                                    # Verify reference enc/dec in reference code
                                                           # Note: (This option performs decryption for
                                                           #        each encryption operation used to
                                                           #        create the test vector)
    ]
    if blocks_per_segment:
        args += ['--max_block_per_sgmt', str(blocks_per_segment)]

    # ========================================================================
    # Message format
    # This format is only correct for encryption. We swap the ad/ct order
    # manually in a post processing step down below
    msg_format = '--msg_format npub data ad tag'.split()
    # Alternative way of creating an option argument message format
    # new key (bool), decrypt (bool), AD_LEN, PT_LEN, hash-mode (bool)
    gen_custom = ['--gen_custom',
'''\
False,	True,	6,	25,	False:
False,	False,	23,	6,	False:
False,	True,	17,	31,	False:
False,	False,	4,	8,	False:
False,	True,	9,	0,	False:
False,	False,	5,	25,	False:
False,	True,	7,	4,	False:
False,	False,	8,	7,	False:
False,	True,	6,	17,	False:
False,	False,	7,	16,	False:
False,	False,	17,	25,	False:
False,	True,	6,	3,	False:
False,	False,	32,	8,	False:
False,	True,	15,	7,	False:
False,	True,	7,	17,	False:
False,	False,	4,	9,	False:
False,	False,	3,	31,	False:
False,	False,	32,	15,	False:
False,	True,	8,	16,	False:
False,	True,	16,	7,	False:
False,	False,	1,	4,	False:
False,	False,	32,	31,	False:
False,	True,	1,	6,	False:
False,	False,	23,	31,	False:
False,	True,	17,	25,	False:
False,	True,	16,	3,	False:
False,	False,	9,	17,	False:
False,	False,	9,	23,	False:
False,	False,	32,	3,	False:
False,	True,	8,	25,	False:
False,	False,	31,	4,	False:
False,	True,	25,	1,	False:
False,	False,	8,	4,	False:
False,	False,	3,	1,	False:
False,	True,	25,	24,	False:
False,	False,	1,	17,	False:
False,	False,	15,	24,	False:
False,	True,	9,	7,	False:
False,	True,	7,	3,	False:
False,	False,	9,	7,	False:
False,	False,	7,	24,	False:
False,	True,	32,	0,	False:
False,	True,	3,	25,	False:
False,	False,	0,	5,	False:
False,	False,	8,	23,	False:
False,	False,	15,	23,	False:
False,	False,	31,	24,	False:
False,	True,	7,	2,	False:
False,	True,	25,	3,	False:
False,	False,	3,	9,	False:
False,	True,	7,	1,	False:
False,	True,	4,	31,	False:
False,	True,	17,	9,	False:
False,	True,	31,	24,	False:
False,	True,	5,	16,	False:
False,	False,	16,	24,	False:
False,	False,	24,	4,	False:
False,	False,	16,	4,	False:
False,	False,	15,	8,	False:
False,	False,	24,	17,	False:
False,	False,	8,	15,	False:
False,	False,	9,	0,	False:
False,	True,	15,	25,	False:
False,	False,	17,	6,	False:
False,	False,	2,	17,	False:
False,	False,	1,	25,	False:
False,	True,	0,	31,	False:
False,	True,	16,	16,	False:
False,	True,	3,	3,	False:
False,	True,	15,	6,	False:
False,	True,	1,	25,	False:
False,	False,	3,	32,	False:
False,	False,	5,	23,	False:
False,	False,	23,	4,	False:
False,	False,	31,	7,	False:
False,	True,	17,	2,	False:
False,	True,	4,	1,	False:
False,	False,	6,	5,	False:
False,	False,	1,	23,	False:
False,	False,	8,	25,	False:
False,	False,	0,	17,	False:
False,	False,	4,	24,	False:
False,	False,	3,	8,	False:
False,	True,	31,	16,	False:
False,	False,	0,	15,	False:
False,	True,	9,	5,	False:
False,	True,	2,	31,	False:
False,	True,	23,	15,	False:
False,	True,	8,	24,	False:
False,	False,	32,	23,	False:
False,	False,	24,	24,	False:
False,	False,	4,	32,	False:
False,	False,	6,	6,	False:
False,	True,	31,	0,	False:
False,	True,	9,	15,	False:
False,	True,	23,	31,	False:
False,	True,	2,	6,	False:
False,	True,	0,	23,	False:
False,	False,	25,	4,	False:
False,	False,	9,	8,	False:
False,	True,	9,	17,	False:
False,	True,	23,	16,	False:
False,	False,	23,	9,	False:
False,	True,	15,	31,	False:
False,	False,	5,	16,	False:
False,	False,	32,	32,	False:
False,	True,	32,	1,	False:
False,	False,	17,	31,	False:
False,	False,	16,	2,	False:
False,	True,	0,	16,	False:
False,	False,	0,	23,	False:
False,	True,	1,	5,	False:
False,	False,	16,	7,	False:
False,	True,	2,	0,	False:
False,	True,	5,	23,	False:
False,	False,	1,	32,	False:
False,	False,	25,	25,	False:
False,	False,	4,	2,	False:
False,	True,	31,	17,	False:
False,	False,	32,	2,	False:
False,	False,	31,	25,	False:
False,	True,	23,	2,	False:
False,	False,	16,	32,	False:
False,	True,	24,	4,	False:
False,	True,	32,	15,	False:
False,	False,	16,	8,	False:
False,	False,	6,	8,	False:
False,	False,	32,	0,	False:
False,	False,	15,	5,	False:
False,	False,	1,	15,	False:
False,	False,	7,	31,	False:
False,	False,	0,	6,	False:
False,	True,	32,	25,	False:
False,	False,	31,	32,	False:
False,	True,	4,	5,	False:
False,	True,	32,	32,	False:
False,	False,	8,	0,	False:
False,	False,	15,	6,	False:
False,	True,	7,	8,	False:
False,	False,	5,	7,	False:
False,	False,	9,	1,	False:
False,	False,	16,	23,	False:
False,	True,	7,	0,	False:
False,	True,	31,	4,	False:
False,	True,	4,	23,	False:
False,	False,	4,	3,	False:
False,	True,	31,	31,	False:
False,	False,	9,	5,	False:
False,	False,	1,	2,	False:
False,	True,	17,	1,	False:
False,	True,	9,	6,	False:
False,	False,	24,	1,	False:
False,	True,	2,	25,	False:
False,	True,	23,	25,	False:
False,	True,	3,	5,	False:
False,	False,	4,	1,	False:
False,	False,	25,	2,	False:
False,	False,	16,	6,	False:
False,	False,	5,	15,	False:
False,	True,	2,	8,	False:
False,	True,	17,	32,	False:
False,	False,	7,	5,	False:
False,	False,	1,	1,	False:
False,	True,	9,	8,	False:
False,	False,	9,	16,	False:
False,	True,	4,	4,	False:
False,	False,	5,	32,	False:
False,	False,	24,	7,	False:
False,	False,	5,	1,	False:
False,	True,	17,	16,	False:
False,	False,	31,	5,	False:
False,	True,	17,	3,	False:
False,	False,	3,	25,	False:
False,	True,	24,	9,	False:
False,	True,	6,	15,	False:
False,	True,	8,	32,	False:
False,	True,	1,	8,	False:
False,	False,	24,	32,	False:
False,	True,	6,	8,	False:
False,	False,	16,	5,	False:
False,	True,	23,	4,	False:
False,	False,	24,	15,	False:
False,	False,	2,	2,	False:
False,	True,	2,	3,	False:
False,	True,	16,	4,	False:
False,	True,	17,	8,	False:
False,	False,	32,	25,	False:
False,	True,	5,	0,	False:
False,	False,	5,	24,	False:
False,	False,	7,	17,	False:
False,	False,	7,	2,	False:
False,	False,	7,	6,	False:
False,	False,	17,	5,	False:
False,	True,	0,	2,	False:
False,	False,	32,	4,	False:
False,	True,	9,	9,	False:
False,	True,	24,	23,	False:
False,	True,	0,	25,	False:
False,	True,	23,	1,	False:
False,	True,	25,	6,	False:
False,	True,	3,	8,	False:
False,	False,	31,	23,	False:
False,	False,	6,	24,	False:
False,	False,	17,	1,	False:
False,	False,	1,	24,	False:
False,	False,	23,	16,	False:
False,	False,	16,	3,	False:
False,	True,	15,	8,	False:
False,	True,	1,	24,	False:
False,	False,	9,	2,	False:
False,	True,	16,	1,	False:
False,	True,	17,	0,	False:
False,	False,	5,	9,	False:
False,	False,	25,	16,	False:
False,	False,	8,	8,	False:
False,	True,	8,	0,	False:
False,	True,	31,	25,	False:
False,	False,	9,	32,	False:
False,	True,	8,	7,	False:
False,	True,	25,	31,	False:
False,	False,	23,	15,	False:
False,	False,	0,	3,	False:
False,	False,	23,	32,	False:
False,	False,	1,	16,	False:
False,	True,	0,	24,	False:
False,	False,	17,	17,	False:
False,	True,	15,	0,	False:
False,	False,	23,	25,	False:
False,	False,	3,	5,	False:
False,	True,	5,	25,	False:
False,	True,	7,	5,	False:
False,	False,	7,	7,	False:
False,	False,	31,	31,	False:
False,	False,	4,	17,	False:
False,	True,	23,	9,	False:
False,	True,	2,	7,	False:
False,	True,	7,	24,	False:
False,	True,	3,	1,	False:
False,	False,	7,	1,	False:
False,	True,	9,	2,	False:
False,	True,	2,	9,	False:
False,	False,	0,	0,	False:
False,	False,	31,	3,	False:
False,	True,	3,	9,	False:
False,	True,	1,	31,	False:
False,	True,	15,	9,	False:
False,	True,	4,	7,	False:
False,	True,	5,	24,	False:
False,	True,	24,	7,	False:
False,	False,	17,	2,	False:
False,	True,	24,	1,	False:
False,	True,	16,	25,	False:
False,	True,	16,	8,	False:
False,	True,	4,	17,	False:
False,	True,	15,	3,	False:
False,	False,	8,	31,	False:
False,	False,	25,	23,	False:
False,	False,	1,	8,	False:
False,	False,	2,	15,	False:
False,	True,	0,	9,	False:
False,	False,	2,	23,	False:
False,	True,	32,	9,	False:
False,	True,	8,	31,	False:
False,	False,	23,	8,	False:
False,	True,	0,	17,	False:
False,	True,	5,	17,	False:
False,	True,	24,	6,	False:
False,	False,	24,	2,	False:
False,	False,	9,	15,	False:
False,	False,	31,	17,	False:
False,	False,	24,	0,	False:
False,	False,	31,	8,	False:
False,	False,	1,	9,	False:
False,	False,	0,	24,	False:
False,	False,	32,	24,	False:
False,	False,	31,	1,	False:
False,	True,	31,	6,	False:
False,	False,	4,	15,	False:
False,	True,	8,	6,	False:
False,	False,	4,	31,	False:
False,	False,	17,	23,	False:
False,	True,	23,	23,	False:
False,	True,	5,	5,	False:
False,	True,	3,	31,	False:
False,	True,	0,	5,	False:
False,	True,	31,	9,	False:
False,	True,	7,	16,	False:
False,	False,	15,	4,	False:
False,	False,	0,	31,	False:
False,	True,	6,	4,	False:
False,	True,	9,	1,	False:
False,	True,	25,	23,	False:
False,	True,	0,	15,	False:
False,	False,	17,	9,	False:
False,	True,	6,	31,	False:
False,	False,	32,	6,	False:
False,	True,	7,	31,	False:
False,	True,	0,	3,	False:
False,	False,	3,	17,	False:
False,	True,	16,	6,	False:
False,	True,	16,	31,	False:
False,	False,	25,	3,	False:
False,	True,	17,	4,	False:
False,	True,	7,	25,	False:
False,	False,	24,	31,	False:
False,	False,	24,	23,	False:
False,	True,	2,	1,	False:
False,	True,	16,	5,	False:
False,	False,	1,	0,	False:
False,	True,	9,	16,	False:
False,	False,	0,	32,	False:
False,	True,	32,	17,	False:
False,	True,	1,	15,	False:
False,	True,	2,	2,	False:
False,	False,	15,	9,	False:
False,	True,	0,	32,	False:
False,	True,	0,	6,	False:
False,	True,	31,	7,	False:
False,	True,	5,	7,	False:
False,	True,	15,	23,	False:
False,	True,	16,	24,	False:
False,	False,	32,	5,	False:
False,	True,	16,	9,	False:
False,	True,	0,	8,	False:
False,	True,	16,	15,	False:
False,	True,	32,	16,	False:
False,	False,	6,	15,	False:
False,	False,	2,	5,	False:
False,	True,	32,	6,	False:
False,	True,	1,	9,	False:
False,	False,	8,	32,	False:
False,	True,	6,	6,	False:
False,	False,	8,	17,	False:
False,	False,	2,	9,	False:
False,	False,	4,	4,	False:
False,	False,	5,	0,	False:
False,	False,	15,	1,	False:
False,	True,	25,	25,	False:
False,	False,	7,	8,	False:
False,	False,	17,	32,	False:
False,	True,	4,	32,	False:
False,	False,	25,	7,	False:
False,	True,	6,	7,	False:
False,	True,	8,	15,	False:
False,	True,	6,	16,	False:
False,	True,	15,	1,	False:
False,	False,	24,	3,	False:
False,	False,	1,	6,	False:
False,	False,	8,	24,	False:
False,	False,	17,	24,	False:
False,	True,	7,	9,	False:
False,	False,	17,	16,	False:
False,	True,	3,	6,	False:
False,	True,	15,	2,	False:
False,	False,	9,	24,	False:
False,	True,	15,	17,	False:
False,	False,	23,	23,	False:
False,	True,	6,	2,	False:
False,	True,	3,	7,	False:
False,	True,	9,	32,	False:
False,	True,	4,	24,	False:
False,	False,	1,	5,	False:
False,	False,	9,	25,	False:
False,	False,	32,	1,	False:
False,	False,	6,	16,	False:
False,	False,	2,	0,	False:
False,	True,	25,	7,	False:
False,	False,	16,	15,	False:
False,	True,	24,	0,	False:
False,	False,	15,	17,	False:
False,	False,	32,	9,	False:
False,	False,	25,	31,	False:
False,	False,	0,	7,	False:
False,	True,	2,	17,	False:
False,	False,	2,	3,	False:
False,	True,	8,	4,	False:
False,	False,	4,	16,	False:
False,	False,	3,	16,	False:
False,	True,	32,	3,	False:
False,	True,	17,	23,	False:
False,	True,	23,	7,	False:
False,	False,	24,	9,	False:
False,	True,	5,	31,	False:
False,	True,	32,	31,	False:
False,	False,	1,	31,	False:
False,	False,	2,	24,	False:
False,	False,	7,	0,	False:
False,	True,	9,	23,	False:
False,	False,	17,	3,	False:
False,	True,	1,	7,	False:
False,	True,	23,	17,	False:
False,	False,	5,	6,	False:
False,	True,	1,	3,	False:
False,	True,	31,	32,	False:
False,	True,	4,	15,	False:
False,	True,	16,	32,	False:
False,	True,	31,	23,	False:
False,	False,	2,	32,	False:
False,	False,	31,	6,	False:
False,	True,	15,	15,	False:
False,	True,	1,	1,	False:
False,	False,	31,	0,	False:
False,	False,	9,	6,	False:
False,	False,	16,	25,	False:
False,	True,	9,	31,	False:
False,	True,	31,	15,	False:
False,	True,	7,	32,	False:
False,	True,	8,	3,	False:
False,	True,	8,	17,	False:
False,	True,	8,	23,	False:
False,	False,	6,	7,	False:
False,	True,	24,	32,	False:
False,	False,	0,	25,	False:
False,	True,	23,	24,	False:
False,	True,	25,	9,	False:
False,	False,	3,	6,	False:
False,	False,	5,	4,	False:
False,	True,	5,	4,	False:
False,	False,	5,	31,	False:
False,	True,	3,	23,	False:
False,	True,	32,	8,	False:
False,	True,	7,	23,	False:
False,	False,	17,	4,	False:
False,	False,	25,	17,	False:
False,	True,	3,	24,	False:
False,	False,	4,	7,	False:
False,	False,	2,	6,	False:
False,	False,	23,	0,	False:
False,	False,	25,	9,	False:
False,	False,	7,	15,	False:
False,	False,	8,	5,	False:
False,	False,	24,	5,	False:
False,	False,	15,	7,	False:
False,	False,	15,	0,	False:
False,	False,	8,	1,	False:
False,	True,	32,	7,	False:
False,	False,	25,	15,	False:
False,	True,	0,	1,	False:
False,	True,	8,	1,	False:
False,	False,	32,	16,	False:
False,	True,	9,	25,	False:
False,	False,	8,	3,	False:
False,	False,	24,	6,	False:
False,	False,	16,	9,	False:
False,	False,	23,	3,	False:
False,	False,	8,	2,	False:
False,	True,	0,	7,	False:
False,	False,	8,	6,	False:
False,	False,	25,	0,	False:
False,	False,	17,	0,	False:
False,	False,	0,	16,	False:
False,	False,	7,	23,	False:
False,	False,	15,	32,	False:
False,	True,	8,	8,	False:
False,	True,	32,	4,	False:
False,	True,	4,	0,	False:
False,	True,	3,	4,	False:
False,	False,	4,	5,	False:
False,	True,	6,	32,	False:
False,	True,	2,	23,	False:
False,	True,	23,	32,	False:
False,	True,	9,	4,	False:
False,	True,	23,	5,	False:
False,	False,	16,	1,	False:
False,	False,	7,	25,	False:
False,	False,	4,	0,	False:
False,	False,	6,	9,	False:
False,	True,	17,	17,	False:
False,	True,	0,	4,	False:
False,	True,	2,	5,	False:
False,	False,	5,	2,	False:
False,	True,	6,	9,	False:
False,	False,	8,	9,	False:
False,	False,	6,	17,	False:
False,	False,	23,	1,	False:
False,	True,	24,	3,	False:
False,	True,	24,	16,	False:
False,	False,	15,	2,	False:
False,	False,	16,	31,	False:
False,	True,	9,	24,	False:
False,	False,	24,	8,	False:
False,	False,	23,	7,	False:
False,	True,	24,	5,	False:
False,	True,	7,	6,	False:
False,	False,	6,	32,	False:
False,	True,	5,	2,	False:
False,	True,	32,	24,	False:
False,	False,	6,	23,	False:
False,	True,	25,	8,	False:
False,	True,	16,	17,	False:
False,	False,	7,	3,	False:
False,	False,	3,	0,	False:
False,	True,	4,	3,	False:
False,	True,	2,	24,	False:
False,	True,	23,	8,	False:
False,	False,	2,	1,	False:
False,	False,	25,	32,	False:
False,	False,	23,	5,	False:
False,	False,	2,	25,	False:
False,	True,	32,	23,	False:
False,	False,	6,	4,	False:
False,	False,	31,	16,	False:
False,	False,	7,	32,	False:
False,	False,	0,	4,	False:
False,	True,	24,	31,	False:
False,	True,	17,	7,	False:
False,	False,	17,	7,	False:
False,	False,	2,	7,	False:
False,	True,	25,	17,	False:
False,	False,	3,	4,	False:
False,	True,	17,	24,	False:
False,	False,	16,	16,	False:
False,	True,	3,	16,	False:
False,	True,	15,	32,	False:
False,	True,	2,	15,	False:
False,	False,	0,	8,	False:
False,	True,	31,	8,	False:
False,	True,	15,	24,	False:
False,	True,	2,	4,	False:
False,	True,	17,	15,	False:
False,	False,	32,	7,	False:
False,	True,	3,	32,	False:
False,	False,	3,	24,	False:
False,	True,	1,	23,	False:
False,	True,	7,	7,	False:
False,	True,	24,	17,	False:
False,	False,	8,	16,	False:
False,	True,	31,	5,	False:
False,	False,	24,	16,	False:
False,	True,	3,	17,	False:
False,	False,	31,	2,	False:
False,	False,	4,	6,	False:
False,	True,	3,	2,	False:
False,	False,	6,	31,	False:
False,	True,	4,	2,	False:
False,	True,	4,	16,	False:
False,	False,	4,	23,	False:
False,	True,	16,	23,	False:
False,	True,	23,	6,	False:
False,	True,	5,	9,	False:
False,	True,	6,	5,	False:
False,	False,	1,	3,	False:
False,	False,	3,	7,	False:
False,	True,	25,	5,	False:
False,	False,	23,	17,	False:
False,	True,	8,	5,	False:
False,	False,	1,	7,	False:
False,	False,	6,	25,	False:
False,	True,	23,	0,	False:
False,	True,	0,	0,	False:
False,	False,	9,	4,	False:
False,	False,	15,	15,	False:
False,	True,	25,	15,	False:
False,	True,	1,	2,	False:
False,	True,	31,	3,	False:
False,	True,	2,	16,	False:
False,	False,	2,	8,	False:
False,	True,	6,	0,	False:
False,	False,	3,	3,	False:
False,	True,	16,	0,	False:
False,	True,	17,	6,	False:
False,	True,	6,	1,	False:
False,	False,	9,	31,	False:
False,	False,	25,	8,	False:
False,	True,	2,	32,	False:
False,	True,	24,	15,	False:
False,	True,	32,	2,	False:
False,	False,	7,	4,	False:
False,	False,	15,	31,	False:
False,	False,	17,	8,	False:
False,	False,	4,	25,	False:
False,	True,	1,	4,	False:
False,	True,	15,	5,	False:
False,	True,	16,	2,	False:
False,	True,	7,	15,	False:
False,	True,	17,	5,	False:
False,	True,	1,	16,	False:
False,	True,	25,	32,	False:
False,	False,	15,	3,	False:
False,	True,	1,	17,	False:
False,	False,	32,	17,	False:
False,	False,	25,	1,	False:
False,	True,	3,	15,	False:
False,	True,	5,	6,	False:
False,	True,	24,	24,	False:
False,	True,	23,	3,	False:
False,	True,	9,	3,	False:
False,	False,	15,	16,	False:
False,	False,	2,	4,	False:
False,	True,	4,	8,	False:
False,	True,	8,	9,	False:
False,	True,	15,	4,	False:
False,	True,	5,	3,	False:
False,	True,	8,	2,	False:
False,	True,	6,	23,	False:
False,	False,	5,	17,	False:
False,	False,	6,	1,	False:
False,	True,	24,	8,	False:
False,	False,	0,	1,	False:
False,	False,	3,	2,	False:
False,	False,	5,	5,	False:
False,	True,	5,	15,	False:
False,	False,	24,	25,	False:
False,	True,	25,	2,	False:
False,	False,	23,	2,	False:
False,	False,	5,	3,	False:
False,	True,	5,	8,	False:
False,	True,	32,	5,	False:
False,	False,	31,	15,	False:
False,	False,	9,	9,	False:
False,	False,	16,	17,	False:
False,	True,	31,	2,	False:
False,	True,	24,	2,	False:
False,	False,	5,	8,	False:
False,	False,	3,	15,	False:
False,	False,	31,	9,	False:
False,	False,	2,	16,	False:
False,	True,	31,	1,	False:
False,	True,	6,	24,	False:
False,	False,	17,	15,	False:
False,	False,	25,	24,	False:
False,	False,	2,	31,	False:
False,	False,	25,	5,	False:
False,	False,	9,	3,	False:
False,	True,	25,	0,	False:
False,	False,	7,	9,	False:
False,	False,	3,	23,	False:
False,	False,	6,	3,	False:
False,	False,	0,	2,	False:
False,	True,	4,	9,	False:
False,	True,	5,	32,	False:
False,	True,	4,	6,	False:
False,	True,	25,	16,	False:
False,	True,	4,	25,	False:
False,	True,	24,	25,	False:
False,	False,	15,	25,	False:
False,	True,	3,	0,	False:
False,	True,	5,	1,	False:
False,	True,	1,	0,	False:
False,	False,	23,	24,	False:
False,	False,	25,	6,	False:
False,	True,	25,	4,	False:
False,	False,	6,	2,	False:
False,	False,	0,	9,	False:
False,	False,	16,	0,	False:
False,	False,	6,	0,	False:
False,	True,	1,	32,	False:
False,	True,	15,	16,	False
''']
    gen_test_routine = gen_custom
    args += msg_format
    args += gen_test_routine
    # ========================================================================
    # Call program
    cli.run_cryptotvgen(args)

    # ========================================================================
    # Swap order of AD and CT during decryption in pdi.txt
    file1 = open(dest_dir + '/' + 'pdi.txt', 'r') 
    Lines = file1.readlines()
    file1.close()
    done = 0
    flag_ctO = 0
    llen = len(Lines)
    h = 0 
    while h < llen:
        line0 = Lines[h]
        if "Authenticated Decryption" in line0:
            i = h+1
            while i < llen:
                line1 = Lines[i]
                if "Ciphertext" in line1:
                    flag_ctO = "Length=0 bytes" in line1
                    if flag_ctO == False:
                        line1 = line1.replace('EOI=0','EOI=1')
                        Lines[i+1] = 'HDR = ' + '{:08x}'.format(int(Lines[i+1].split(' ')[-1],16) | 0x04000000).upper()
                    Lines[i] = line1
                    j = i+1
                    while j < llen:
                        line2 = Lines[j]
                        if "Associated Data" in line2:
                            if flag_ctO == False:
                                line2 = line2.replace('EOI=1','EOI=0')
                                Lines[j+1] = 'HDR = ' + '{:08x}'.format(int(Lines[j+1].split(' ')[-1],16) & 0xFBFFFFFF).upper()
                            Lines.insert(i,line2)
                            Lines.pop(j+1)
                            i += 1
                            for k in range(j+1,llen):
                                line3 = Lines[k]
                                if "Tag" not in line3:
                                    Lines.insert(i,line3)
                                    Lines.pop(k+1)
                                    i += 1
                                else:
                                    done = 1
                                    h = k + 1
                                    if done: break
                            if done: break
                        else:
                            j += 1
                    if done: break
                else:
                    i += 1
            done = 0
        else:
            h += 1

    with open(dest_dir + '/' + 'pdi.txt', 'w') as the_file:
        for line in Lines: 
            the_file.write(line.strip() + '\n')

    # ========================================================================
    # Fix missing last block flag for hash messages

    file1 = open(dest_dir + '/' + 'pdi.txt', 'r') 
    Lines = file1.readlines()
    file1.close()
    
    with open(dest_dir + '/' + 'pdi.txt', 'w') as the_file:
        for line in Lines: 
            the_file.write(line.strip().replace('HDR = 76','HDR = 77').replace('Hash, EOI=1 EOT=1, Last=0','Hash, EOI=1 EOT=1, Last=1') + '\n')

