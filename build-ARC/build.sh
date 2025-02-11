echo "here we go!"

if [[ $1 == "--developer" ]] ; then
  REBUILD_FLAG=
else
  REBUILD_FLAG=-B
fi

echo REBUILD_FLAG=$REBUILD_FLAG

set -e # exit on error

../yocto-toolchain.sh ARC

./build-uboot.sh

make $REBUILD_FLAG -f kernel.mk

./build-stm32-firmware.sh

make $REBUILD_FLAG -f application-server-service.mk

make $REBUILD_FLAG -f cloud-proxy-service.mk

make $REBUILD_FLAG -f leatcp-proxy-service.mk

make $REBUILD_FLAG -f sftp-monitor-service.mk

./build-rootfs.sh

# rename/encrypt the compressed rootfs tarball- note that we now get a warning about 'deprecated key derivation' - not sure if we can change this and maintain compatibility with deployed sftp-monitor-service decryption
DATE=`date +%m-%d-%Y`
VERSION=`python3 getVersionNumber.py`
INFILE=./tmp/deploy/images/lea-arc/core-image-minimal-lea-arc.rootfs.tar.xz
OUTFILE=postBuild/images/ASBT-${VERSION}-LEA-ARC-${DATE}-V2.tar.xz.enc
mkdir -p postBuild/images
rm -rf $OUTFILE
openssl enc -aes-256-cbc -salt -in $INFILE -out $OUTFILE -k DTSB
