echo "building uboot (u-boot + MLO)"

source build-setup.sh
cd ..;  source $ENVSETUP build-$TARGET

cd ../../u-boot

./build_lea_dls.sh

# the following will put MLO and u-boot.img in the rootfs /boot directory using the yocto 'sftp-monitor-service' recipe
cp MLO $YOCTODIR/meta-lea-dls/recipes-core/sftp-monitor-service/files
cp u-boot.img $YOCTODIR/meta-lea-dls/recipes-core/sftp-monitor-service/files
