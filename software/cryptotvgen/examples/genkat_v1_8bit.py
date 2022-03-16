#!/usr/bin/env python3

import os
import sys
from pathlib import Path

from cryptotvgen import cli

script_dir = Path(__file__).parent.resolve()

if __name__ == '__main__':
    blocks_per_segment = None
    ccw = 8
    print(
        f'Generating test-vectors for io={ccw}' +
        (f" and max_block_per_sgmt={blocks_per_segment}" if blocks_per_segment else "") + "..."
    )
    dest_dir = f'testvectors/v1_{ccw}bit'
    
    # ========================================================================
    # Create the list of arguments for cryptotvgen
    args = [
        '--lib_path', str(script_dir.parents[1] / 'isap_ref' / 'lib'),  # Library path
        # Library name of AEAD algorithm (<algorithm_name>)
        '--aead', 'isapa128av20',
        # Library name of Hash algorithm (<algorithm_name>)
        '--hash', 'asconhashv12',
        '--io', str(ccw), str(ccw),                        # I/O width: PDI/DO and SDI width, respectively.
        '--key_size', '128',                               # Key size
        '--npub_size', '128',                              # Npub size
        '--nsec_size', '0',                                # Nsec size
        '--message_digest_size', '256',                    # Hash tag
        '--tag_size', '128',                               # Tag size
        '--block_size',    '64',                           # Data block size
        '--block_size_ad', '64',                           # AD block size
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
    gen_test_routine = '--gen_test_routine 1 22 0'.split()
    gen_test_hash = '--gen_hash 1 22 0'.split()
    gen_test_combined = '--gen_test_combined 1 22 0'.split()

    # ========================================================================
    # Add option arguments together
    args += msg_format
    args += gen_test_routine
    args += gen_test_hash
    args += gen_test_combined

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

