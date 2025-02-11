SUMMARY = "Control4 SDDPd service for LEA Amps"
DESCRIPTION = "Control4 SDDPd service for LEA Amps"
LICENSE = "CLOSED"
PR = "r1"

SRC_URI = "file://Sddp.c \
           file://Sddp.h \
           file://SddpNetwork.c \
           file://SddpNetwork.h \
           file://SddpPacket.c \
           file://SddpPacket.h \
           file://SddpServer.c \
           file://SddpStatus.h \
           file://control4-sddpd.service \
          "

FILES:${PN} += "/usr/lib/systemd/system/control4-sddpd.service /usr/sbin/sddpd"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -DNO_GETOPT_HACK Sddp.c SddpNetwork.c SddpPacket.c SddpServer.c -o sddpd
}

do_install() {
    install -d ${D}/${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/control4-sddpd.service ${D}${systemd_unitdir}/system

    install -d ${D}${sbindir}
    install -m 0755 sddpd ${D}/${sbindir}
}

NATIVE_SYSTEMD_SUPPORT = "1"
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE_${PN} = "control4-sddpd.service"

inherit systemd
