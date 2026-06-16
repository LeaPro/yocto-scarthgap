SUMMARY = "Bluetooth firmware for CYBT-343026-01 (BCM20703A2)"
DESCRIPTION = "HCD RAM patch firmware for the Infineon CYBT-343026-01 Bluetooth module \
(BCM20703A2 chip). Installed as /lib/firmware/brcm/BCM.hcd for the kernel \
hci_uart_bcm driver fallback firmware load path. \
Source file: BCM20703A2_001.002.011.0423.0000_Generic_UART_24MHz_fcbga_BU.hcd"
SECTION = "kernel"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://BCM.hcd;md5=3b276ba70d28e1b5dab66d8436647f0f"

SRC_URI = "file://BCM.hcd"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/brcm
    install -m 0644 ${WORKDIR}/BCM.hcd ${D}${nonarch_base_libdir}/firmware/brcm/BCM.hcd
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/brcm/BCM.hcd"

INHIBIT_PACKAGE_STRIP = "1"
