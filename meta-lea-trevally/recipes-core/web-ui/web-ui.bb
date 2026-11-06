SUMMARY = "Trevally web UI"
DESCRIPTION = "Web browser UI for LEA Trevally"
LICENSE = "CLOSED"
DEPENDS = "lighttpd"
RDEPENDS:${PN} += " \
    lighttpd \
    lighttpd-module-cgi \
    perl \
    libcgi-perl \
    perl-module-file-basename \
    perl-module-file-copy \
    perl-module-json-pp \
"
PR = "r4"

SRC_URI = " \
    file://${BP}.tar.gz \
    file://index.html \
    file://upload.cgi \
"

inherit bin_package

FILES:${PN} += " \
    /www/pages/upload-test.html \
    /www/pages/http-multipart-form-data-upload.cgi \
"

do_install:append() {
    install -m 0644 ${WORKDIR}/index.html ${D}/www/pages/upload-test.html
    install -m 0755 ${WORKDIR}/upload.cgi ${D}/www/pages/http-multipart-form-data-upload.cgi
}
