#!/bin/bash
# Define some variable
DirName=$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)
ScriptName=`basename "$0"`

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
	if [ $(git rev-parse HEAD) != $(git rev-parse @{u}) ]
	then
		git pull > /dev/null 2>&1
		git pull --recurse-submodules > /dev/null 2>&1
		git submodule update --remote --merge > /dev/null 2>&1
		cd $DirName/../lib/cryptobot
		source ../bin/activate
		python -m pip install -r requirements.txt -U > /dev/null 2>&1
		deactivate
		sudo systemctl restart trading
	fi
}

stop_ipCheck() {
	screen -S ipCheck -X quit
}

stop_TelegramBot() {
	screen -S TelegramBot -X quit
}

exit_all() {
	stop_ipCheck
	stop_TelegramBot
	exit 0
}

init() {
	count=0
	init_git
	while true
	do
		screen -wipe > /dev/null 2>&1
		for i in ipCheck TelegramBot
		do
			if ! [ "$(screen -ls | grep $i)" ]
			then
				init_$i
			fi
		done
		trap exit_all SIGINT SIGTERM SIGKILL
		((count++)
		if [ $count == 2880 ]
		then
			init_git
		fi
		sleep 15
	done
}

init
