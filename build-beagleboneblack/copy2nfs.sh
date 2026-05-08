#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath .)

rm -rf /nfs/LEA/beagleboneblack/rootfs
mkdir -p /nfs/LEA/beagleboneblack/rootfs
tar xpf $BUILDDIR/deploy-ti/images/beaglebone/core-image-minimal-beaglebone.rootfs.tar.xz -C /nfs/LEA/beagleboneblack/rootfs

