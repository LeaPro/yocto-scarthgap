echo "building rootfs"

source build-setup.sh
cd ..;  source $ENVSETUP build-$TARGET

bitbake $IMAGE
