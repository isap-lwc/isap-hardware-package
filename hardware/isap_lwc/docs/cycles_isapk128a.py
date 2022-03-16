'''
Notation:

Na, Nm, Nc, Nh : the number of complete blocks of associated data, plaintext, ciphertext, and hash message, respectively

Ina, Inm, Inc, Inh : binary variables equal to 1 if the last block of the respective data type is incomplete, and 0 otherwise

Bla, Blm, Blc, Blh : the number of bytes in the incomplete block of associated data, plaintext, ciphertext, and hash message, respectively.
'''

Na = 0
Nm = 0
Nc = 0

Bla = 0
Blm = 0
Blc = 0

# do not touch
Ina = 1 if Bla > 0 else 0
Inm = 1 if Blm > 0 else 0
Inc = 1 if Blc > 0 else 0

'''
encryption, 16-bit interface:

4                                                idle
8                                                store_key
8                                                store_nonce
((Na>0)|(Ina>0))*2                               isap_wait_input_type
((Nm>0)|(Inm>0))*1                               isap_rk_setup_state
((Nm>0)|(Inm>0))*8                               isap_rk_initialize
((Nm>0)|(Inm>0))*127                             isap_rk_rekeying
((Nm>0)|(Inm>0))*8                               isap_rk_squeeze
((Nm>0)|(Inm>0))*1                               isap_enc_initialize
((Nm>0)|(Inm>0))*(Nm*17)                         squeeze complete MSG blocks
((Nm>0)|(Inm>0))*(Inm*((Blm+1)//2 + 8))          squeeze incomplete MSG blocks
1                                                isap_mac_state_setup
16                                               isap_mac_initialize
1                                                isap_mac_wait_input
25*Na                                            absorb + process complete AD blocks
Ina*((Bla+1)//2 + 16)                            absorb + process incomplete AD blocks
(Ina==0)*16                                      absorb empty AD block with padding
1                                                isap_mac_domain_seperation
25*Nm                                            absorb + process complete CT blocks
Inm*((Blm+1)//2 + 16)                            absorb + process incomplete CT blocks
(Inm==0)*16                                      absorb empty CT block with padding
1                                                isap_rk_setup_state
8                                                isap_rk_initialize
127                                              isap_rk_rekeying
8                                                isap_rk_squeeze
1                                                isap_mac_finalize_after_rk_setup
16                                               isap_mac_finalize_permute_ph
8                                                extract_tag
1                                                idle
-8                                               offset to GMU simulation
'''

runtime_enc =\
20 +\
((Na>0)|(Ina>0))*2 +\
((Nm>0)|(Inm>0))*145 +\
((Nm>0)|(Inm>0))*(Nm*17) +\
((Nm>0)|(Inm>0))*(Inm*((Blm+1)//2 + 8)) +\
18 +\
25*Na +\
Ina*((Bla+1)//2 + 16) +\
(Ina==0)*16 +\
1 +\
25*Nm +\
Inm*((Blm+1)//2 + 16) +\
(Inm==0)*16 +\
170 -\
8

print('runtime_enc: ' + str(runtime_enc))

'''
decryption, 16-bit interface:

4                                                idle
8                                                store_key
8                                                store_nonce
1                                                isap_mac_state_setup
16                                               isap_mac_initialize
1                                                isap_wait_input
25*Na                                            absorb + process complete AD blocks
Ina*((Bla+1)//2 + 16)                            absorb + process incomplete AD blocks
(Ina==0)*16                                      absorb empty AD block with padding
1                                                isap_mac_domain_seperation
25*Nc                                            absorb + process complete CT blocks
Inc*((Blc+1)//2 + 16)                            absorb + process incomplete CT blocks
(Inc==0)*16                                      absorb empty CT block with padding
1                                                isap_rk_setup_state
8                                                isap_rk_initialize
127                                              isap_rk_rekeying
8                                                isap_rk_squeeze
1                                                isap_mac_finalize_after_rk_setup
16                                               isap_mac_finalize_permute_ph
8                                                verify_tag
1                                                wait_ack
((Nc>0)|(Inc>0))*1                               isap_rk_setup_state
((Nc>0)|(Inc>0))*8                               isap_rk_initialize
((Nc>0)|(Inc>0))*127                             isap_rk_rekeying
((Nc>0)|(Inc>0))*8                               isap_rk_squeeze
((Nc>0)|(Inc>0))*1                               isap_enc_initialize
((Nc>0)|(Inc>0))*(Nc*17)                         squeeze complete MSG blocks
((Nc>0)|(Inc>0))*(Inc*((Blc+1)//2 + 8))          squeeze incomplete MSG blocks
1                                                idle
-9                                               offset to GMU simulation
'''

runtime_dec =\
38 +\
25*Na +\
Ina*((Bla+1)//2 + 16) +\
(Ina==0)*16 +\
1 +\
25*Nc +\
Inc*((Blc+1)//2 + 16) +\
(Inc==0)*16 +\
170 +\
((Nc>0)|(Inc>0))*(145) +\
((Nc>0)|(Inc>0))*(Nc*17) +\
((Nc>0)|(Inc>0))*(Inc*((Blc+1)//2 + 8)) +\
1 -\
9

print('runtime_dec: ' + str(runtime_dec))

