#!/bin/bash
# Clone the currently running SD card image (/dev/mmcblk0) to eMMC (/dev/mmcblk1)
# for BeagleBone Black. Run this on the BBB while booted from SD.

set -euo pipefail

SRC_DEV="/dev/mmcblk0"
DST_DEV="/dev/mmcblk1"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Please run as root (sudo)."
  exit 1
fi

if [[ ! -b "${SRC_DEV}" || ! -b "${DST_DEV}" ]]; then
  echo "Expected ${SRC_DEV} (SD) and ${DST_DEV} (eMMC) to exist."
  cat /proc/partitions
  exit 1
fi

# Refuse to run if we're already booted from eMMC.
if grep -q "root=/dev/mmcblk1" /proc/cmdline; then
  echo "Root filesystem is already on eMMC. Nothing to do."
  exit 0
fi

echo "Source (SD):        ${SRC_DEV}"
echo "Destination (eMMC): ${DST_DEV}"
echo
echo "WARNING: This will erase ${DST_DEV}."
read -r -p "Continue? [y/N] " answer
if [[ "${answer}" != "y" && "${answer}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# Unmount any mounted eMMC partitions before writing.
for p in "${DST_DEV}"p*; do
  if grep -q "^${p} " /proc/mounts; then
    umount "$p" || true
  fi
done

# Clone only the used SD region (MBR + p1 + p2) to eMMC.
P2_START="$(cat /sys/block/mmcblk0/mmcblk0p2/start)"
P2_SIZE="$(cat /sys/block/mmcblk0/mmcblk0p2/size)"
SECTOR_COUNT="$((P2_START + P2_SIZE))"

echo "Cloning ${SECTOR_COUNT} sectors from ${SRC_DEV} to ${DST_DEV} ..."
dd if="${SRC_DEV}" of="${DST_DEV}" bs=512 count="${SECTOR_COUNT}"
sync

# Fix extlinux.conf on the eMMC boot partition to use mmcblk1p2 as root.
EMMC_BOOT_MNT="/mnt/emmc-boot"
mkdir -p "${EMMC_BOOT_MNT}"
if mount "${DST_DEV}p1" "${EMMC_BOOT_MNT}"; then
  if [[ -f "${EMMC_BOOT_MNT}/extlinux/extlinux.conf" ]]; then
    awk '
      /^[[:space:]]*APPEND[[:space:]]+/ {
        print "        APPEND root=/dev/mmcblk1p2 rootwait rw earlycon console=ttyS0,115200n8"
        next
      }
      { print }
    ' "${EMMC_BOOT_MNT}/extlinux/extlinux.conf" > "${EMMC_BOOT_MNT}/extlinux/extlinux.conf.new"
    mv "${EMMC_BOOT_MNT}/extlinux/extlinux.conf.new" "${EMMC_BOOT_MNT}/extlinux/extlinux.conf"
    sync
  else
    echo "Warning: extlinux/extlinux.conf not found on ${DST_DEV}p1; skipping."
  fi
  umount "${EMMC_BOOT_MNT}" || true
else
  echo "Warning: could not mount ${DST_DEV}p1; skipping extlinux.conf fix."
fi

# Write MLO + U-Boot into raw offsets expected by AM335x ROM.
if [[ -f /boot/MLO && -f /boot/u-boot.img ]]; then
  dd if=/boot/MLO        of="${DST_DEV}" seek=1 bs=128k
  dd if=/boot/u-boot.img of="${DST_DEV}" seek=1 bs=384k
  sync
else
  echo "Warning: /boot/MLO or /boot/u-boot.img not found; skipping raw bootloader write."
fi

echo
echo "Provisioning complete."
echo "Power down, remove SD card, and boot from eMMC."
