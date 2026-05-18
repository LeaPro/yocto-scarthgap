SUMMARY = "NXP out-of-tree WiFi driver (mlan + moal) for IW612 / SD9177"
DESCRIPTION = "NXP mwifiex out-of-tree driver from github.com/nxp-imx/mwifiex. \
Produces mlan.ko and moal.ko, which replace the upstream in-kernel mwifiex for \
the IW612 (SD9177) combo chip used on the MAYA-W271 EVK."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=ab04ac0f249af12befccb94447c08b77"

inherit module

# Upstream mwifiex Makefile provides 'install' (not 'modules_install').
MODULES_INSTALL_TARGET = "install"

# Branch targeting kernel 6.12.x; matches the BBB kernel (linux-bb.org 6.12.34-ti).
SRC_URI = "git://github.com/nxp-imx/mwifiex.git;branch=lf-6.12.49_2.2.0;protocol=https"
SRCREV = "84ca65c9ff935d7f2999af100a82531c22c65234"
PV = "1.0"

S = "${WORKDIR}/git"

# Build only for SD9177 (IW612) on SDIO. Explicitly disable every other
# interface/chipset so we don't pull in PCIE/USB symbols that aren't present
# in the BBB kernel, and disable i.MX-specific OOB GPIO IRQ support.
# KERNEL_SRC: mwifiex Makefile uses this (line 144: KERNELDIR ?= $(KERNEL_SRC))
# to locate the kernel build tree. Yocto's module.bbclass passes KERNEL_PATH
# but not KERNEL_SRC, so we supply it here.
EXTRA_OEMAKE = " \
    KERNEL_SRC=${STAGING_KERNEL_BUILDDIR} \
    KERNELDIR=${STAGING_KERNEL_BUILDDIR} \
    INSTALLDIR=${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION} \
    CONFIG_SD8887=n CONFIG_SD8897=n CONFIG_SD8977=n CONFIG_SD8978=n \
    CONFIG_SD8997=n CONFIG_SD8987=n CONFIG_SD9097=n CONFIG_SD9098=n \
    CONFIG_SD9177=y \
    CONFIG_SDIW610=n CONFIG_SDIW624=n CONFIG_SDAW693=n CONFIG_SD8801=n \
    CONFIG_USB8801=n CONFIG_USB8897=n CONFIG_USB8997=n CONFIG_USB8978=n \
    CONFIG_USB9097=n CONFIG_USB9098=n CONFIG_USBIW610=n CONFIG_USBIW624=n \
    CONFIG_PCIE8897=n CONFIG_PCIE8997=n CONFIG_PCIE9097=n CONFIG_PCIE9098=n \
    CONFIG_PCIEIW624=n CONFIG_PCIEAW693=n \
    CONFIG_STA_SUPPORT=y CONFIG_UAP_SUPPORT=y \
    CONFIG_WIFI_DIRECT_SUPPORT=y CONFIG_REASSOCIATION=y \
    CONFIG_MFG_CMD_SUPPORT=y CONFIG_SDIO_SUSPEND_RESUME=y \
    CONFIG_DFS_TESTING_SUPPORT=y CONFIG_DUMP_TO_PROC=y \
    CONFIG_DEBUG=1 CONFIG_IMX_SUPPORT=n \
"

do_install:prepend() {
    install -d ${D}${nonarch_base_libdir}/modules/${KERNEL_VERSION}
}

do_install:append() {
    # modprobe options: pass the firmware parameter config at module load time
    install -d ${D}${sysconfdir}/modprobe.d
    echo "options moal mod_para=nxp/wifi_mod_para.conf" \
        > ${D}${sysconfdir}/modprobe.d/nxp-wlan.conf

    # systemd-modules-load will load mlan first, then moal (order matters:
    # moal depends on mlan's exported symbols).
    install -d ${D}${sysconfdir}/modules-load.d
    printf 'mlan\nmoal\n' > ${D}${sysconfdir}/modules-load.d/nxp-wlan.conf
}

FILES:${PN} += " \
    ${sysconfdir}/modprobe.d/nxp-wlan.conf \
    ${sysconfdir}/modules-load.d/nxp-wlan.conf \
"
