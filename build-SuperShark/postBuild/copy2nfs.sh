#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath ..)

rm -rf /nfs/LEA/SuperShark/rootfs
mkdir -p /nfs/LEA/SuperShark/rootfs
tar xpf $BUILDDIR/tmp/deploy/images/lea-supershark/core-image-minimal-lea-supershark.rootfs.tar.xz -C /nfs/LEA/SuperShark/rootfs

