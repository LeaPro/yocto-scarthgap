SUMMARY = "Pilotfish display UI config"
DESCRIPTION = "Demo configuration files for the Pilotfish touchscreen UI"
LICENSE = "CLOSED"
PR = "r1"

SRC_URI = " \
    file://home_demo.config \
    file://commercial_demo.config \
"

do_compile () {
}

do_install () {
    install -d ${D}/etc/cstouch
    install -m 0644 ${WORKDIR}/home_demo.config ${D}/etc/cstouch/
    install -m 0644 ${WORKDIR}/commercial_demo.config ${D}/etc/cstouch/
}

FILES:${PN} = "/etc/cstouch/*"
