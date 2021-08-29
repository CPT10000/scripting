#!/bin/bash
#Micheal Young
#2019-08-12
#Program to get public ip from google and update namesilo ddns.
#DEPENDS ON: curl
#2019-08-29 pass host as parameter to ddns script
#2019-10-01 Make sure the IP is different before updating
#2019-11-14 Merged ddns scripts and changed trigger to cron from systemd timers
#2020-01-10 Attempted to fix "failed to update" bug
#2020-01-11 Fixed bug where ip check only looks at first dns record
#2020-03-09 Added line for dependency
function dnslog {
        echo "$(date +%X) - $1" >> /var/log/ddns_namesilo
}

read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}

HOST=$2
DOMAIN=$1
APIKEY=""

#Build domain name
if [ -z "$HOST" ]; then
        FULLDOMAIN=$DOMAIN
else
        FULLDOMAIN=$HOST.$DOMAIN
fi

# Fetch DNS record ID
RESPONSE="$(curl -s "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=$APIKEY&domain=$DOMAIN")"
echo $RESPONSE > /opt/response.txt

x=0
while read_dom; do	
	if [[ $ENTITY = "ip" ]]; then
#Maybe enable this later and compare with the other one		
		newip=$CONTENT
	elif [[ $ENTITY = "host" ]]; then
		if [[ $CONTENT = "$FULLDOMAIN" ]]; then
			#echo HOST: $CONTENT
			x=1		
		fi
	elif [[ $ENTITY = "value" ]] && [[ $x = "1" ]]; then
		oldip=$CONTENT
		#echo IP:$CONTENT
		unset x
	fi
done < /opt/response.txt

dnslog "Namesilo DNS record for $FULLDOMAIN is $oldip"

#Get current ip (is available through namesilo api but this is easier to implement)
newip=$(curl -s https://ipecho.net/plain)

#save current ip to file
echo $newip > /opt/current_ip.txt
dnslog "Current IP for $HOST.$DOMAIN is $newip"
if [ "$newip" != "$oldip" ]; then
	IP=$newip
	
	#Isolate the first record ID
	RECORD_ID="$(echo $RESPONSE | sed -n "s/^.*<record_id>\(.*\)<\/record_id>.*<host>$FULLDOMAIN<\/host>.*$/\1/p")"

	# Update DNS record in Namesilo
	RESPONSE="$(curl -s "https://www.namesilo.com/api/dnsUpdateRecord?version=1&type=xml&key=$APIKEY&domain=$DOMAIN&rrid=$RECORD_ID&rrhost=$HOST&rrvalue=$IP&rrttl=7207")"

	# Check whether the update was successful
	echo $RESPONSE | grep -E "<code>(280|300)</code>" &>/dev/null
	if [ $? ]; then
	        dnslog "$FULLDOMAIN failed to update"
	else
	        dnslog "$FULLDOMAIN changed to $newip"
	fi
else
	dnslog "$FULLDOMAIN has not changed"
fi
