SUMMARY = "Trevally application server"
DESCRIPTION = "Service that runs the Trevally application server"
LICENSE = "CLOSED"
DEPENDS = "boost lmdb openssl curl bash python3 hidapi"
RDEPENDS:${PN} = "libudev libdrm hidapi"
INSANE_SKIP:${PN} += "file-rdeps"
PR = "r1"

SRC_URI =  " \
    file://application-server.service \
    file://application-server \
    file://gpioTool \
    file://ipcTool \
    file://kvsTool \
    file://gpioNumber.py \
    file://libsplayer-1.so \
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
    install -m 0755 ${WORKDIR}/ipcTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}/kvsTool ${D}/${sbindir}
    install -m 0755 ${WORKDIR}//gpioNumber.py ${D}/${sbindir}

    install -d ${D}${libdir}
    install -m 0644 ${WORKDIR}/libsplayer-1.so ${D}${libdir}
}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "application-server.service"
RDEPENDS:${PN} += "alsa-lib"

# vendor libraries delivered already stripped.
INSANE_SKIP:${PN} += "already-stripped"

# Keep unversioned vendor runtime libraries out of auto -dev split.
FILES_SOLIBSDEV = ""

# Package vendor runtime libraries with the main package.
FILES:${PN} += "${libdir}/libsplayer-1.so"


inherit systemd

