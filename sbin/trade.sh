#!/bin/bash
# Define some variable
ScriptName=$(basename "$0")
DirName=$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)
ENABLED="$DirName/../etc/config.d/enabled"

# Telegram bot key and id
source $DirName/../etc/keys/telegram.key

# Define function

start() {
	cd $DirName/../lib/cryptobot/
	merge_config
	if ! [ "$(status)" ]
	then
		screen -dmS $MARKET $DirName/../sbin/$ScriptName trade $MARKET
		echo $?
	fi
}

trade() {
	source $DirName/../bin/activate
	rotate_log $MARKET

	if [ -e $DirName/../etc/trade.conf ]
	then
		source $DirName/../etc/trade.conf
	fi
	local LOG="$DirName/../logs/$MARKET.log"
	local TRACKER="$DirName/../logs/tracker/$MARKET.csv"
	until python3.9 pycryptobot.py --config /tmp/$MARKET.json $OPTIONS --telegramtradesonly --websocket --logfile $LOG --tradesfile $TRACKER
	do
		curl -s "https://api.telegram.org/bot$API_KEY/sendMessage?chat_id=$CHAT_ID&text=Warning: respawning $MARKET process"
		sleep 1
	done
}

stop() {
	screen -S $MARKET -X quit
	echo $?
}

enable() {
	cd $ENABLED
	ln -s ../availlable/$MARKET.json
	echo $?
}

disable() {
	unlink $ENABLED/$MARKET.json
	echo $?
}

rotate_log() {
        for k in $(seq 5 -1 0)
        do
                if [ "$k" -gt 0 ]
                then
                        lastOld="$MARKET.log.$k"
                else
                        lastOld="$MARKET.log"
                fi
                if [ -n "$lastOld" ] && [ -e "../logs/$lastOld" ]
                then
                        version=$[ $k +1 ]
                        mv $DirName/../logs/$lastOld $DirName/../logs/$MARKET.log.$version
                fi
        done
}

log() {
	cd $DirName
	LOGS=""
	for k in $(ls $ENABLED | sed 's/\.json//')
	do
		MARKET=$k
		local running=$(status)
		if [ -n "$running" ]
		then
			LOGS="$LOGS $k"
		fi
	done
	num=$(echo $LOGS | wc -w)
	if [ "$num" -gt 0 ]
	then
		lines=$[ 40 / $num ]
		for l in $LOGS
		do
			echo "==> $l.log <=="
			tail -n 100 $DirName/../logs/$l.log | egrep -v "$l$|BUSD$|EUR$|^$|DEBUG" | tail -n $lines
		done
	fi
}

status() {
	echo $(screen -ls | grep $MARKET)
}

merge_config() {
	local JSON=$(cat $ENABLED/$MARKET.json)
	local JSON=$(echo $JSON | jq --arg api_key "$API_KEY" '. += {telegram: {"token" : $api_key}}')
	local JSON=$(echo $JSON | jq --arg chat_id "$CHAT_ID" '.telegram += {"client_id" : $chat_id, "user_id" : $chat_id, "datafolder": "../../logs/telegrambot"}')
	echo $JSON > /tmp/$MARKET.json
}

# Check passed argument
if [ "$1" != "log" ] && [ -z "$2" ]
then
	exit 1
else
	MARKET=$2
fi

case $1 in
	trade)
		trade
	;;
	start)
		start
	;;
	stop)
		stop
	;;
	status)
		status
	;;
	restart)
		stop
		start
	;;
	enable)
		enable
	;;
	disable)
		disable
	;;
	log)
		log
	;;
	*)
		exit 1
	;;
esac
