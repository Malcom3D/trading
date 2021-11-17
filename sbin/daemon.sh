#!/bin/bash
# Define some variable
DirName=$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)

# Telegram bot key and id
source $DirName/../etc/keys/telegram.key

# Define function

init_ipCheck() {
	cd $DirName
	screen -dmS ipCheck ./ipCheck.sh
}

init_TelegramBot() {
	cd $DirName
	screen -dmS TelegramBot ./telegrambot.sh
}

init_git() {
	cd $DirName/../
	git pull --recurse-submodules &>/dev/null
}

exit_all() {
	screen -S ipCheck -X quit
	screen -S TelegramBot -X quit
	exit 0
}

init() {
	init_git
	while true
	do
		screen -wipe &>/dev/null
		for i in ipCheck TelegramBot
		do
			if ! [ "$(screen -ls | grep $i)" ]
			then
				init_$i
			fi
		done
		trap exit_all SIGINT SIGTERM SIGKILL
		sleep 15
	done
}

init
