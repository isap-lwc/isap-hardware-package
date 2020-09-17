# Using readlines() 
file1 = open('pdi.txt', 'r') 
Lines = file1.readlines() 
  
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

for line in Lines: 
    print(line.strip())

