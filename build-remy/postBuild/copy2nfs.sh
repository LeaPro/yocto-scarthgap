#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath ..)

rm -rf /nfs/LEA/remy/rootfs
mkdir -p /nfs/LEA/remy/rootfs
tar xpf $BUILDDIR/deploy-ti/images/lea-remy/core-image-minimal-lea-remy.rootfs.tar.xz -C /nfs/LEA/remy/rootfs
