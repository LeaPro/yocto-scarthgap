#!/bin/bash

# script to make SDCard image
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

dd if=$1 of=sdcard.img bs=1024 count=4M status=progress

sync

echo "Done."
