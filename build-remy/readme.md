### BEWARE - this file is outdated, but may still contain useful stuff.

## make SDCard image

# 1) Ensure SD partitions are unmounted
mount | awk '/mmcblk0/ {print $1}' | sudo xargs umount

# 2) Set device
DEV=/dev/mmcblk0

# 3) Find last used sector from partition table
LAST_SECTOR=$(sudo sfdisk -d "$DEV" \
  | awk -F'[, ]+' '
      /^\/dev\/mmcblk0p[0-9]+/ {
        start=$4; size=$6; end=start+size-1;
        if (end > max) max=end
      }
      END { print max }')

# 4) Add margin (2048 sectors = 1 MiB)
COUNT=$((LAST_SECTOR + 2048))

echo "Last sector: $LAST_SECTOR"
echo "Capture count: $COUNT sectors"
# 5) Create truncated image
sudo dd if="$DEV" of=lea-remy-sdcard.img bs=512 count="$COUNT" status=progress conv=fsync
stat -c%s lea-remy-sdcard.img | numfmt --to=si

# 6) Zip it (single-file archive)
zip -9 lea-remy-sdcard.img.zip lea-remy-sdcard.img

# 7) Generate checksum for sharing
sha256sum lea-remy-sdcard.img.zip > lea-remy-sdcard.img.zip.sha256


# write the image to another SDCard, decompress if necessary and then:
mount | awk '/mmcblk0/ {print $1}' | sudo xargs umount
sudo dd if=lea-remy-sdcard.img of=/dev/mmcblk0 bs=16M oflag=direct conv=fsync status=progress


## zero unused space on SDCard if necessary

# Example mount points (adjust if already mounted elsewhere)
sudo mkdir -p /mnt/sdboot /mnt/sdroot
sudo mount /dev/mmcblk0p1 /mnt/sdboot
sudo mount /dev/mmcblk0p2 /mnt/sdroot

# Zero free space on FAT boot partition
sudo dd if=/dev/zero of=/mnt/sdboot/zero.fill bs=16M status=progress || true
sync
sudo rm -f /mnt/sdboot/zero.fill
sync

# Zero free space on ext4 rootfs partition
sudo dd if=/dev/zero of=/mnt/sdroot/zero.fill bs=64M status=progress || true
sync
sudo rm -f /mnt/sdroot/zero.fill
sync

# Unmount when done
sudo umount /mnt/sdboot /mnt/sdroot