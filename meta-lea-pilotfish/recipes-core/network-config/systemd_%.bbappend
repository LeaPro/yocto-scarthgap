FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " file://timesyncd.conf "

#EXTRA_OECONF += "--with-alias"

do_install:append() {
    # Push the custom conf files on target
    install -m 0644 ${WORKDIR}/timesyncd.conf ${D}${sysconfdir}/systemd
}