#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath ..)
UBOOTDIR=$BUILDDIR/../../u-boot/lea_pilotfish/

if [ $(mount | grep -c /media/mlwerba/boot) != 1 ]
then
  echo "nothing mounted on /media/mlwerba/boot"
  exit
fi

if [ $(mount | grep -c /media/mlwerba/rootfs) != 1 ]
then
  echo "nothing mounted on /media/mlwerba/rootfs"
  exit
fi

rm -rf /media/mlwerba/boot/*
cp $UBOOTDIR/{MLO,u-boot.img} /media/mlwerba/boot
rm -rf /media/mlwerba/rootfs/*
tar xpf $BUILDDIR/tmp/deploy/images/lea-pilotfish/core-image-minimal-lea-pilotfish.rootfs.tar.xz -C /media/mlwerba/rootfs
sync
sync
umount /media/mlwerba/boot
umount /media/mlwerba/rootfs
sync
sync


# below not needed since handled by tar above, but handy sometimes
#mkdir -p /media/mlwerba/rootfs/boot
#cp $BUILDDIR/tmp/deploy/images/beaglebone/{zImage,am335x-boneblack.dtb} /media/mlwerba/rootfs/boot