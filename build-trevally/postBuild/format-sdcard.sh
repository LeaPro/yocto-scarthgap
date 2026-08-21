#!/bin/bash

# script to format an SDCard for use in LEA Trevally

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

# Partition geometry (512-byte sectors)
BOOT_START=2048
BOOT_SIZE=262144          # 128 MiB
ROOTFS_START=264192
ROOTFS_SIZE=6291456       # 3 GiB

# Require enough space for both partitions
MIN_SECTORS=$((ROOTFS_START + ROOTFS_SIZE))
CARD_SECTORS=$(blockdev --getsz "$1")
if [ "$CARD_SECTORS" -lt "$MIN_SECTORS" ]; then
  echo "Error: $1 is too small (${CARD_SECTORS} sectors)"
  echo "Need at least ${MIN_SECTORS} sectors (~3.13 GiB usable)"
  exit 1
fi

# determine partition suffix (mmcblkN -> p1/p2, sdX -> 1/2)
if [[ "$1" == *mmcblk* ]] || [[ "$1" == *nvme* ]]; then
  PART_PREFIX="${1}p"
else
  PART_PREFIX="${1}"
fi

# unmount all SDCard partitions
printf "hang on while partitions are unmounted...\n"
umount "${1}"?* &> /dev/null
sleep 5

# zero the first chunk of the SDCard for good measure
printf "zeroing first chunk of the SDCard...\n"
dd if=/dev/zero of=$1 bs=1M count=16

# delete all partitions
printf "deleting old partitions...\n"
sfdisk --delete $1

printf "creating partitions...\n"

# create a 128MB DOS boot partition + linux partition for the rest:
sfdisk --force "$1" <<EOF
start=${BOOT_START}, size=${BOOT_SIZE}, type=c, bootable
start=${ROOTFS_START}, size=${ROOTFS_SIZE}, type=83
EOF

# tell the kernel to re-read the partition table
sudo partprobe $1

printf "formatting...\n"

# format partition 1 as FAT32
mkfs.vfat -F 32 -n boot "${PART_PREFIX}1"

# format partition 2 as ext4
mkfs.ext4 -q -F -L rootfs "${PART_PREFIX}2"

# tell the kernel to re-read the partition table
sudo partprobe $1

# show what we got
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$1"
