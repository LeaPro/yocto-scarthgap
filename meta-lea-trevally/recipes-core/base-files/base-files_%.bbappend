FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI += "file://fstab \
            file://.profile \
            "
            
do_install:append () {
    install -d ${D}/etc
    install -m 0644 ${S}/fstab ${D}/etc/
    install -d ${D}/root
    install -m 0644 ${S}/.profile ${D}/root/
}
