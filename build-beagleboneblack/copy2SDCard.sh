#!/bin/bash

# Script to flash the beaglebone black SD card image.
#
# Usage:
#   sudo ./copy2SDCard.sh /dev/sdX
#
# The .wic.xz image contains a proper partition layout:
#   Partition 1: FAT (bootable) with MLO, u-boot.img, uEnv.txt
#   Partition 2: ext4 rootfs
#
# WARNING: ALL DATA on the target device will be destroyed.

set -e

MACHINE=beaglebone
DEPLOY_DIR=deploy-ti/images/${MACHINE}
WIC_XZ=${DEPLOY_DIR}/core-image-minimal-${MACHINE}.rootfs.wic.xz
BMAP=${DEPLOY_DIR}/core-image-minimal-${MACHINE}.rootfs.wic.bmap

if [ $(id -u) -ne 0 ]; then
  echo "Please run this script as root (sudo)"
  exit 1
fi

DEVICE=$1
if [ -z "${DEVICE}" ]; then
  echo "Usage: sudo $0 /dev/sdX"
  echo ""
  echo "Available block devices:"
  lsblk -d -o NAME,SIZE,MODEL | grep -v loop
  exit 1
fi

if [ ! -b "${DEVICE}" ]; then
  echo "Error: ${DEVICE} is not a block device"
  exit 1
fi

# Resolve symlink to actual wic.xz file
pushd $(dirname ${WIC_XZ}) > /dev/null
WIC_XZ_FILE=$(readlink -f $(basename ${WIC_XZ}))
popd > /dev/null

if [ ! -f "${WIC_XZ_FILE}" ]; then
  echo "Error: image not found: ${WIC_XZ_FILE}"
  exit 1
fi

echo "Target device : ${DEVICE}"
echo "Image         : ${WIC_XZ_FILE}"
echo ""
lsblk "${DEVICE}"
echo ""
read -p "All data on ${DEVICE} will be destroyed. Continue? [y/N] " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# Unmount any mounted partitions on the device
for PART in $(lsblk -ln -o NAME "${DEVICE}" | tail -n +2); do
  if mount | grep -q "/dev/${PART}"; then
    echo "Unmounting /dev/${PART} ..."
    umount "/dev/${PART}" || true
  fi
done

echo "Flashing ${WIC_XZ_FILE} to ${DEVICE} ..."

if command -v bmaptool &> /dev/null && [ -f "${BMAP}" ]; then
  BMAP_FILE=$(cd $(dirname ${BMAP}) && readlink -f $(basename ${BMAP}))
  echo "Using bmaptool (fast sparse write)..."
  bmaptool copy --bmap "${BMAP_FILE}" "${WIC_XZ_FILE}" "${DEVICE}"
else
  echo "Using xzcat | dd ..."
  xzcat "${WIC_XZ_FILE}" | dd of="${DEVICE}" bs=4M conv=fsync status=progress
fi

sync
echo "Done. SD card is ready."
