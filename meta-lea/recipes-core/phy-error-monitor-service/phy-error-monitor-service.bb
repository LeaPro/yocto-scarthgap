SUMMARY = "phy error monitor service"
DESCRIPTION = "Service that monitors the kernel log for ethernet phy errors"
LICENSE = "CLOSED"
DEPENDS = ""
PR = "r1"

SRC_URI =  " \
    file://phy-error-monitor.service \
    file://phy-error-monitor.sh \
"

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
    install -d ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/phy-error-monitor.service ${D}${systemd_unitdir}/system

    install -d ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/phy-error-monitor.sh ${D}/${sbindir}

}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "phy-error-monitor.service"

inherit systemd

