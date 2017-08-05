# Setup a WiFi access points for Raspberry Pi Zero W

## Elevator pitch
![Oh yes](https://media.tenor.com/images/25a78a23f6ff708b06b5cbe3718b03f5/tenor.gif)

Setup WiFi connections via an interactive script. 

In simpler terms. Add WiFi names and passwords to your Raspi Zero W

## Motivation

With Raspian Lite this gets old. Real quick.

## Do it

1. Grab a copy of Raspbian Image.
2. Make the script runnable `chmod +x ./wifi_setup.sh`
3. Run `./tor_pifi_wlan1.sh ./path-to-image.img`
4. Flash the image onto an SD-card

## What it does

It mounts the raw image.
Modifies the `/etc/wpa_supplicant/wpa_supplicant.conf`
Unmounts the image.

## After party

This most likely will work for any linux distro given it uses WPA Supplicant. 