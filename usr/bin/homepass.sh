#!/bin/sh
# HomePass for OpenWRT. Forked from https://github.com/trusk89/openwrt-homepass
# This script can be called in multiple ways (as script / via cron /system-service(e.g init.d)) to accommodate different setups / use-cases

# /etc/homepass.lists/default must contain at least one line with a MAC.
# !! THIST IS DIFFERENT THAN THE ORIGINAL SCRIPT!!
# Optionally, you can specify a SSID after any MAC separating it with a tab.

# FYI - as of September 2016 and the 11.1 firmware update, it is being reported that "NZ@McD1" 
# no longer works as a Homepass Relay.

rs="\e[0m"
yl="\e[1;33m"
rd="\e[0;31m"
gr="\e[1;32m"
bl="\e[1;34m"

DEFAULT_SSID="attwifi"
DEFAULT_LIST="default"
DEFAULT_LIST_ONLINE="https://raw.githubusercontent.com/LukeSkywalk3r/openwrt-homepass/master/etc/homepass.lists/default"
LIST_PATH="/etc/homepass.lists/"
DELAY_TIME=${2:-120} 
LOOP_TURNS=${3:-30}

RUN_MODE=${1:-"once"}



if [[ $RUN_MODE = "help" ]]; then
    echo "Usage:"
    echo "$(basename $0) [run-mode [delay [turns]]]"
    echo "  run-mode:"
    echo "      help         -  displays this"
    echo "      setup        -  run the setup (recommended for first time)"
    echo "      update-list  -  updates the MAC-list, gets it from GitHub-Repo"
    echo "      once         -  sets the next MAC (no delay, no turns) (default)"
    echo "      loop         -  loops trough MACs (optional delay, optional turns)"
    echo "      conti        -  loops trough MACs until stopped(optional delay, no turns)"
    echo -e "\n  delay:"
    echo "      number in seconds to wait between MAC-Changes (default 120)"
    echo "  turns:"
    echo "      how many MAC-Chnages will happen (default 30)"
    
    
    exit 0
fi


if [[ $RUN_MODE = "setup" ]]; then
	echo -e $yl"Running Setup..."$rs
    echo -e $bl"Looking for a list file"$rs
	if [ -e $LIST_PATH$DEFAULT_LIST ]; then
		echo -e $gr"Default list exists.\n\rSkipping it's update."$rs
	else
		echo -e $rd"Default list doesn't exist."$rs
		mkdir -p $LIST_PATH
		if [[ -e /etc/homepass.list ]]; then
			echo -e $gr"Found /etc/homepass.list"$rs"\n\rWhat shall I do?"
			USR_IN=false
			while [ ! $USR_IN ]; do
				echo -e $rs"[m]ove it, [c]opy it, [l]ink it, [i]gnore & download new (recommended)\n\r:>"
				read -p -n 1 do_what
				USR_IN=true
				case $do_what in
					[mM]) mv /etc/homepass.list $DEFAULT_PATH$DEFAULT_LIST;;
					[cC]) cp /etc/homepass.list $DEFAULT_PATH$DEFAULT_LIST;;
					[lL]) ln -s /etc/homepass.list $DEFAULT_PATH$DEFAULT_LIST;;
					[iI]) ;;
					*) USR_IN=false
						echo "Your input is not valid.";;
				esac
			done
		else
            echo "Downloading new List..."
            wget -O $DEFAULT_PATH$DEFAULT_LIST $DEFAULT_LIST_ONLINE
        fi
        
	fi 
    #Network setup
    echo -e $yl"Starting Network Setup"
    echo -e $bl"Looking for usable Networks"$rs
    WIFI=$(uci show wireless | grep -i "homepass" | awk 'NR>1{print $1}' RS=[ FS=] | head -n 1)
    if [ -z "$WIFI" ]; then
        echo -e $bl"Looking for 'legacy'-networks..."$rs
        WIFI=$(uci show wireless | grep -i "NZ@McD1" | awk 'NR>1{print $1}' RS=[ FS=] | head -n 1)
        if [ -z "$WIFI" ]; then
            WIFI=$(uci show wireless | grep -i "$DEFAULT_SSID" | awk 'NR>1{print $1}' RS=[ FS=] | head -n 1)
            if [ -z "$WIFI" ]; then  
                WIFI=$(uci show wireless | grep -i "\.profile=" | awk 'NR>1{print $1}' RS=[ FS=] | head -n 1)
                if [ -z  "$WIFI"]; then
                    echo -e $rd"No network found to safely use."
                    echo -e "Please set up a WiFi network I can use, with the name \"homepass\" on the routers webinterface"$rs
                    exit
                fi
            fi 
        fi
    fi
    uci set wireless.@wifi-iface[$((WIFI))].homepass=1
    echo "Done! Everything is set up!"
    echo "Script is finished, and closes now."
	exit 0
fi

if [[ $RUN_MODE = "update-list" ]]; then
    echo -e $bl"Updating list..."$rs
    rm -f $DEFAULT_PATH$DEFAULT_LIST
    wget -O $DEFAULT_PATH$DEFAULT_LIST $DEFAULT_LIST_ONLINE
    echo -e $gr"Done! Exiting"$rs
    exit 0
fi
###

if [ -s $3 ] ; then
    LIST_FILE=$3;
  else
    if [ -s $LIST_PATH$3]; then
      LIST_FILE=$LIST_PATH$3
    else
      if [ ! -s $LIST_PATH$DEFAULT_LIST ]; then
        echo "MAC address list is missing or zero in length."
        exit
      fi
    LIST_FILE=$DEFAULT_PATH$DEFAULT_LIST;
    fi
    
fi
echo $LIST_FILE
LENGTH=$(wc -l < $LIST_FILE)
DATE=$(date)

# The WiFi network number we need to toggle the MAC address of
# This will NOT use the first wifi in access point mode (ap)
# it will find any wifis that have the SSID "homepass" (capitalization ignored) or a property named "homepass" (with any 'dummy'-value) 
# #################
# "OpenWRT can run multiple SSIDs (with their own config) on the same network chipset. 
# I set up a new SSID for Homepass and noticed that your script scans for the first "mode='ap'", 
# which was my main AP. I changed the script to use the dedicated ID (2 in my case). 
# You might add a word of notice about that "Multi-AP"-Feature, for some people that are not that 
# good with OpenWRT."
# #################
# this was my comment to trusk89. But now I use a different approach. This script gets any network that has
# a key or value named "homepass" (capitalization ignored). This is necessary to always get the correct network,
# even when the SSID changes, if one would run a Multi-AP-Setup.

WIFI=$(uci show wireless | grep -i "homepass" | awk 'NR>1{print $1}' RS=[ FS=] | head -n 1)





if [ -z "$WIFI" ]; then
  echo "Unable to identify the WiFi configuration for the Nintendo Zone network!"
  echo "Please make sure you have configured a Nintendo Zone WiFi access point (ssid \"homepass\") before running this script."
  exit
fi

#To find the network, if the script is re-run.
uci set wireless.@wifi-iface[$((WIFI))].homepass=1

#Just to be sure. If one would turn it off over night or something.
uci set wireless.@wifi-iface[$((WIFI))].disabled=0

k=0
case $RUN_MODE in
        "loop") ;;
        "once") ;;
        "conti") LOOP_TURNS=10;;
        *) echo -e $rd"Your input is not valid."$rs; exit ;;
esac

               
while [ $k -lt $LOOP_TURNS] ; do

        # If no profile was manually specified then read it from uci
        if [ -z "$1" ]; then
           I=$(uci get wireless.@wifi-iface[$((WIFI))].profile)
           # If there is no uci entry then we start from scratch
           if [ -z "$I" ]; then
              I=1
           else
             I=$((I+1))
           fi
           # If we went over the last profile we reset back to $MIN
           if [ $I -gt $LENGTH ]; then
              I=1
           fi
        else
           I=$1
        fi

        # Read MAC address number $I from the list
        MAC=$(sed -n $((I))p $LIST_FILE | awk '{print $1}' FS="\t")
        # Make sure we actually got a MAC address from the list
        if [ -n "$MAC" ]; then
           # Check if the list also specifies a SSID for this MAC
           SSID=$(sed -n $((I))p $LIST_FILE | awk '{print $2}' FS="\t")
           if [ -n "$SSID" ]; then
              echo "$DATE: Setting profile $I. Found in list ssid $SSID for mac $MAC"
           else
              # otherwise, use the default
              SSID="$DEFAULT_SSID"
              echo "$DATE: Setting profile $I. Using default ssid $SSID for mac $MAC"
           fi
           # Save a custom config called profile so that we know where we are in the list next time
           uci set wireless.@wifi-iface[$((WIFI))].profile=$I
           # Save the new MAC address
           uci set wireless.@wifi-iface[$((WIFI))].macaddr=$MAC
           uci set wireless.@wifi-iface[$((WIFI))].ssid="$SSID"
           # Restart the WiFi
           wifi
           exit
        else
           echo "We had a problem reading the MAC address from the list, aborting."
           exit
        fi
        
    case $RUN_MODE in
        "once") k=$LOOP_TURNS;;
        "loop") ((k++));;
        "conti") ;;
        *) echo -e $rd"Your input is not valid."$rs; exit ;;
    esac
done