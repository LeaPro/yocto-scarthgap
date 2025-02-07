echo "building linux-yocto (kernel + device tree)"

source build-setup.sh
cd ..;  source $ENVSETUP build-$TARGET

# unpacking not required if all of our tweaks are done w/patches
#bitbake -f -c unpack linux-yocto
bitbake linux-yocto
