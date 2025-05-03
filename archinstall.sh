#!/usr/bin/env bash

#[CONSOLE]
#KEYBOARD LAYOUT
#localectl list-keymaps
loadkeys be-latin1

#FONT SIZE
#location /sys/share/kbd/consolefonts/
#setfont ter-132b

#[BOOT MODE]
bootmode=
uefibitness=$( cat /sys/firmware/efi/fw_platform_size )
if [ $uefibitness -eq 64 ]; then bootmode='UEFI64'; elif [ $uefibitness -eq 32 ]; then bootmode='UEFI32'; else bootmode='BIOS'; fi

#[INTERNET CONNECTION]
#LAN
#ip link

#WIFI
#iwctl (through iwd.service)
#[iwd] device list
#[iwd] device [name|adatper] set-property Prowered on
#[iwd] station name scan
#[iwd] station name get-networks
#[iwd] station name [connect|connect-hidden] SSID
wifipass=
ssid=
read -p "Enter SSID: " ssid
read -p "Enter WiFi passphrase: " -s wifipass
iwctl --passphrase $wifipass station name connect $ssid
wifipass=
ssid=

ping -c www.archlinux.org

#[SYSTEM CLOCK]
timedatectl

#[DISKS]

