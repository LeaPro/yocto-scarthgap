#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath .)

rm -rf /nfs/LEA/beagleplay/rootfs
mkdir -p /nfs/LEA/beagleplay/rootfs
tar xpf $BUILDDIR/deploy-ti/images/beagleplay/core-image-minimal-beagleplay.rootfs.tar.xz -C /nfs/LEA/beagleplay/rootfs

