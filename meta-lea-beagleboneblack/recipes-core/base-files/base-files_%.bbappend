FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI += "file://provision-eMMC-from-SD.sh"

RDEPENDS:${PN}:append = " bash"

# Install the eMMC provisioning helper directly into root's home so an SD boot
# can immediately reprovision eMMC without any host-side scp step.
do_install:append () {
    install -d ${D}/root
    install -m 0755 ${WORKDIR}/provision-eMMC-from-SD.sh ${D}/root/provision-eMMC-from-SD.sh
}
