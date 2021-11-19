#!/bin/bash
# Telegram bot key and id
source ../etc/keys/telegram.key

# variable
DirName=$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)

# Define function

exit_all() {
	echo $oldIP > $DirName/../etc/ipcheck/ip.txt
	exit 0
}

ipCheck() {
	oldIP=$(cat $DirName/../etc/ipcheck/ip.txt)
        while $True;
        do
                nowIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
                if [ "$nowIP" != "$oldIP" ] && [[ "$nowIP" != *"timed out"* ]]
                then
                        curl -s "https://api.telegram.org/bot$API_KEY/sendMessage?chat_id=$CHAT_ID&text=Warning: Public IP changed! New IP: $nowIP."
                        curl -s "https://api.telegram.org/bot$API_KEY/sendMessage?chat_id=$CHAT_ID&text=Open the following link and change API restriction."
                        curl -s "https://api.telegram.org/bot$API_KEY/sendMessage?chat_id=$CHAT_ID&text=https://www.binance.com/en/my/settings/api-management"
                        oldIP=$nowIP
                fi
		trap exit_all SIGINT SIGTERM SIGKILL
                sleep 15
        done
}

ipCheck
