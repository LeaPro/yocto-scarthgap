SUMMARY = "Trevally placeholder web UI"
DESCRIPTION = "Skeleton web UI and CGI endpoint for upload testing"
LICENSE = "CLOSED"
DEPENDS = "lighttpd"
RDEPENDS:${PN} += "lighttpd perl"
PR = "r0"

SRC_URI = " \
    file://index.html \
    file://upload.cgi \
"

S = "${WORKDIR}"
FILES:${PN} += " \
    /www/pages/upload-test.html \
    /www/pages/cgi-bin/upload.cgi \
"

do_install() {
    install -d ${D}/www/pages
    install -d ${D}/www/pages/cgi-bin

    install -m 0644 ${WORKDIR}/index.html ${D}/www/pages/upload-test.html
    install -m 0755 ${WORKDIR}/upload.cgi ${D}/www/pages/cgi-bin/upload.cgi
}
