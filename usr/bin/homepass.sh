#!/bin/sh
# HomePass for OpenWRT. Forked from https://github.com/trusk89/openwrt-homepass
# This script can be called in multiple ways (as script / via cron /system-service(e.g init.d)) to accommodate different setups / use-cases

# /etc/homepass.lists/default must contain at least one line with a MAC.
# !! THIST IS DIFFERENT THAN THE ORIGINAL SCRIPT!!
# Optionally, you can specify a SSID after any MAC separating it with a tab.

# FYI - as of September 2016 and the 11.1 firmware update, it is being reported that "NZ@McD1" 
# no longer works as a Homepass Relay.

#####
#add multiple-instance-protection here
#####

DEFAULT_SSID="attwifi"
DEFAULT_LIST="default"
LIST_PATH="/etc/homepass.lists/"
#RUN_MODE=${1:-"once"}
#DELAY_TIME=${2:-120} 
#LOPP_TURNS=${3:-30}

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
    LIST_FILE=/etc/homepass.lists/default;
    fi
    
fi
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
else
   echo "We had a problem reading the MAC address from the list, aborting."
fi
