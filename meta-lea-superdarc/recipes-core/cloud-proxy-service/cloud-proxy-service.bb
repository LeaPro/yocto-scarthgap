SUMMARY = "AWS cloud proxy"
DESCRIPTION = "Service that provides AWS IoT connectivity"
LICENSE = "CLOSED"
DEPENDS = "boost lmdb openssl"
PR = "r1"

SRC_URI =  " \
    file://cloud-proxy.service \
    file://cloud-proxy \
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
    install -m 0644 ${WORKDIR}/cloud-proxy.service ${D}${systemd_unitdir}/system

    install -d ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/cloud-proxy ${D}/${sbindir}

}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "cloud-proxy.service"

inherit systemd

