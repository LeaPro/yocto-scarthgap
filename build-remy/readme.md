build w/docker:

docker run --rm --mac-address="a4:4c:c8:29:84:c4" -it -v $HOME:$HOME -v /media/wap/HDD/yocto-scarthgap-shared/downloads:/media/wap/HDD/yocto-scarthgap-shared/downloads -v /media/wap/HDD/yocto-scarthgap-shared/sstate-cache:/media/wap/HDD/yocto-scarthgap-shared/sstate-cache lea-yocto-scarthgap
cd ~/LEA/yocto-scarthgap/
. poky/oe-init-build-env build-remy/
bitbake core-image-minimal
bitbake core-image-minimal -f -c populate_sdk

#### fix me for remy toolchain
### wap@0a649ea35afc:~/LEA/yocto-scarthgap/build-remy$ find . -name "*toolchain-*.sh"
### ./deploy-ti/sdk/poky-glibc-x86_64-core-image-minimal-aarch64-beagleplay-toolchain-5.0.6.sh


### cd deploy-ti/sdk
### wap@boyd:~/LEA/yocto-scarthgap/build-beagleplay/deploy-ti/sdk$ ./poky-glibc-x86_64-core-image-minimal-aarch64-beagleplay-toolchain-5.0.6.sh

