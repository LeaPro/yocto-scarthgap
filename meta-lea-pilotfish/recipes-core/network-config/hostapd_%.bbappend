FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " file://hostapd.conf "

#EXTRA_OECONF += "--with-alias"

do_configure:append() {
  # bbwarn "work is ${WORKDIR}"
}
do_install:append() {
  # bbwarn "WORKDIR is ${WORKDIR}"
  # bbwarn "B is ${B}"
  # bbwarn "D is ${D}"
  # install -m 0644 ${WORKDIR}/hostapd.conf ${D}${sysconfdir}
}
