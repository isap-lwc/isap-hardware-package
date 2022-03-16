#!/usr/bin/env python3

import os
import sys
import random
from pathlib import Path

dest_dir = str(sys.argv[1])

# ========================================================================
# Change status of auth dec to fail
file1 = open(dest_dir + '/' + 'do.txt', 'r') 
Lines = file1.readlines()
file1.close()
done = 0
flag_ctO = 0
llen = len(Lines)
i = 0

while i < len(Lines):
    line_i = Lines[i]
    if "#### Authenticated Decryption" in line_i:
        j = i+1
        while j < len(Lines):
            line_j = Lines[j]
            if 'Success' in line_j:
                break
            else:
                if 'DAT =' in line_j:
                    Lines[j] = '# ' + line_j
                j += 1
        line_j = Lines[j]
        line_j = line_j.strip().replace('Success','Failure')
        Lines[j] = line_j
        k = j+1
        line_k = Lines[k]
        line_k = line_k.strip().replace('E','F')
        Lines[k] = line_k
        i = k+1
    else:
        i += 1

with open(dest_dir + '/' + 'do.txt', 'w') as the_file:
    for line in Lines: 
        the_file.write(line.strip() + '\n')

# ========================================================================
# Corrupt input data of auth dec
file1 = open(dest_dir + '/' + 'pdi.txt', 'r') 
Lines = file1.readlines()
file1.close()
done = 0
flag_ctO = 0
i = 0

matches = ['Npub,','Tag,','Associated Data,','Ciphertext,']#
#matches = ['Npub,','Tag,']

while i < len(Lines):
    line_i = Lines[i]
    if "#### Authenticated Decryption" in line_i:
        j = i+1
        line_meta = Lines[j]
        adlen = int(" ".join(line_meta.split()).split(" ")[8][:-1])
        clen = int(" ".join(line_meta.split()).split(" ")[12])
        coin = random.randint(0, 3) # corrupt npub, ad, ct, or tag
        while (coin == 2 and adlen == 0) or (coin == 3 and clen == 0):
            coin = random.randint(0, 3) # corrupt npub, ad, ct, or tag
        while j < len(Lines):
            line_j = Lines[j]
            if matches[coin] in line_j:
                line_h = Lines[j+2]
                line_hh = line_h.strip().split(" ")[2]
                line_hhh = bytearray.fromhex(line_hh)
                max_idx = len(line_hhh)-1
                if coin == 2:
                    max_idx = adlen-1
                if coin == 3:
                    max_idx = clen-1
                line_hhh[random.randint(0, max_idx)] ^= random.randint(1, 255)
                line_hhhh = 'DAT = ' + ''.join('{:02X}'.format(x) for x in line_hhh)
                Lines[j+2] = '# ORIG: ' + line_h
                Lines.insert(j+3, '# FAIL: ' + line_hhhh)
                Lines.insert(j+4, line_hhhh)
                i = j+5
                break
            else:
                j += 1
    else:
        i += 1

with open(dest_dir + '/' + 'pdi.txt', 'w') as the_file:
    for line in Lines: 
        the_file.write(line.strip() + '\n')
