#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath ..)

rm -rf /nfs/LEA/DLS/rootfs
mkdir -p /nfs/LEA/DLS/rootfs
tar xpf $BUILDDIR/tmp/deploy/images/lea-dls/core-image-minimal-lea-dls.rootfs.tar.xz -C /nfs/LEA/DLS/rootfs

