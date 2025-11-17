# script to partition and format eMMC

echo "partitioning and formatting eMMC"
set -e # exit on any error

# delete all partitions
sgdisk --zap-all /dev/mmcblk1

# 1GB user a/b partitions for kernel+dtb+rootfs (firmware updates go here)
# note:  1st partition starts @ sector 4096, so partition table + MLO + u-boot must be <= 2MB
sgdisk --new=1:4096:+1G /dev/mmcblk1
sgdisk --change-name=1:usera /dev/mmcblk1
sgdisk --new=2::+1G /dev/mmcblk1
sgdisk --change-name=2:userb /dev/mmcblk1

# 1GB factory partition for kernel+dtb+rootfs (failsafe; by default 1st partition starts at sector 2048)
sgdisk --new=3::+1G /dev/mmcblk1
sgdisk --change-name=3:factory /dev/mmcblk1

# 512MB data partition (so partitions up to and including this will fit in a 4GB eMMC and room for scratch partition)
sgdisk --new=4::+512M /dev/mmcblk1
sgdisk --change-name=4:data /dev/mmcblk1

# scratch partition in remainder of disk space
sgdisk --new=5:: /dev/mmcblk1
sgdisk --change-name=5:scratch /dev/mmcblk1

sgdisk --print /dev/mmcblk1

# format partitions created above
mkfs.ext4 -q -F -L usera /dev/mmcblk1p1
mkfs.ext4 -q -F -L userb /dev/mmcblk1p2
mkfs.ext4 -q -F -L factory /dev/mmcblk1p3
mkfs.ext4 -q -F -L data /dev/mmcblk1p4
mkfs.ext4 -q -F -L scratch /dev/mmcblk1p5

# copy MLO + u-boot to raw area of disk between partition table and 1st partition
# (see 'MMC/SD Read Sector Procedure in Raw Mode' in spruh73p.pdf - AM335x Technical Reference Manual)
# note:  see comment above regarding size of partition table + MLO + u-boot 
echo "copying MLO + u-boot to eMMC"
dd if=/boot/MLO of=/dev/mmcblk1 seek=1 bs=128k
dd if=/boot/u-boot.img of=/dev/mmcblk1 seek=1 bs=384k

set +e
