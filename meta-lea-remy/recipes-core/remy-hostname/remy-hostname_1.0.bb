SUMMARY = "Set Remy hostname from Ethernet MAC"
DESCRIPTION = "Boot-time service that sets hostname to lea-remy-<last4mac>"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://remy-set-hostname.sh \
    file://remy-set-hostname.service \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "remy-set-hostname.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${libexecdir}
    install -d ${D}${systemd_system_unitdir}

    install -m 0755 ${WORKDIR}/remy-set-hostname.sh ${D}${libexecdir}/remy-set-hostname.sh
    install -m 0644 ${WORKDIR}/remy-set-hostname.service ${D}${systemd_system_unitdir}/remy-set-hostname.service
}

FILES:${PN} = "${libexecdir}/remy-set-hostname.sh ${systemd_system_unitdir}/remy-set-hostname.service"
