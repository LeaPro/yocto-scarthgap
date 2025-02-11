#!/bin/bash

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

BUILDDIR=$(realpath ..)

rm -rf /nfs/LEA/SuperDARC/rootfs
mkdir -p /nfs/LEA/SuperDARC/rootfs
tar xpf $BUILDDIR/tmp/deploy/images/lea-superdarc/core-image-minimal-lea-superdarc.rootfs.tar.xz -C /nfs/LEA/SuperDARC/rootfs

