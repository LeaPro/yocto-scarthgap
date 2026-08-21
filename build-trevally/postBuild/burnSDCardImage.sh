#!/bin/bash

# script to burn SDCard image
if [ $(id -u) -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 mmc_device, e.g. /dev/mmcblk0"
  exit 1
fi

if [ ! -b "$1" ]; then
  echo "Error: $1 is not a block device"
  exit 1
fi

# unmount all SDCard partitions
printf "hang on while partitions are unmounted...\n"
umount "${1}"?* &> /dev/null || true
sleep 5

dd if=sdcard.img of=$1 bs=1024 status=progress

#zip lea_trevally_sdcard_image-6-23-2026.zip sdcard.img

sync

echo "Done."
