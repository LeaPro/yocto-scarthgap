FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
  file://index.html.lighttpd \
  file://lighttpd.conf \
  "

#EXTRA_OECONF += "--with-alias"

do_configure:append() {
  bbwarn "work is ${WORKDIR}"
}
do_install:append() {
  bbwarn "work is ${WORKDIR}"
}
