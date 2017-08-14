#!/bin/bash

# Consts
EMPTY=""
EXPECTED_MIME_TYPE="application/octet-stream"
SSID_EMPTY_THRESHOLD_TO_EXIT=2

MOUNT_POINT="temporary_raspbian_mount_point"
WPA_SUPPLICANT_CONF="$MOUNT_POINT/etc/wpa_supplicant/wpa_supplicant.conf"
WPA_SUPPLICANT_CONF_BACKUP="$WPA_SUPPLICANT_CONF.bak"

# answers
YES="yes"
NO="no"

# Error Codes
NO_IMAGE=3
WRONG_IMAGE_OFFSET=5
MOUNT_POINT_EXISTS=7
WRONG_MOUNT_PARAM_SUPPLIED=13
STILL_MOUNTED=17
COUlD_NOT_UNMOUNT=23
COULD_NOT_CLEANUP_MOUNT_POINT=29

function main {
	check_if_root
	check_image_path $1
	if [ $? -ne 0 ]; then
		exit $?
	fi

	splash
	start_message	
	check_mount_point $MOUNT_POINT
	safe_cleanup $? $MOUNT_POINT

	create_mount $MOUNT_POINT
	mount_image $1 $MOUNT_POINT	
	if [ $? -eq 0 ]; then
		backup_wap_conf

		if [ $? -eq 0 ]; then
			setup_wpa_conf
		fi		
	fi

	check_mount_point $MOUNT_POINT
	safe_cleanup $? $MOUNT_POINT
}

function check_if_root {	
	if (( $EUID != 0 )); then 
	   echo "This must be run as root. Try 'sudo bash $0'." 
	   exit 1 
	fi
}

function check_image_path {
	if [ "$1" == "$EMPTY" ]; then
	  echo "$(tput setaf 6) ERROR: Please provide a path to a Raspbian Lite Image.$(tput sgr0)"    
	  echo "$(tput setaf 6) Call this script this way: $(tput setaf 2) sudo bash /somepath/to/an/raspbian.img$(tput sgr0)"
	  return $NO_IMAGE
	elif [ -d $1 ]; then
		echo "$(tput setaf 6) ERROR: You supplied a directory instead of a file with an IMG$(tput sgr0)"    
		return $WRONG_MOUNT_PARAM_SUPPLIED
	elif [ ! -e $1 ]; then
		echo "$(tput setaf 6) ERROR: Supplied path $1 does not exist $(tput sgr0)"    
		return $NO_IMAGE		
	fi

	local mime_type=`file -i $1 | grep $EXPECTED_MIME_TYPE`
	if [ -z "$mime_type" ]; then
		echo "$(tput setaf 6) ERROR: Wrong file supplied. Did not match application/octet-stream; charset=binary $(tput sgr0)"    
		return $WRONG_MOUNT_PARAM_SUPPLIED
	fi

	return 0
}

function splash {
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
}

function start_message {
	echo "$(tput setaf 6)This script will configure your Raspbian Lite Pi image with a wireless connection.$(tput sgr0)"
	read -p "$(tput bold ; tput setaf 2)Press [Enter] to begin, [Ctrl-C] to abort...$(tput sgr0)"
}

function check_mount_point {
	local is_still_mounted=`df | grep $1`

	if [ ! -z "$is_still_mounted" ]; then
		return $STILL_MOUNTED
	fi		

	return 0
}

function safe_unmount {
	umount $1
	return $?
}

function safe_remove {
	if [ -d $1 ]; then 
		rm -rf $1
		return $?		
	fi

	return $COULD_NOT_CLEANUP_MOUNT_POINT
}

function safe_cleanup {
	if [ $1 == $STILL_MOUNTED ]; then
		safe_unmount $2		
		if [ $? -ne 0 ]; then
			exit $COUlD_NOT_UNMOUNT
		fi

		safe_remove $2
		return $?
	fi
	return 0	
}

function create_mount {
	if [ -d $1 ]; then
		return $MOUNT_POINT_EXISTS
	else
		echo "$(tput setaf 6)Creating a temp mount point at $1.$(tput sgr0)"
		mkdir $1
	fi

	return $?
}

function mount_image {	
	local END_SECTOR=`fdisk -l $1 | grep img2 | awk '{print $2}'`
	local BLOCK_SIZE=`fdisk -l $1 | grep Sector | awk '{print $4}'`
	local EQUATION="$BLOCK_SIZE*$END_SECTOR"
	local MOUNT_OFFSET=`echo "$EQUATION" | bc`

	echo "$(tput setaf 6)Mounting $1 at $2 with offset $MOUNT_OFFSET.$(tput sgr0)"
	mount -v -o offset=$MOUNT_OFFSET -t ext4 $1 $2

	if [ $? -ne 0 ]; then
		echo "$(tput setaf 6) There was error mounting the image. Run fdisk -l $1.
		Look up the most end sector.
		Multiply it by sectors. 
		Default is 512. $(tput sgr0)"
	fi

	return $?
}

function backup_wap_conf {	
	if [ -e $WPA_SUPPLICANT_CONF ]; then	
		echo "$(tput setaf 6) Backing up $WPA_SUPPLICANT_CONF at $WPA_SUPPLICANT_CONF_BACKUP$(tput sgr0)"
		mv $WPA_SUPPLICANT_CONF $WPA_SUPPLICANT_CONF_BACKUP
		return $?
	fi

	return 0
}

function should_keep_adding {
	if [ "$1" == "y" ] || [ "$1" == "yes" ] || [ "$1" == "YES" ] || [ "$1" == "Y" ] || [ "$1" == "" ] ; then
		return 0	
	else 
		return 1
	fi
}

function setup_wpa_conf {
	echo "$(tput setaf 6)Lets setup WPA Supplicant with your access points.$(tput sgr0)"
	local ssid_empty_count=0
	local SSID=$EMPTY
	local keep_adding=$NO
	local pwd1="0"
	local pwd2="1"

	until [ "$pwd1" == "$pwd2" ]; do
		echo "$(tput bold ; tput setaf 2)Type a SSID (name) for your WiFi network, then press [ENTER]:$(tput sgr0)"
		read SSID
		if [ "$SSID" == "$EMPTY" ]; then
			ssid_empty_count=$(($ssid_empty_count+1))
			if [  $ssid_empty_count -ge $SSID_EMPTY_THRESHOLD_TO_EXIT ]; then
				break
			fi

			echo "ERROR: SSID was empty. Press [ENTER] once more to exit."
				pwd1="0"
				pwd2="1"
			continue
		fi
	  
	  	echo "$(tput bold ; tput setaf 2)Type a password to access your WiFi network, then press [ENTER]:$(tput sgr0)"
	  	read  pwd1
		echo "$(tput bold ; tput setaf 2)Verify password to access your WiFi network, then press [ENTER]:$(tput sgr0)"
		read  pwd2

		if [ "$pwd1" != "$pwd2" ]; then
			pwd1="0"
			pwd2="1"
			echo "$(tput bold: tput setaf 6)Passwords did not match.$(tput sgr0)"
			continue
		fi

	  	echo "$(tput setaf 6)Updating wpa_supplicant configuration.$(tput sgr0)"
		echo -e "network={\n\tssid=\"$SSID\"\n\tpsk=\"$pwd1\"\n}\n				
		" >> $WPA_SUPPLICANT_CONF

	 	echo "$(tput bold ; tput setaf 2)Keep adding? (yes)/no [ENTER]:$(tput sgr0)"  	
		read keep_adding
		should_keep_adding $keep_adding

		if [ $? -eq 0 ]; then
			pwd1="0"
			pwd2="1"
			continue
		else
			break
		fi

	done
}

main "$@"

exit $?