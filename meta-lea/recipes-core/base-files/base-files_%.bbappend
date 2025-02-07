FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI += "file://fw_env.config \
            "
do_install:append () {
    #bbwarn "work is ${WORKDIR}"
    #bbwarn "B is ${B}"
    #bbwarn "S is ${S}"
    #bbwarn "D is ${D}"
    #bbwarn "SRC_URI is ${SRC_URI}"
    install -d ${D}/etc
    install -m 0644 ${S}/fw_env.config ${D}/etc/
}
