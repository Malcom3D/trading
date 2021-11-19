#!/bin/bash
# Telegram bot key and id
source ../etc/keys/telegram.key

# Main URL
BASE_URL="https://api.telegram.org/bot$API_KEY"
GET_URL="$BASE_URL/getUpdates"
SEND_URL="$BASE_URL/sendMessage"
ANSWER_URL="$BASE_URL/answerCallbackQuery"
EDIT_URL="$BASE_URL/editMessageText"
MENU_URL="$BASE_URL/setMyCommands"

# Common options
CANCEL=$(jo text="Cancel" callback_data="cancel")
ALL_ENABLED=$(jo -a $(jo text="AllEnabled" callback_data="all_enabled"))
ALL_STARTED=$(jo -a $(jo text="AllStarted" callback_data="all_started"))
CONTENT="Content-Type: application/json"

# logger funtion
log() {
	echo "$(date) $1" | tee -a /dev/null
}

# update bot commands menu
update_menu() {
	local MENU_BALANCE="$(jo command="/balance" description="Show balance")"
	local MENU_NEW="$(jo command="/new" description="Enable trading for selected crypto")"
	local MENU_DEL="$(jo command="/del" description="Disable trading for selected crypto")"
	local MENU_START="$(jo command="/start" description="Start bot for selected crypto")"
	local MENU_STOP="$(jo command="/stop" description="Stop bot for selected crypto")"
	local MENU_RESTART="$(jo command="/restart" description="Restart bot for selected crypto")"
	local MENU_STATUS="$(jo command="/status" description="Show bot status")"
	local MENU_MARGIN="$(jo command="/margin" description="Show bot margin")"
	local MENU_TRADES="$(jo command="/trades" description="Show trading history")"
	local MENU_HELP="$(jo command="/help" description="Show help text")"
	local COMMANDS="$(jo -a "$MENU_HELP" "$MENU_STATUS" "$MENU_MARGIN" "$MENU_TRADES" "$MENU_BALANCE" "$MENU_START" "$MENU_STOP" "$MENU_RESTART" "$MENU_NEW" "$MENU_DEL")"

	if [ $(curl -s -d commands="" -H "$CONTENT" -X POST $MENU_URL | jq .ok) ]
	then
		until $(curl -s -d "$(jo commands="$COMMANDS")" -H "$CONTENT" -X POST $MENU_URL | jq .ok)
		do
			log "DEBUG: Unable to update menu. Sleeping."
			sleep 1
		done
	fi
}

help() {
	local HELP="/help         Show this message"
	local STATUS="/status         Show bots status"
	local MARGIN="/margin         Show bots margin"
	local TRADES="/trades         Show trading history"
	local BALANCE="/balance         Show wallet balance"
	local START="/start          Start bot for selected crypto"
	local STOP="/stop           Stop bot for selected crypto"
	local RESTART="/restart		Restart running bots"
	local NEW="/new            Enable trading for selected crypto"
	local DEL="/del            Disable trading for selected crypto"
	printf "$HELP\n$STATUS\n$MARGIN\n$TRADES\n$BALANCE\n$START\n$STOP\n$RESTART\n$NEW\n$DEL"
}

# Get date of lastest message in buffer
last_msg() {
        curl -s -X GET $GET_URL | jq -r ' .result[-1] | if has("callback_query") then .callback_query.message else .message end | .date'
}

get_cmd() {
        curl -s -X GET $GET_URL | jq -r '.result[-1].message | select ( .entities[0].type=="bot_command" ) | .text'
}

send_msg() {
        until $(curl -s -X POST $SEND_URL -d chat_id=$CHAT_ID -d text="$1" | jq .ok)
        do
		log "DEBUG: Unable to send message. Sleeping."
		sleep 1
        done
}

change_last_msg() {
	local MESSAGE_ID=$(curl -s -X GET $GET_URL | jq -r '.result[-1] | .callback_query.message.message_id')
	until $(curl -s -d chat_id=$CHAT_ID -d message_id=$MESSAGE_ID -d text="$1" -X POST $EDIT_URL | jq .ok)
	do
		log "DEBUG: Unable to change last message. Sleeping."
		sleep 1
	done
}

update_msg() {
	local UPDATE_ID=$(curl -s -X GET $GET_URL | jq -r '.result[-1].update_id')
	local OFFSET=$(echo "$UPDATE_ID + 1" | bc)
	until $(curl -s -d offset=$OFFSET -X GET $GET_URL | jq .ok)
        do
                log "DEBUG: Unable to mark message as read. Sleeping."
                sleep 1
        done
}

send_quest() {
	JSON=$1
	until $(curl -s -d "$JSON" -H "$CONTENT" -X POST $SEND_URL | jq .ok)
	do
		sleep 1
	done
}

get_answer() {
	local STATUS=true
	while $STATUS
	do
		local ANS=$(curl -s -X GET $GET_URL | jq -r '.result[-1] | .callback_query | select(.data!=null) | .data')
		if [ -n "$ANS" ]
		then
			# Acknowledge the query
			local QUERY_ID=$(curl -s -X GET $GET_URL | jq -r '.result[-1] | .callback_query | select(.id!=null) | .id')
			if [ -n "$QUERY_ID" ]
			then
				if $(curl -s -d chat_id=$CHAT_ID -d callback_query_id=$QUERY_ID -X POST $ANSWER_URL | jq .ok)
				then
					local STATUS=false
				fi
			fi
		else
			sleep 1
		fi
	done
        if [ "$ANS" == "cancel" ]
        then
                local TEXT="Action cancelled by user."
                change_last_msg "$TEXT"
        else
		echo $ANS
	fi
}

bot_enabled() {
	local files=(../etc/config.d/enabled/*.json)
	if [ -e "${files[0]}" ]
	then
        	echo "$(ls ../etc/config.d/enabled/ | grep "\.json" | sed 's/\.json//')"
	fi
}

bot_started() {
	local started=""
	local enabled="$(bot_enabled)"
	if [ -n "$enabled" ]
	then
		for i in $enabled
		do
			if [ "$(./trade.sh status $i)" ]
			then
				local started="$started $i"
			fi
		done
	fi
	echo "$started"
}

bot_unstarted() {
	local started="$(bot_started)"
	local unstarted="$(bot_enabled)"
	for i in $started
	do
		local unstarted="$(echo $unstarted | sed "s/$i//")"
	done
	echo "$unstarted"
}

put_in_row() {
	ROW=""
	local BUTTONS=""
	local count=0
	for l in $1
	do
		local BUTTONS="$BUTTONS $(jo text="$l" callback_data="$l")"
		((count+=1))

		if [ "$count" -eq 4 ] && [ -z "$ROW" ]
		then
			ROW="$(jo -a $BUTTONS)"
			local BUTTONS=""
			local count=0
		elif [ "$count" -eq 4 ] && [ -n "$ROW" ]
		then
			ROW="$ROW $(jo -a $BUTTONS)"
			local BUTTONS=""
			local count=0
		fi
	done
	if [ -n "$BUTTONS" ]
	then
		ROW="$ROW $(jo -a $BUTTONS)"
	fi
	ROW="$(jo -a $CANCEL) $ROW"
}

new_quest() {
	# Currency list
	local CURR_LIST="EUR BUSD"

	# choose your currency
	local ROW=""
	put_in_row "$CURR_LIST"
	send_quest "$(jo chat_id=$CHAT_ID text="Select currency:" reply_markup=$(jo inline_keyboard=$(jo -a $ROW)))"
	local currency="$(get_answer)"
	local TEXT="Trading in $currency."
	change_last_msg "$TEXT"
	update_msg

	# choose your crypto coin
	local enabled="$(echo $(bot_enabled) | grep $currency | sed "s/$currency//" )"
	local availlable=$(ls ../etc/config.d/availlable/ | grep "$currency\.json" | sed "s/$currency\.json//")
	if [ -n "$enabled" ]
	then
		for i in $enabled
		do
			local availlable=$(echo $availlable | sed "s/$i //")
		done
	fi

	if [ -z "$availlable" ]
	then
		local TEXT="All bot enabled"
		send_msg "$TEXT"
	else
		local ROW=""
		put_in_row "$availlable"
		send_quest "$(jo chat_id=$CHAT_ID text="Select crypto to trade:" reply_markup=$(jo inline_keyboard=$(jo -a $ROW)))"
		new_answer $currency
	fi
}

new_answer() {
	local ANSWER=$(get_answer)
	local pair="$ANSWER$1"

	if [ -n "$ANSWER" ]
	then
		if [ "$(./trade.sh enable $pair)" ]
		then
			local TEXT="$ANSWER->$1 bot enabled."
		else
			local TEXT="WARNING: error enabling $ANSWER->$1 bot."
		fi
		change_last_msg "$TEXT"
	fi
}

del_quest() {
	local enabled="$(bot_enabled)"
	if [ -z "$enabled" ]
	then
		local TEXT="No bot enabled"
		send_msg "$TEXT"
	else
		local ROW=""
		put_in_row "$enabled"
	        send_quest "$(jo chat_id=$CHAT_ID text="Select pair to remove:" reply_markup=$(jo inline_keyboard=$(jo -a $ROW)))"
		del_answer
	fi
}

del_answer() {
        local ANSWER=$(get_answer)

        if [ -n "$ANSWER" ]
        then
		if [ "$(./trade.sh disable $ANSWER)" ]
		then
                	local TEXT="$ANSWER bot disabled."
		else
                	local TEXT="WARNING: error disabling $ANSWER bot."
		fi
                change_last_msg "$TEXT"
        fi
}

start_quest() {
	local unstarted="$(bot_unstarted)"
	if [ -z "$unstarted" ]
	then
		local TEXT="No bot enabled"
		send_msg "$TEXT"
	else
		local ROW=""
		put_in_row "$unstarted"
		local ROW="$ALL_ENABLED $ROW"
		send_quest "$(jo chat_id=$CHAT_ID text="Select crypto to trade" reply_markup=$(jo inline_keyboard=$(jo -a $ROW)))"
		start_answer
	fi
}

start_answer() {
        local ANSWER=$(get_answer)

        if [ -n "$ANSWER" ] && [ "$ANSWER" != "all_enabled" ]
        then
		if [ "$(./trade.sh start $ANSWER)" ]
		then
	                local TEXT="$ANSWER bot started."
		else
	                local TEXT="WARNING: error starting $ANSWER bot."
		fi
	        change_last_msg "$TEXT"
        elif [ -n "$ANSWER" ] && [ "$ANSWER" == "all_enabled" ]
	then
		local TEXT="Starting all enabled bot."
	        change_last_msg "$TEXT"
		start_all
	fi
}

start_all() {
	local unstarted="$(bot_unstarted)"
	if [ -n "$unstarted" ]
	then
		for i in $unstarted
		do
			if [ "$(./trade.sh start $i)" ]
			then
		                local TEXT="$i bot started."
			else
		                local TEXT="WARNING: error starting $i bot."
			fi
			send_msg "$TEXT"
		done
	else
		local TEXT="No bot enabled."
		send_msg "$TEXT"
	fi
}

stop_quest() {
	started="$(bot_started)"
	if [ -z "$started" ]
	then
		local TEXT="No running bot."
		send_msg "$TEXT"
	else
		local ROW=""
		put_in_row "$started"
       		local ROW="$ALL_STARTED $ROW"
       		send_quest "$(jo chat_id=$CHAT_ID text="Select crypto bot to stop" reply_markup=$(jo inline_keyboard=$(jo -a $ROW)))"
		stop_answer
	fi
}

stop_answer() {
        local ANSWER=$(get_answer)

        if [ -n "$ANSWER" ] && [ "$ANSWER" != "all_started" ]
        then
                if [ "$(./trade.sh stop $ANSWER)" ]
		then
	                local TEXT="$ANSWER bot stopped."
		else
	                local TEXT="WARNING: error stopping $ANSWER bot."
		fi
                change_last_msg "$TEXT"
        elif [ -n "$ANSWER" ] && [ "$ANSWER" == "all_started" ]
        then
		local TEXT="Stopping all started bot."
		change_last_msg "$TEXT"
		stop_all
	fi
}

stop_all() {
	local started="$(bot_started)"
	if [ -n "$started" ]
	then
		for i in $started
		do
			if [ "$(./trade.sh stop $i)" ]
			then
				local TEXT="$i bot stopped."
			else
				local TEXT="WARNING: error stopping $i bot stopped."
			fi
			send_msg "$TEXT"
		done
	else
		local TEXT="No running bot."
		send_msg "$TEXT"
	fi
}

restart_quest() {
	local started="$(bot_started)"
	if [ -z "$started" ]
	then
		local TEXT="No running bot."
		send_msg "$TEXT"
	else
		local ROW=""
		put_in_row "$started"
       		local ROW="$ALL_STARTED $ROW"
       		send_quest "$(jo chat_id=$CHAT_ID text="Select crypto bot to restart" reply_markup=$(jo inline_keyboard=$(jo -a $ROW)))"
		restart_answer
	fi
}

restart_answer() {
        local ANSWER=$(get_answer)

        if [ -n "$ANSWER" ] && [ "$ANSWER" != "all_started" ]
        then
                if [ "$(./trade.sh restart $ANSWER)" ]
                then
                        local TEXT="$ANSWER bot restarted."
                else
                        local TEXT="WARNING: error restarting $ANSWER bot."
                fi
                change_last_msg "$TEXT"
        elif [ -n "$ANSWER" ] && [ "$ANSWER" == "all_started" ]
        then
                local TEXT="Restart all enabled bot."
                change_last_msg "$TEXT"
		stop_all
		start_all
        fi
}

get_status() {
	local enabled="$(bot_enabled)"
	if [ -n "$enabled" ]
	then
	        for l in $enabled
	        do
	                if [ "$(./trade.sh status $l)" ]
	                then
				local TEXT=$(echo "$TEXT" && echo "$l bot is running")
			else
				local TEXT=$(echo "$TEXT" && echo "$l bot is not running")
			fi
		done
	else
		local TEXT="No bot enabled."
	fi
	send_msg "$TEXT"
}

get_margin() {
	local started="$(bot_started)"
	if [ -n "$started" ]
	then
		for l in $started
		do
			local info=$(tail -n 12 ../logs/$l.log | grep INFO | tail -1)
			local price=$(echo $info | cut -d"|" -f4 | cut -d":" -f2)
			local margin=$(echo $info | grep "Margin" | cut -d"|" -f5 | cut -d":" -f2)
			local profit=$(echo $info | grep "Profit" | cut -d"|" -f6 | cut -d":" -f2)
			if [ -n "$price" ] && [ -n "$margin" ] && [ -n "$profit" ]
			then
				if [[ $l =~ "BUSD$" ]]
				then
					val="\$"
				elif [[ $l =~ "EUR$" ]]
				then
					val="\€"
				fi
				local TEXT=$(echo "$TEXT" && echo "$l" && echo " - Price: $price $val" && echo " - Margin: $margin \%" && echo " - (P/L): $profit $val" && echo)
			fi
		done
		if [ -z "$TEXT" ]
		then
			TEXT="No trade for running bot"
		fi
	else
		local TEXT="No running bot."
	fi
	send_msg "$TEXT"
}

balance() {
	send_msg "$(./balance.sh)"
}

get_trades() {
	JSON="../logs/telegrambot/telegram_data/data.json"
	jq -r '.trades | keys' $JSON | sed -e '/\[/d' -e '/\]/d' -e 's/^  //' -e 's/\,//' | while read DATE
	do
		local PAIR=$(jq -r ".trades.$DATE | .pair" $JSON)
		local PRICE=$(jq -r ".trades.$DATE | .price" $JSON | sed 's/Close\://')
		local MARGIN=$(jq -r ".trades.$DATE | .margin" $JSON)
		local TEXT=$(echo $PAIR && echo $DATE && echo " - Sell Price: $PRICE€" && echo " - Margin: $MARGIN")
		send_msg "$TEXT"
	done
}

exit_all() {
	stop_all
	exit 0
}

log "INFO: Starting..."
send_msg "Starting all enabled bot..."
start_all

# update menu list with commands
log "DEBUG: Updating Menu"
update_menu

# set init var
LAST_MSG=$(last_msg)

send_msg "Your automatic trading solution is up&runnning"

log "DEBUG: starting main loop"
while true
do
	MSG="$(get_cmd)"
	if [ -n "$MSG" ]
	then
		log "INFO: Get Command: $MSG"
		case $MSG in
			/start)
				start_quest
			;;
			/stop)
				stop_quest
			;;
			/restart)
				restart_quest
			;;
			/status)
				get_status
			;;
			/margin)
				get_margin
			;;
			/trades)
				get_trades
			;;
			/new)
				new_quest
			;;
			/del)
				del_quest
			;;
			/balance)
				balance
			;;
			/help|/*)
				send_msg "$(help)"
			;;
			*)
				send_msg "Hei man, I'm only a bot"
			;;
		esac
		trap exit_all SIGINT SIGTERM SIGKILL
		update_msg
	fi
done
