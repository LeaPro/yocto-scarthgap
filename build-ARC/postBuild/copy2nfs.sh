#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath ..)

rm -rf /nfs/LEA/ARC/rootfs
mkdir -p /nfs/LEA/ARC/rootfs
tar xpf $BUILDDIR/tmp/deploy/images/lea-arc/core-image-minimal-lea-arc.rootfs.tar.xz -C /nfs/LEA/ARC/rootfs

