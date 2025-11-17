#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath ..)

rm -rf /nfs/LEA/Pilotfish/rootfs
mkdir -p /nfs/LEA/Pilotfish/rootfs
tar xpf $BUILDDIR/tmp/deploy/images/lea-pilotfish/core-image-minimal-lea-pilotfish.rootfs.tar.xz -C /nfs/LEA/Pilotfish/rootfs

