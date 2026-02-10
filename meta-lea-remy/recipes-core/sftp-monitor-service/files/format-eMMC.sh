# script to partition and format eMMC

echo "partitioning and formatting eMMC"
set -e # exit on any error

EMMC=mmcblk0

# delete all partitions
sgdisk --zap-all /dev/${EMMC}

# create a 128MB DOS boot partition:
sgdisk --new=1:4096:+128M /dev/${EMMC}
sgdisk --change-name=1:boot /dev/${EMMC}

# 1GB user a/b partitions for kernel+dtb+rootfs (firmware updates go here)
# note:  1st partition starts @ sector 4096, so partition table + MLO + u-boot must be <= 2MB
sgdisk --new=2::+1G /dev/${EMMC}
sgdisk --change-name=2:usera /dev/${EMMC}
sgdisk --new=3::+1G /dev/${EMMC}
sgdisk --change-name=3:userb /dev/${EMMC}

# 1GB factory partition
sgdisk --new=4::+1G /dev/${EMMC}
sgdisk --change-name=4:factory /dev/${EMMC}

# 512MB data partition (so partitions up to and including this will fit in a 4GB eMMC and room for scratch partition)
sgdisk --new=5::+512M /dev/${EMMC}
sgdisk --change-name=5:data /dev/${EMMC}

# scratch partition in remainder of disk space
sgdisk --new=6:: /dev/${EMMC}
sgdisk --change-name=6:scratch /dev/${EMMC}

sgdisk --print /dev/${EMMC}

# format partitions created above
mkfs.vfat -F 32 -n boot /dev/${EMMC}p1
mkfs.ext4 -q -F -L usera /dev/${EMMC}p2
mkfs.ext4 -q -F -L userb /dev/${EMMC}p3
mkfs.ext4 -q -F -L factory /dev/${EMMC}p4
mkfs.ext4 -q -F -L data /dev/${EMMC}p5
mkfs.ext4 -q -F -L scratch /dev/${EMMC}p6

echo "copying u-boot binaries to eMMC"
cd /boot

# Enable eMMC boot0 boot
mmc bootpart enable 1 2 /dev/${EMMC}
mmc bootbus set single_backward x1 x8 /dev/${EMMC}
mmc hwreset enable /dev/${EMMC}

# Clear eMMC boot0
echo '0' >> /sys/class/block/${EMMC}boot0/force_ro
dd if=/dev/zero of=/dev/${EMMC}boot0 count=32 bs=128k

# copy tiboot3.bin to eMMC boot0
# (see https://docs.u-boot.org/en/v2025.01/board/beagle/am62x_beagleplay.html#am62x-beagleboard-org-beagleplay
dd if=tiboot3.bin of=/dev/${EMMC}boot0 bs=128k

# the remaining u-boot binaries go in the FAT32 boot partition of the eMMC User Defined Area (UDA) created above
rm -rf mnt
mkdir mnt
mount /dev/${EMMC}p1 mnt
cp {tispl.bin,u-boot.img} mnt
sync
umount mnt

set +e


