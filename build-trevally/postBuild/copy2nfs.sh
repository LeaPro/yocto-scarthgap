#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath ..)

rm -rf /nfs/LEA/trevally/rootfs
mkdir -p /nfs/LEA/trevally/rootfs
tar xpf $BUILDDIR/deploy-ti/images/lea-trevally/core-image-minimal-lea-trevally.rootfs.tar.xz -C /nfs/LEA/trevally/rootfs
