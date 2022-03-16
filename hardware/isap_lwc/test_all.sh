#!/bin/bash

declare -a arr=(
"test_v1.py"
"test_v1_8bit.py"
"test_v1_16bit.py"
"test_v1_lowlatency.py"
"test_v1_testmode1.py"
"test_v1_StP.py"
"test_v1_decfail.py"
"test_v2.py"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

for i in "${arr[@]}"
do
	echo "$i"
	res=$(python3 $i | grep "SIMULATION FINISHED")
	if [[ $res == *"PASS"* ]]; then
	  	printf "${GREEN}PASS!${NC}\n"
	else
		printf "${RED}FAIL!${NC}\n"
	fi
done

