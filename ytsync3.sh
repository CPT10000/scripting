#Micheal Young
#2019-01-01
#Script to move downloaded music from temp directory to Media directory folder.
#$1 = Subfolder for music
#!/bin/bash

#Define variables
year=$(date +"%Y")
dest="mike@192.168.1.252::IST4/mike_music/"

#Update the beets catalog
#make sure ~/beets_library is mounted first!
if grep -qs '/home/mike/beets_library' /proc/mounts; then
        beet import -sgi /home/mike/ytdl
else	
	echo "Beet library folder not mounted! Quitting"
	exit
fi

#Check if a subfolder is specified
if [ -z $1 ]; then
	#Transfer music files to server foler via rsync
	rsync -ru --remove-source-files ~/ytdl/ "$dest$year/" --password-file /home/mike/rsync_pass
else
	rsync -ru --remove-source-files ~/ytdl/ "$dest$1/" --password-file /home/mike/rsync_pass
fi
