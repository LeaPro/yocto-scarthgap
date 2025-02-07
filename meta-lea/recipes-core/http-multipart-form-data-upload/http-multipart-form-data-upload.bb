SUMMARY = "CGI script for http-multipart-form-data-upload"
DESCRIPTION = "CGI script http-multipart-form-data-upload"
LICENSE = "CLOSED"
DEPENDS = "lighttpd"
PR = "r1"

SRC_URI = "file://cgic.c \
           file://cgic.h \
           file://http-multipart-form-data-upload.c \
          "

S = "${WORKDIR}"
FILES:${PN} += "/www/pages/*"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} http-multipart-form-data-upload.c cgic.c -o http-multipart-form-data-upload.cgi
}

do_install() {
    install -d ${D}/www/pages
    install -m 0755 http-multipart-form-data-upload.cgi ${D}/www/pages
}
