SUMMARY = "SFTP Monitor"
DESCRIPTION = "Script to monitor SFTP directory and install firmware updates"
LICENSE = "CLOSED"
PR = "r1"
PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI =  " \
    file://sftp-monitor.service \
    file://sftp-monitor.sh \
    file://format-eMMC.sh \
    file://MLO \
    file://u-boot.img \
"

FILES:${PN} += "/boot/*"

do_compile () {
}

python do_build() {
    bb.plain("***********************************************");
    bb.plain("*                                             *");
    bb.plain("*  Example recipe created by bitbake-layers   *");
    bb.plain("*                                             *");
    bb.plain("***********************************************");
}

do_install () {
    bbwarn "installing to ${D}"
    install -d ${D}/${sbindir}
    install -d ${D}/boot
    install -m 0755 ${WORKDIR}/sftp-monitor.sh ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/format-eMMC.sh ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/MLO ${D}/boot
    install -m 0755 ${WORKDIR}/u-boot.img ${D}/boot

    install -d ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/sftp-monitor.service ${D}${systemd_unitdir}/system
}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "sftp-monitor.service"

inherit allarch systemd

