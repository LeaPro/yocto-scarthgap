SUMMARY = "NST VR2 firmware"
DESCRIPTION = "NST VR2 firmware"
LICENSE = "CLOSED"
DEPENDS = ""
RDEPENDS:${PN} = ""
PR = "r1"

SRC_URI = "file://${BP}.tgz;subdir=nst-vr2-firmware-1.0/usr/sbin"

# skip the usual package dependency and QA checks
SKIP_FILEDEPS = "1"
INSANE_SKIP:${PN}:append = "already-stripped"
do_package_qa[noexec] = "1"

inherit bin_package

do_install:append() {
  #bbwarn "D is ${D}"
  #bbwarn "WORKDIR is ${WORKDIR}"
}