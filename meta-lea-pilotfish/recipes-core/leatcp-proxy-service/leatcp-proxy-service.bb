SUMMARY = "LEA TCP API proxy"
DESCRIPTION = "Service that provides a line-oriented TCP API"
LICENSE = "CLOSED"
DEPENDS = "boost lmdb openssl"
PR = "r1"

SRC_URI =  " \
    file://leatcp-proxy.service \
    file://leatcp-proxy \
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
    install -d ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/leatcp-proxy.service ${D}${systemd_unitdir}/system

    install -d ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/leatcp-proxy ${D}/${sbindir}

}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "leatcp-proxy.service"

inherit systemd

