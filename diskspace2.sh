#!/bin/bash
# Mike Young
#2020-01-08
#DEPEND: sendmail
#Runs hourly though cron
#sets /$scriptdir/space_warning.flg flag and emails via nullmailer when a disk is
#       above $threshold capacity. Deletes flag when space issue is resolved.
#       Does not email while flag exists.

admin_addr="CPT10000@mail.lan"
threshold=90
scriptdir=/opt

IFS='
'
flg_st=0
echo "Subject: Space Issues Report for $HOSTNAME on $(date +%c)" > $scriptdir/space_report.txt
echo "" >> $scriptdir/space_report.txt
for x in `df -h -x tmpfs -x devtmpfs`; do
	if [ ${x:0:10} == "Filesystem" ]; then
		echo $x >> $scriptdir/space_report.txt
		continue
	fi
	space=$(echo $x | awk '{ print substr($5,0,2) }')
	if [ $space -gt $threshold ]; then
		echo $x >> $scriptdir/space_report.txt
		flg_st=1
	fi
done

if [ "$flg_st" == "0" ]; then
	if [ -f $scriptdir/space_warning.flg ]; then
        	rm $scriptdir/space_warning.flg
	fi
elif [ "$flg_st" == "1" ]; then
	if [ ! -f $scriptdir/space_warning.flg ]; then
		touch $scriptdir/space_warning.flg
        	sendmail $admin_addr < "$scriptdir/space_report.txt"
	fi
fi
