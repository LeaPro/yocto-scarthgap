SUMMARY = "ARC application server"
DESCRIPTION = "Service that runs the ARC application server"
LICENSE = "CLOSED"
DEPENDS = "boost lmdb openssl curl"
PR = "r1"

SRC_URI =  " \
    file://application-server.service \
    file://application-server \
    file://fwUpdate \
    file://stm32flash \
    file://ipcTool \
    file://kvsTool \
    file://PSAS.hex \
    file://AMAS.hex \
    file://PSBT.hex \
    file://AMBT.hex \
    file://fwUpdateDontWait.txt \
    file://readHwRev.sh \
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
    install -m 0644 ${WORKDIR}/application-server.service ${D}${systemd_unitdir}/system

    install -d ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/application-server ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/fwUpdate ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/stm32flash ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/ipcTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/kvsTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/PSAS.hex ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/AMAS.hex ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/PSBT.hex ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/AMBT.hex ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/fwUpdateDontWait.txt ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/readHwRev.sh ${D}/${sbindir}
}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "application-server.service"

inherit systemd

