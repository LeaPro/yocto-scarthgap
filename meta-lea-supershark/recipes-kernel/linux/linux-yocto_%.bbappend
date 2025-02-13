# see meta-yocto-bsp

KBRANCH:lea-supershark = "v5.10/standard/beaglebone"

KMACHINE:lea-supershark ?= "beaglebone"

SRCREV_machine:lea-supershark ?= "3c44f12b9de336579d00ac0105852f4cbf7e8b7d"

COMPATIBLE_MACHINE:lea-supershark = "lea-supershark"

LINUX_VERSION:lea-supershark = "5.10.130"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://devtool-fragment.cfg \
            file://devtool-fragment.scc \
            file://devtool-fragment2.cfg \
            file://devtool-fragment2.scc \
            file://devtool-fragment3.cfg \
            file://devtool-fragment3.scc \
            file://devtool-fragment4.cfg \
            file://devtool-fragment4.scc \
            file://0001-added-am3352-device-tree-using-devtool-5.10.patch \
            file://0002-spidev-tweaks-5.10.patch \
            file://0003-added-WILC-15.7-driver-from-yocto-kirkstone.patch \
            file://am33xx-lea-supershark.dtsi;subdir=git/arch/arm/boot/dts \
            file://am3352-lea-supershark.dts;subdir=git/arch/arm/boot/dts \
            "

do_install:append() {
    # create a symlink in /boot named am335x-boneblack.dtb for compatibility with legacy u-boot environment
    ln -sf am3352-lea-supershark.dtb ${D}/boot/am335x-boneblack.dtb
}