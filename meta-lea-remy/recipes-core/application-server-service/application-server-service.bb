SUMMARY = "Remy application server"
DESCRIPTION = "Service that runs the Remy application server"
LICENSE = "CLOSED"
DEPENDS = "boost lmdb openssl curl bash python3"
PR = "r1"

SRC_URI =  " \
    file://application-server.service \
    file://application-server \
    file://gpioTool \
    file://fpgaTool \
    file://ipcTool \
    file://kvsTool \
    file://stm32flash \
    file://remy_pof.svf \
    file://gpioNumber.py \
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
    install -m 0755 ${WORKDIR}/gpioTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/fpgaTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/ipcTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/kvsTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/stm32flash ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/remy_pof.svf ${D}/${sbindir}
    install -m 0755 ${WORKDIR}//gpioNumber.py ${D}/${sbindir}
}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "application-server.service"

inherit systemd

