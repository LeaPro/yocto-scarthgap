echo "building $1"

source build-setup.sh
cd ..;  source $ENVSETUP build-$TARGET

bitbake $1
