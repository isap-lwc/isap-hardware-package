import random

newkey = [True,False]
decrypt = [True,False]
adlen = [0,1,2,3,4,5,6,7,8,9,15,16,17,23,24,25,31,32,33]
ptlen = [0,1,2,3,4,5,6,7,8,9,15,16,17,23,24,25,31,32,33]
hashmode = [True,False]

lines = []

for k in newkey:
    for d in decrypt:
        for a in adlen:
            for p in ptlen:
                for h in hashmode:
                    if h == True and k == False:
                        continue
                    lines.append(f'{k},\t{d},\t{a},\t{p},\t{h}:')

random.shuffle(lines)
lines[-1] = lines[-1][:-1]

for l in lines:
    print(l)

