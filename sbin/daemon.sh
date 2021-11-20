#!/bin/bash
# Define some variable
DirName=$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)
ScriptName=$(basename "$0")

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
	git fetch origin > /dev/null 2>&1
	if [ -n "$(git log HEAD..origin/main --oneline)" ]
	then
		git pull > /dev/null 2>&1
		git pull --recurse-submodules > /dev/null 2>&1
		git submodule update --remote --merge > /dev/null 2>&1
		cd $DirName/../lib/cryptobot
		source $DirName/../bin/activate
		python -m pip install -r requirements.txt -U > /dev/null 2>&1
		deactivate
		sudo /sbin/systemctl restart trading
	fi
}

exit_all() {
	screen -S ipCheck -X quit
	screen -S TelegramBot -X quit
	exit 0
}

init() {
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
		init_git
		sleep 15
	done
}

init_git
init
