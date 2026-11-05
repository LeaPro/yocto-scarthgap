#!/bin/bash
# full trevally build: u-boot, application-server tools, kernel/dtb, rootfs,
# then encrypt the rootfs tarball for sftp-monitor-service firmware updates
#
# usage: ./build.sh [--developer]
#   --developer: incremental build (default forces a rebuild of sub-projects)

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd "$SCRIPT_DIR"

# the Makefile must run inside the docker container
if [[ -z $LEA_YOCTO_SCARTHGAP_CONTAINER ]] ; then
  exec ./docker-run "$SCRIPT_DIR/build.sh" "$@"
fi

echo "here we go!"

if [[ $1 == "--developer" ]] ; then
  REBUILD_FLAG=
else
  REBUILD_FLAG=-B
fi

echo REBUILD_FLAG=$REBUILD_FLAG

set -e # exit on error

# install the SDK toolchain if needed (never forced; it's a long bitbake build)
make sdk

make $REBUILD_FLAG image

# encrypt the compressed rootfs tarball - must match the decryption in sftp-monitor.sh
DATE=`date +%m-%d-%Y`
INFILE=./deploy-ti/images/lea-trevally/core-image-minimal-lea-trevally.rootfs.tar.xz
OUTFILE=postBuild/images/TV-LEA-Trevally-${DATE}.tar.xz.enc
mkdir -p postBuild/images
rm -rf $OUTFILE
openssl enc -aes-256-cbc -salt -in $INFILE -out $OUTFILE -k GCEA
echo "created $OUTFILE"
