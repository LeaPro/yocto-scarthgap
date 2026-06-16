SUMMARY = "Infineon wmbt - Wireless Module Bluetooth Tool"
DESCRIPTION = "Linux tool for programming HCD firmware into the CYBT-343026-01 \
(BCM20703A2) Bluetooth module SPI flash over UART."
SECTION = "support"
LICENSE = "CLOSED"

SRC_URI = "file://wmbt.cpp \
           file://download.cpp \
           file://crc.cpp \
           file://wmbt_uart.cpp \
           file://wmbt_linux.c \
           file://wmbt_uart.h \
           file://Makefile \
           file://minidriver_new.hcd \
           file://20703A2_wiced_uart_flash.hcd \
           "

S = "${WORKDIR}"

do_compile() {
    # Makefile expects common sources in ./common/ subdirectory
    mkdir -p ${S}/common
    cp ${S}/wmbt_uart.cpp ${S}/common/
    cp ${S}/wmbt_linux.c  ${S}/common/
    cp ${S}/wmbt_uart.h   ${S}/common/
    cd ${S}
    oe_runmake CC="${CC}" CXX="${CXX}" CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/wmbt ${D}${bindir}/wmbt

    install -d ${D}/opt/wmbt
    install -m 0644 ${S}/minidriver_new.hcd        ${D}/opt/wmbt/
    install -m 0644 ${S}/20703A2_wiced_uart_flash.hcd ${D}/opt/wmbt/
}

FILES:${PN} = "${bindir}/wmbt /opt/wmbt"
