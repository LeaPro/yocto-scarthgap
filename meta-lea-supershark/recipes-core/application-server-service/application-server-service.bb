SUMMARY = "SuperShark application server"
DESCRIPTION = "Service that runs the SuperShark application server"
LICENSE = "CLOSED"
DEPENDS = "boost lmdb openssl curl"
PR = "r1"

SRC_URI =  " \
    file://application-server.service \
    file://application-server \
    file://stm32flash \
    file://ipcTool \
    file://kvsTool \
    file://PSSS.zip;unpack=0 \
    file://PSOK.zip;unpack=0 \
    file://AMSS.zip;unpack=0 \
    file://AMOK.zip;unpack=0 \
    file://readHwRev.sh \
    file://SuperDARC.ldr \
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
    install -m 0755 ${WORKDIR}/stm32flash ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/ipcTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/kvsTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/PSSS.zip ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/PSOK.zip ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/AMSS.zip ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/AMOK.zip ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/readHwRev.sh ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/SuperDARC.ldr ${D}/${sbindir}
}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "application-server.service"

inherit systemd

