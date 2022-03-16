'''
Notation:

Na, Nm, Nc, Nh : the number of complete blocks of associated data, plaintext, ciphertext, and hash message, respectively

Ina, Inm, Inc, Inh : binary variables equal to 1 if the last block of the respective data type is incomplete, and 0 otherwise

Bla, Blm, Blc, Blh : the number of bytes in the incomplete block of associated data, plaintext, ciphertext, and hash message, respectively.

'''
CCW = 32 # same as CCSW, either 8, 16, or 32
UROL = 1 # permutation rounds per cycle; needs to evenly divide 6

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

cycles_enc = 128//CCW                                                       # store_key   
cycles_enc += 128//CCW                                                      # store_nonce             
cycles_enc += ((Na>0)|(Ina>0))*2                                            # isap_wait_input_type                   
cycles_enc += ((Nm>0)|(Inm>0))*1                                            # isap_rk_setup_state                   
cycles_enc += ((Nm>0)|(Inm>0))*(12//UROL)                                   # isap_rk_initialize                       
cycles_enc += ((Nm>0)|(Inm>0))*(127//UROL)                                  # isap_rk_rekeying                       
cycles_enc += ((Nm>0)|(Inm>0))*(12//UROL)                                   # isap_rk_squeeze                           
cycles_enc += ((Nm>0)|(Inm>0))*1                                            # isap_enc_initialize                       
cycles_enc += ((Nm>0)|(Inm>0))*(Nm*(64//CCW)+Nm*6//UROL)                     # squeeze complete CT blocks                               
cycles_enc += ((Nm>0)|(Inm>0))*(Inm*(int(((Blm*8+CCW-8)/CCW))+6//UROL))     # squeeze incomplete CT blocks               
cycles_enc += 1                                                             # isap_mac_state_setup               
cycles_enc += 12//UROL                                                      # isap_mac_initialize                       
cycles_enc += 1                                                             # isap_mac_wait_input
cycles_enc += Na*(64//CCW)+Na*12//UROL                                      # absorb + process complete AD blocks          
cycles_enc += Ina*(int(((Bla*8+CCW-8)/CCW))+12//UROL)                       # absorb + process incomplete AD blocks
cycles_enc += (Ina==0)*12//UROL                                             # absorb empty AD block with padding
cycles_enc += 1                                                             # isap_mac_domain_seperation
cycles_enc += Nm*(64//CCW)+Nm*12//UROL                                      # absorb + process complete CT blocks
cycles_enc += Inm*(int(((Blm*8+CCW-8)/CCW))+12//UROL)                       # absorb + process incomplete CT blocks
cycles_enc += (Inm==0)*12//UROL                                             # absorb empty CT block with padding
cycles_enc += 1                                                             # isap_rk_setup_state
cycles_enc += 12//UROL                                                      # isap_rk_initialize
cycles_enc += 127//UROL                                                     # isap_rk_rekeying
cycles_enc += 12//UROL                                                      # isap_rk_squeeze
cycles_enc += 1                                                             # isap_mac_finalize_after_rk_setup
cycles_enc += 12//UROL                                                      # isap_mac_finalize_permute_ph
cycles_enc += 128//CCW                                                      # extract_tag

print('cycles_enc: ' + str(cycles_enc))

cycles_dec = 128//CCW                                                       # store_key
cycles_dec += 128//CCW                                                      # store_nonce
cycles_dec += 1                                                             # isap_mac_state_setup
cycles_dec += 12//UROL                                                      # isap_mac_initialize
cycles_dec += 1                                                             # isap_wait_input
cycles_dec += Na*12//UROL + Na*(64//CCW)                                    # absorb + process complete AD blocks
cycles_dec += Ina*(int(((Bla*8+CCW-8)/CCW))+12//UROL)                       # absorb + process incomplete AD blocks                       
cycles_dec += (Ina==0)*12//UROL                                             # absorb empty AD block with padding           
cycles_dec += 1                                                             # isap_mac_domain_seperation   
cycles_dec += Nc*12//UROL + Nc*(64//CCW)                                    # absorb + process complete CT blocks  
cycles_dec += Inc*(int(((Blc*8+CCW-8)/CCW))+12//UROL)                       # absorb + process incomplete CT blocks
cycles_dec += (Inc==0)*12//UROL                                             # absorb empty CT block with padding
cycles_dec += 1                                                             # isap_rk_setup_state
cycles_dec += 12//UROL                                                      # isap_rk_initialize
cycles_dec += 127//UROL                                                     # isap_rk_rekeying
cycles_dec += 12//UROL                                                      # isap_rk_squeeze 
cycles_dec += 1                                                             # isap_mac_finalize_after_rk_setup 
cycles_dec += 12//UROL                                                      # isap_mac_finalize_permute_ph 
cycles_dec += 128//CCW                                                      # verify_tag  
cycles_dec += 1                                                             # wait_ack   
cycles_dec += ((Nc>0)|(Inc>0))*1                                            # isap_rk_setup_state
cycles_dec += ((Nc>0)|(Inc>0))*12//UROL                                     # isap_rk_initialize
cycles_dec += ((Nc>0)|(Inc>0))*127//UROL                                    # isap_rk_rekeying
cycles_dec += ((Nc>0)|(Inc>0))*12//UROL                                     # isap_rk_squeeze
cycles_dec += ((Nc>0)|(Inc>0))*1                                            # isap_enc_initialize
cycles_dec += ((Nc>0)|(Inc>0))*(Nc*6//UROL + Nc*64//CCW)                    # squeeze complete MSG blocks
cycles_dec += ((Nc>0)|(Inc>0))*(Inc*(int(((Blc*8+CCW-8)/CCW))+6//UROL))     # squeeze incomplete MSG blocks               

print('cycles_dec: ' + str(cycles_dec))

# asconhashav12
PA = 12
PB = 8
R = 64

cycles_hash = PA//UROL                                      # initialization
cycles_hash += Na*PB//UROL + Na*(R//CCW)                    # absorb + process complete AD blocks  
cycles_hash += Ina*(int(((Bla*8+CCW-8)/CCW)) + PB//UROL)    # absorb + process incomplete AD blocks
cycles_hash += (Ina==0)*PA//UROL                            # absorb empty AD block with padding
cycles_hash += (Ina==1)*(PA-PB)//UROL                       # last process before squeeze has PA rounds
cycles_hash += 64//CCW*4                                    # Squeeze Hash
cycles_hash += PB//UROL*3

print('cycles_hash: ' + str(cycles_hash))
