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
encryption, 32-bit interface:

4                                                idle
4                                                store_key
4                                                store_nonce
2                                                isap_wait_input_type
((Nm>0)|(Inm>0))*1                               isap_rk_setup_state
((Nm>0)|(Inm>0))*12                              isap_rk_initialize
((Nm>0)|(Inm>0))*127                             isap_rk_rekeying
((Nm>0)|(Inm>0))*12                              isap_rk_squeeze
((Nm>0)|(Inm>0))*1                               isap_enc_initialize
((Nm>0)|(Inm>0))*(Nm*8)                          squeeze complete MSG blocks
((Nm>0)|(Inm>0))*(Inm*(6+((Blm+3)//4)))          squeeze incomplete MSG blocks
1                                                isap_mac_state_setup
12                                               isap_mac_initialize
1                                                isap_mac_wait_input
14*Na                                            absorb + process complete AD blocks
Ina*((Bla+3)//4 + 12)                            absorb + process incomplete AD blocks
(Ina==0)*12                                      absorb empty AD block with padding
1                                                isap_mac_domain_seperation
14*Nm                                            absorb + process complete CT blocks
Inm*((Blm+3)//4 + 12)                            absorb + process incomplete CT blocks
(Inm==0)*12                                      absorb empty CT block with padding
1                                                isap_rk_setup_state
12                                               isap_rk_initialize
127                                              isap_rk_rekeying
12                                               isap_rk_squeeze
1                                                isap_mac_finalize_after_rk_setup
12                                               isap_mac_finalize_permute_ph
4                                                extract_tag
1                                                idle
'''

runtime_enc =\
14 +\
((Nm>0)|(Inm>0))*153 +\
((Nm>0)|(Inm>0))*(Nm*8) +\
((Nm>0)|(Inm>0))*(Inm*(6+((Blm+3)//4))) +\
14 +\
14*Na +\
Ina*((Bla+3)//4 + 12) +\
(Ina==0)*12 +\
1 +\
14*Nm +\
Inm*((Blm+3)//4 + 12) +\
(Inm==0)*12 +\
170

print('runtime_enc: ' + str(runtime_enc))

'''
decryption, 32-bit interface:

4                                                idle
4                                                store_key
4                                                store_nonce
1                                                isap_mac_state_setup
12                                               isap_mac_initialize
1                                                isap_wait_input
14*Na                                            absorb + process complete AD blocks
Ina*((Bla+3)//4 + 12)                            absorb + process incomplete AD blocks
(Ina==0)*12                                      absorb empty AD block with padding
1                                                isap_mac_domain_seperation
14*Nc                                            absorb + process complete CT blocks
Inc*((Blc+3)//4 + 12)                            absorb + process incomplete CT blocks
(Inc==0)*12                                      absorb empty CT block with padding
1                                                isap_rk_setup_state
12                                               isap_rk_initialize
127                                              isap_rk_rekeying
12                                               isap_rk_squeeze
1                                                isap_mac_finalize_after_rk_setup
12                                               isap_mac_finalize_permute_ph
4                                                verify_tag
1                                                wait_ack
((Nc>0)|(Inc>0))*1                               isap_rk_setup_state
((Nc>0)|(Inc>0))*12                              isap_rk_initialize
((Nc>0)|(Inc>0))*127                             isap_rk_rekeying
((Nc>0)|(Inc>0))*12                              isap_rk_squeeze
((Nc>0)|(Inc>0))*1                               isap_enc_initialize
((Nc>0)|(Inc>0))*(Nc*8)                          squeeze complete MSG blocks
((Nc>0)|(Inc>0))*(Inc*(6+((Blc+3)//4)))          squeeze incomplete MSG blocks
1                                                idle
'''

runtime_dec =\
26 +\
14*Na +\
Ina*((Bla+3)//4 + 12) +\
(Ina==0)*12 +\
1 +\
14*Nc +\
Inc*((Blc+3)//4 + 12) +\
(Inc==0)*12 +\
170 +\
((Nc>0)|(Inc>0))*(153) +\
((Nc>0)|(Inc>0))*(Nc*8) +\
((Nc>0)|(Inc>0))*(Inc*(6+((Blc+3)//4))) +\
1

print('runtime_dec: ' + str(runtime_dec))

cycle_start = 0
cycle_end = 0

print('diff: ' + str(cycle_end - cycle_start))

