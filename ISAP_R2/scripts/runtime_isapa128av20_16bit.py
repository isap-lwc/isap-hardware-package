'''
Notation:

Na, Nm, Nc, Nh : the number of complete blocks of associated data, plaintext, ciphertext, and hash message, respectively

Ina, Inm, Inc, Inh : binary variables equal to 1 if the last block of the respective data type is incomplete, and 0 otherwise

Bla, Blm, Blc, Blh : the number of bytes in the incomplete block of associated data, plaintext, ciphertext, and hash message, respectively.
'''

Na = 0
Nm = 0
Nc = 0

Ina = 0
Inm = 0
Inc = 0

Bla = 0
Blm = 0
Blc = 0

'''
encryption, 16-bit interface:

4                                                idle
8                                                store_key
8                                                store_nonce
2                                                isap_wait_input_type
((Nm>0)|(Inm>0))*1                               isap_rk_setup_state
((Nm>0)|(Inm>0))*12                              isap_rk_initialize
((Nm>0)|(Inm>0))*127                             isap_rk_rekeying
((Nm>0)|(Inm>0))*12                              isap_rk_squeeze
((Nm>0)|(Inm>0))*1                               isap_enc_initialize
((Nm>0)|(Inm>0))*(Nm*10)                         squeeze complete MSG blocks
((Nm>0)|(Inm>0))*(Inm*(6+((Blm+1)//2)))          squeeze incomplete MSG blocks
1                                                isap_mac_state_setup
12                                               isap_mac_initialize
1                                                isap_mac_wait_input
16*Na                                            absorb + process complete AD blocks
Ina*((Bla+1)//2 + 12)                            absorb + process incomplete AD blocks
(Ina==0)*12                                      absorb empty AD block with padding
1                                                isap_mac_domain_seperation
16*Nm                                            absorb + process complete CT blocks
Inm*((Blm+1)//2 + 12)                            absorb + process incomplete CT blocks
(Inm==0)*12                                      absorb empty CT block with padding
1                                                isap_rk_setup_state
12                                               isap_rk_initialize
127                                              isap_rk_rekeying
12                                               isap_rk_squeeze
1                                                isap_mac_finalize_after_rk_setup
12                                               isap_mac_finalize_permute_ph
8                                                extract_tag
1                                                idle
'''

runtime_enc =\
22 +\
((Nm>0)|(Inm>0))*(153) +\
((Nm>0)|(Inm>0))*(Nm*10) +\
((Nm>0)|(Inm>0))*(Inm*(6+((Blm+1)//2))) +\
14 +\
16*Na +\
Ina*((Bla+1)//2 + 12) +\
(Ina==0)*12 +\
1 +\
16*Nm +\
Inm*((Blm+1)//2 + 12) +\
(Inm==0)*12 +\
174

print('runtime_enc: ' + str(runtime_enc))

'''
decryption, 32-bit interface:

4                                                idle
8                                                store_key
8                                                store_nonce
1                                                isap_mac_state_setup
12                                               isap_mac_initialize
1                                                isap_wait_input
16*Na                                            absorb + process complete AD blocks
Ina*((Bla+1)//2 + 12)                            absorb + process incomplete AD blocks
(Ina==0)*12                                      absorb empty AD block with padding
1                                                isap_mac_domain_seperation
16*Nc                                            absorb + process complete CT blocks
Inc*((Blc+1)//2 + 12)                            absorb + process incomplete CT blocks
(Inc==0)*12                                      absorb empty CT block with padding
1                                                isap_rk_setup_state
12                                               isap_rk_initialize
127                                              isap_rk_rekeying
12                                               isap_rk_squeeze
1                                                isap_mac_finalize_after_rk_setup
12                                               isap_mac_finalize_permute_ph
8                                                verify_tag
1                                                wait_ack
((Nc>0)|(Inc>0))*1                               isap_rk_setup_state
((Nc>0)|(Inc>0))*12                              isap_rk_initialize
((Nc>0)|(Inc>0))*127                             isap_rk_rekeying
((Nc>0)|(Inc>0))*12                              isap_rk_squeeze
((Nc>0)|(Inc>0))*1                               isap_enc_initialize
((Nc>0)|(Inc>0))*(Nc*10)                         squeeze complete MSG blocks
((Nc>0)|(Inc>0))*(Inc*(6+((Blc+1)//2)))          squeeze incomplete MSG blocks
1                                                idle
'''

runtime_dec =\
34 +\
16*Na +\
Ina*((Bla+1)//2 + 12) +\
(Ina==0)*12 +\
1 +\
16*Nc +\
Inc*((Blc+1)//2 + 12) +\
(Inc==0)*12 +\
174 +\
((Nc>0)|(Inc>0))*(153) +\
((Nc>0)|(Inc>0))*(Nc*10) +\
((Nc>0)|(Inc>0))*(Inc*(6+((Blc+1)//2))) +\
1

print('runtime_dec: ' + str(runtime_dec))

cycle_start = 0
cycle_end = 0

print('diff: ' + str(cycle_end - cycle_start))

