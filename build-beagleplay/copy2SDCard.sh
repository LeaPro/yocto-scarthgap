#!/bin/bash

# script to copy root filesystem to SDCard for use on beagleplay

# expects SDCard 'boot' and 'rootfs' partitions to be mounted (happens automatically in linux mint when I plug in an SDCard formatted with 'format-sdcard.sh')
MOUNT_DIR=/media/${SUDO_USER}/rootfs

if [ $(id -u) -ne 0 ]; then
  echo "Please run this script as root"
  exit
fi

if [ $(mount | grep -c ${MOUNT_DIR}) != 1 ]
then
  echo "nothing mounted on ${MOUNT_DIR}"
  exit
fi

echo "Copying linux root file system to ${MOUNT_DIR} ..."

rm -rf ${MOUNT_DIR}/*

# TAR_XZ_LINK is a symlink pointing to a timestamped, xz-compressed image
MACHINE=beagleplay
TAR_XZ_LINK=deploy-ti/images/${MACHINE}/core-image-minimal-${MACHINE}.rootfs.tar.xz


pushd $(dirname ${TAR_XZ_LINK})
# TAR_XZ is the target pointed to by TAR_XZ_LINK
TAR_XZ=$(readlink $(basename ${TAR_XZ_LINK}))
tar xpfv ${TAR_XZ} -C ${MOUNT_DIR}
popd

# copy u-boot files to /boot; we need them after formatting/partitioning eMMC so we can boot from it later
cp ../../u-boot/lea_beagleplay/{tiboot3.bin,tispl.bin,u-boot.img} ${MOUNT_DIR}/boot/

sync

# unmount the SDCard partitions if the first argument ($1) is the string "umount"
if [ "$1" = "umount" ]; then
  mount | awk '/mmcblk0/ {print $1}' | xargs umount
fi

echo "Done."
