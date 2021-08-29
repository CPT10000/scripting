#!/bin/bash
# Mike Young
# 2021-07-29
# Recieves signal messages and downloads videos to a folder
# Signal messages admin on error
# Won't run if running flag exists.

#Variable declaration
log_fldr=/home/mike/signal_log
output=/home/mike/ytdl
#Server's signal account
signal_phone_no="+1"
#User phone number
auth_phone_no="+1"

function logfile(){
        day=$(date +%F)
        time=$(date +%T)
        echo "$$-$time-$1" >> $log_fldr/signal_$day.log
}
function msg_admin(){
	 signal-cli -u $signal_phone_no send -m "$1" $auth_phone_no
}

#quit if this is already running
if [ -f $log_fldr/running.flg ]; then
	logfile "CANCEL - $log_fldr/running.flg exists"
	exit
else
	touch $log_fldr/running.flg
fi

#Recieve signal messages
envelopes=$(signal-cli --output=json -u $signal_phone_no receive)

#Parse messages and load into array
for envelope in $envelopes; do
	if [ "null" == "$(echo $envelope | jq -r .envelope.dataMessage)" ]; then
		continue
	fi
	msg_source=$(echo $envelope | jq -r .envelope.source 2>&1)
	msg_text=$(echo $envelope | jq -r .envelope.dataMessage.message 2>&1)
	if [[ $msg_source == *"parse error:"* ]] || [[ $msg_text == *"parse error:"* ]]; then
		logfile "BAD ENVELOPE!"
		msg_admin "Bad envelope recieved!"
		continue
	elif [[ -z $msg_source ]] || [[ -z $msg_text ]]; then
		continue
	fi
	if [ "$msg_source" == "$auth_phone_no" ]; then
		if echo "$msg_text" | grep -E "^https:\/\/www\.youtube\.com\/watch\?[0-9,.a-z,A-Z,_,=]+" || \
		   echo "$msg_text" | grep -E "^https:\/\/youtu\.be\/[0-9,.a-z,A-Z,_]+"; then
			logfile "YT URL FROM $msg_source, $msg_text"
			result=$(youtube-dl --extract-audio --audio-format mp3 -o "$output/%(title)s.%(ext)s" $msg_text 2>&1)
			if echo "$result" | grep -i "error"; then
				logfile "YTERR: $result"
				msg_admin "YTERR while DLing $msg_text"
			else
				msg_admin "YTDL Complete $(echo "$result" | grep "ffmpeg")"
			fi
		else
			msg_admin "Error, message is not valid youtube URL: $msg_text"
		fi
	else
		logfile "RECV, $msg_source, $msg_text"
		continue
	fi
done

if [ -f $log_fldr/running.flg ]; then
	rm $log_fldr/running.flg
fi
