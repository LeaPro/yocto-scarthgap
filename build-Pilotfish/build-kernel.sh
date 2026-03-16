echo "building linux-yocto (kernel + device tree)"

source build-setup.sh
cd ..;  source $ENVSETUP build-$TARGET

# cleansstate so do_bundle_initramfs re-runs and picks up the fresh core-image-minimal cpio.gz
bitbake -c cleansstate linux-yocto

# unpacking not required if all of our tweaks are done w/patches
#bitbake -f -c unpack linux-yocto
bitbake linux-yocto
