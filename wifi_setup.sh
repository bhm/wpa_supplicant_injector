#!/bin/bash

EMPTY=""
NO_IMAGE=3
WRONG_IMAGE_OFFSET=4
MOUNT_POINT="temporary_raspbian_mount_point"
YES="yes"
NO="no"

WPA_SUPPLICANT_CONF="$MOUNT_POINT/etc/wpa_supplicant/wpa_supplicant.conf"
WPA_SUPPLICANT_CONF_BACKUP="$WPA_SUPPLICANT_CONF.bak"

if (( $EUID != 0 )); then 
   echo "This must be run as root. Try 'sudo bash $0'." 
   exit 1 
fi


echo "
$(tput setaf 2)              .~~.   .~~.
$(tput setaf 6)   /         $(tput setaf 2)'. \ ' ' / .'$(tput setaf 6)         \ 
$(tput setaf 6)  |   /       $(tput setaf 1).~ .~~~..~.$(tput setaf 6)       \   |
$(tput setaf 6) |   |   /  $(tput setaf 1) : .~.'~'.~. :$(tput setaf 6)   \   |   |
$(tput setaf 6)|   |   |   $(tput setaf 1)~ (   ) (   ) ~$(tput setaf 6)   |   |   |
$(tput setaf 6)|   |  |   $(tput setaf 1)( : '~'.~.'~' : )$(tput setaf 6)   |  |   |
$(tput setaf 6)|   |   |   $(tput setaf 1)~ .~ (   ) ~. ~ $(tput setaf 6)  |   |   |
$(tput setaf 6) |   |   \   $(tput setaf 1)(  : '~' :  )$(tput setaf 6)   /   |   |
$(tput setaf 6)  |   \       $(tput setaf 1)'~ .~~~. ~'$(tput setaf 6)       /   |
$(tput setaf 6)   \              $(tput setaf 1)'~'$(tput setaf 6)              / 
               _       ______  ___       __________  _   ________
              | |     / / __ \/   |     / ____/ __ \/ | / / ____/
              | | /| / / /_/ / /| |    / /   / / / /  |/ / /_    
              | |/ |/ / ____/ ___ |   / /___/ /_/ / /|  / __/    
              |__/|__/_/   /_/  |_|   \____/\____/_/ |_/_/       
                                                                 
                         _____   __    ____________________
                        /  _/ | / /   / / ____/ ____/_  __/
                        / //  |/ /_  / / __/ / /     / /   
                      _/ // /|  / /_/ / /___/ /___  / /    
                     /___/_/ |_/\____/_____/\____/ /_/     $(tput sgr0)
                                                           
"

echo "$(tput setaf 6)This script will configure your Raspbian Lite Pi image with a wireless connection.$(tput sgr0)"
read -p "$(tput bold ; tput setaf 2)Press [Enter] to begin, [Ctrl-C] to abort...$(tput sgr0)"

IMAGE_PATH=$1

if [ "$IMAGE_PATH" == "$EMPTY" ]; then
  echo "$(tput setaf 6) ERROR: Please provide a path to a Raspbian Lite Image.$(tput sgr0)"    
  echo "$(tput setaf 6) Like this: sudo bash $0 /somepath/to/an/raspbian.img"
  exit $NO_IMAGE
fi

echo "$(tput setaf 6)Creating a temp mount point at $MOUNT_POINT.$(tput sgr0)"
mkdir $MOUNT_POINT

END_SECTOR=`fdisk -l $IMAGE_PATH | grep img2 | awk '{print $2}'`
BLOCK_SIZE=`fdisk -l $IMAGE_PATH | grep Sector | awk '{print $4}'`
EQUATION="$BLOCK_SIZE*$END_SECTOR"
MOUNT_OFFSET=`echo "$EQUATION" | bc`

echo "$(tput setaf 6)Mounting $1 at $MOUNT_POINT with offset $MOUNT_OFFSET.$(tput sgr0)"

mount -v -o offset=$MOUNT_OFFSET -t ext4 $1 $MOUNT_POINT

MOUNTING_RESULT=$?

function cleanup {
	rm -rf $MOUNT_POINT
}

if [ $MOUNTING_RESULT != 0 ]; then
	echo "$(tput setaf 6) There was error mounting the image. Run fdisk -l $IMAGE_PATH, look for img1 End column. Multiply by sectors. Default is 512. $(tput sgr0)"
	cleanup
	exit $WRONG_IMAGE_OFFSET
fi

echo "$(tput setaf 6)Lets setup WPA Supplicant with your access points.$(tput sgr0)"
SSID=$EMPTY
pwd1="0"
pwd2="1"
keep_adding=$NO

function resetPasswords {
	pwd1="0"
	pwd2="1"
}

echo "$(tput setaf 6) Backup of /etc/wpa_supplicant/wpa_supplicant.conf at $WPA_SUPPLICANT_CONF_BACKUP$(tput sgr0)"
mv $WPA_SUPPLICANT_CONF $WPA_SUPPLICANT_CONF_BACKUP

until [ "$pwd1" == "$pwd2" ]; do
	echo "$(tput bold ; tput setaf 2)Type a SSID (name) for your WiFi network, then press [ENTER]:$(tput sgr0)"
	read SSID
	if [ "$SSID" == "$EMPTY" ]; then
		echo "ERROR: SSID was empty"
		resetPasswords
		continue
	fi
  
  	echo "$(tput bold ; tput setaf 2)Type a password to access your WiFi network, then press [ENTER]:$(tput sgr0)"
  	read -s pwd1
	echo "$(tput bold ; tput setaf 2)Verify password to access your WiFi network, then press [ENTER]:$(tput sgr0)"
	read -s pwd2

	if [ "$pwd1" != "$pwd2" ]; then
		resetPasswords
		echo "$(tput bold: tput setaf 6)Passwords did not match.$(tput sgr0)"
		continue
	fi

  	echo "$(tput setaf 6)Updating wpa_supplicant configuration.$(tput sgr0)"
	echo "network={
	    ssid=\"$SSID\"
	    psk=\"$pwd1\"
	}
	
	" >> $WPA_SUPPLICANT_CONF

 	echo "$(tput bold ; tput setaf 2)Keep adding? (yes)/no [ENTER]:$(tput sgr0)"  	
	read keep_adding

	if [ "$keep_adding" == "y" ] || [ "$keep_adding" == "yes" ]; then
		resetPasswords
		continue
	elif [ "$keep_adding" == "" ]; then
		resetPasswords
		continue
	elif [ "$keep_adding" == "n" ] || [ "$keep_adding" == "no" ]; then
		break
	fi

done

echo "$(tput setaf 6)Unmount $MOUNT_POINT $(tput sgr0)"
umount $MOUNT_POINT
UNMOUNTED=$?

if [ $? -eq 0 ]; then
	echo "$(tput setaf 6)Removing $MOUNT_POINT $(tput sgr0)"
	rm -rf $MOUNT_POINT
fi

exit 0