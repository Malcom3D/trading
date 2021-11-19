#!/bin/bash

balance() {
	# source binance keys
	declare -a array=()
	m=0
	while IFS= read -r line; do
		array[i++]=$line
		# reading from file path
	done < "../etc/keys/binance.key"

	local APIKEY="${array[0]}"
	local APISECRET="${array[1]}"

	local RECVWINDOW=5000
	local TM=$(( $(date -u +%s) *1000))
	local GET_BALANCE_QUERY="recvWindow=$RECVWINDOW&timestamp=$TM"
	local GET_BALANCE_SIG=$(echo -n "$GET_BALANCE_QUERY" | openssl dgst -sha256 -hmac $APISECRET)
	local GET_BALANCE_SIG="$(echo $GET_BALANCE_SIG | cut -f2 -d" ")"

	local FULL_WALLET=$(curl -s -S -H "X-MBX-APIKEY: $APIKEY" -X GET "https://api.binance.com/api/v3/account?recvWindow=$RECVWINDOW&timestamp=$TM&signature=$GET_BALANCE_SIG")
	local ASSET=$(echo $FULL_WALLET | jq -r ".balances[] | select(.free>=\"0.00000001\") | .asset")

	local ESTIMATED="0"
	for i in $ASSET
	do
		# Get value
		local FREE=$(echo $FULL_WALLET | jq -r ".balances[] | select(.asset==\"$i\") | .free")
		local LOCKED=$(echo $FULL_WALLET | jq -r ".balances[] | select(.asset==\"$i\") | .locked")
		local VALUE=$(echo "$FREE + $LOCKED" | bc -l)
		if [[ $i =~ "BUSD" ]]
		then
			local CURR_PRICE=$(curl -s -S -X GET "https://api.binance.com/api/v3/ticker/price?symbol="$i"BUSD" | jq -r ".price")
			local VALUE_EUR=$(echo "scale=8;$VALUE * $PRICE * $CURR_PRICE" | bc -l)
		else
			local PRICE=$(curl -s -S -X GET "https://api.binance.com/api/v3/ticker/price?symbol="$i"EUR" | jq -r ".price")
			local VALUE_EUR=$(echo "scale=8;$VALUE * $PRICE" | bc -l)
		fi
		local ESTIMATED=$(echo "scale=8;$ESTIMATED + $VALUE_EUR" | bc -l)
		echo "$i: $VALUE"
	done
	echo
	echo "Total estimate balance: $ESTIMATED €"
}

balance
