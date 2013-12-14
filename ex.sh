#!/bin/bash
# $1	-	state

#functions
function SFP 
{
	#send fingerprint
	fp=$(gpg -k --fingerprint $id | grep -E '([a-fA-F0-9]{4} ){5} ([a-fA-F0-9]{4} ){4}[a-fA-F0-9]{4}' | tr -s " " | cut -d " " -f 5,6,7,8,9,10,11,12,13,14);
	echo "$fp" | minimodem -A --tx --ascii 300;
}

if [ "${1}" == "" ]; then
	#state 0	-	signalize ready to receive

	#ask for id and send it out
	D=$(dialog --stdout --inputbox "Which ID would you like to exchange?" 10 100 "olaf@ruehenbeck.org");
	id=$(gpg -K $D | grep sec | tr -s " " | cut -d " " -f 2 | cut -d "/" -f 2);
	echo $id | minimodem -A --tx --ascii 300;
	
	#go to state 1
	exec ${0} 1;
	
elif [ "${1}" == "1" ]; then
	#state 1	-	wait for receive
	
	#start minimodem with receive command
	minimodem -A --rx-one -q 300;
	
	#test for ID
	grep -E '^[a-fA-F0-9]{8}$' /tmp/mm_rx;
	if [ $? -eq 0 ]; then
		#go to state 2
		exec ${0} 2;
	fi
	
	#test for fingerprint (FORMAT: #### #### #### #### #### #### #### ####)
	grep -E '^([a-fA-F0-9]{4} ){5}([a-fA-F0-9]{4} ){4}[a-fA-F0-9]{4}$' /tmp/mm_rx;
	if [ $? -eq 0 ]; then
		#go to state 3
		exec ${0} 3;
	fi
	
	#rx failed, retry
	echo "Received data is not valid. Try again.";
	exec ${0} 1;

elif [ "${1}" == "2" ]; then
	#state 2	-	transfer fingerprint
	
	SFP;
	
	#go to state 1
	exec ${0} 1;

elif [ "${1}" == "3" ]; then
	#state 3	-	received fingerprint, send own over
	
	SFP;
	
	#go to state 4
	exec ${0} 4;
	
elif [ "${1}" == "4" ]; then
	#state 4	-	check received fingerprint
	
	#remote id
	rid=$(grep -E '([a-fA-F0-9]{4} ){5} ([a-fA-F0-9]{4} ){4}[a-fA-F0-9]{4}' | tr -s " " | cut -d " " -f 13,14 | tr -d " " /tmp/mm_rx);
	
	#local fingerprint
	gpg -k --fingerprint $rid | grep -E '([a-fA-F0-9]{4} ){5} ([a-fA-F0-9]{4} ){4}[a-fA-F0-9]{4}' | tr -s " " | cut -d " " -f 5,6,7,8,9,10,11,12,13,14 > /tmp/lfp;
	diff -a /tmp/lfp /tmp/mm_rx;
	
	#diff return value
	if [ $? -eq 0 ]; then
		#go to WIN
		exec ${0} WIN;
	else
		#go to FAIL
		exec ${0} FAIL;
	fi

elif [ "${1}" == "WIN" ]; then
	echo "Fingerprint verification successfull!";
	rm /tmp/{mm_rx,lfp};

elif [ "${1}" == "FAIL" ]; then
	echo "Fingerprint verification failed!";
	rm /tmp/{mm_rx,lfp};
	
	#go to state 1
	exec ${0} 1;

else
	echo "Not implemented.";
fi
