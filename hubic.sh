#!/bin/bash
URL="EDIT_HERE"
CLIENTID="EDIT_HERE"
CLIENTSECRET="EDIT_HERE"
CREDENTIALS=$( printf "$CLIENTID:$CLIENTSECRET" | base64 -w 0 )

urlen() {
    # Thanks https://gist.github.com/cdown/1163649
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%s' "$c" | xxd -p -c1 |
                   while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

function setup () {
	# Obtain request code
	OAUTH=$( curl -s --get "https://api.hubic.com/oauth/auth/" --data-urlencode "client_id=$CLIENTID" --data-urlencode "redirect_uri=$URL" --data-urlencode "scope=usage.r,account.r,getAllLinks.r,credentials.r,sponsorCode.r,activate.w,sponsored.r,links.drw" --data-urlencode "response_type=code" --data-urlencode "state=RandomString_mpOwM8gSJD" | grep "name=\"oauth\"" | cut -d" " -f4 | cut -c8-13 )
	if [ $? -ne 0 ]; then
		echo "Error getting request code, verify credentials"
		exit 1
	fi

	# Accepting the app itself for the request token
	REQUESTTOKEN=$( curl -s -i "https://api.hubic.com/oauth/auth/" --data-urlencode "oauth=$OAUTH" --data-urlencode "action=accepted" --data-urlencode "account=r" --data-urlencode "credentials=r" --data-urlencode "getAllLinks=r" --data-urlencode "links=r" --data-urlencode "links=w" --data-urlencode "usage=r" --data-urlencode "login=ernesto@catalogomty.com" --data-urlencode "user_pwd=iodkaxpq1-" --data-urlencode "submit=Accept" | grep Location | cut -c11- | grep code | cut -d"=" -f2 | cut -d"&" -f1 )
	if [ $? -ne 0 ]; then
			echo "Error getting Request Token, try again later"
			exit 1
	fi

	# Obtaining the auth code	
	AUTHCODE=$( curl -s "https://api.hubic.com/oauth/token/" -H "Authorization: Basic $CREDENTIALS" --data-urlencode "code=$REQUESTTOKEN" --data-urlencode "redirect_uri=$URL" --data-urlencode "grant_type=authorization_code" | cut -d"\"" -f10 )
	if [ $? -ne 0 ] || [ "$AUTHCODE" == "" ]; then
			echo "Error $? getting Auth Code, try again later."
			exit 1
	fi

	#Obtaining endpoint and token
	curl -s -H "Authorization: Bearer $AUTHCODE" https://api.hubic.com/1.0/account/credentials > /tmp/paso1.txt
	if [ $? -ne 0 ] || [ $( cat /tmp/paso1.txt | grep invalid ) ] ; then
		echo "Error $? getting token, check your AuthCode"
		echo "Debug: "
		cat /tmp/paso1.txt
		echo "***********************************"
		rm /tmp/paso1.txt
		exit 1
	fi

	TOKEN=$( cat /tmp/paso1.txt | cut -d"\"" -f4 )
	ENDPOINT=$( cat /tmp/paso1.txt | cut -d"\"" -f8 )

	#Deleting temp file
	rm /tmp/paso1.txt
}

if [ $# == 0 ]; then
		echo "hubiC cli manager - NetoMX v0.1"
        echo "Usage: $0 [-l / -d / -u] [FILE]"
        exit 1
fi

if [ "$1" == "-d" ] || [ "$1" == "-u" ] && [ $# != 2 ]; then
		echo "hubiC cli manager - NetoMX v0.1"
        echo "Usage: $0 [-l / -d / -u] [FILE]"
        exit 1
fi

case "$1" in
"-d")	echo "Downloading file: $2"
		setup
		FILENAME=$( urlen "$2" )
		curl -s -g -H "X-Auth-Token: $TOKEN" "$ENDPOINT/default/$FILENAME" -X GET -o "$2"
		if [ $? -ne 0 ]; then
			echo "Error $? downloading file: $1" 
			exit 1
		fi
		exit 0
    ;;
"-u")	echo "Uploading file: $2"
		setup
		curl -s -g -H "X-Auth-Token: $TOKEN" "$ENDPOINT/default/"  -X PUT -T "$2"
		if [ $? -ne 0 ]; then
			echo "Error $? subiendo archivo $2" 
			exit 1
		fi
		exit 0
	;;
"-l")	echo "Listing files:"
		setup
		curl -s -H "X-Auth-Token: $TOKEN" $ENDPOINT/default?format=json -X GET | python -m json.tool
		if [ $? -ne 0 ]; then
			echo "Error $? listing files" 
			exit 1
		fi
		exit 0
	;;
*)		echo "Error: argument not recognized."
		echo "Usage: $0 [-l / -d / -u] [FILE]"
		exit
	;;
esac		
