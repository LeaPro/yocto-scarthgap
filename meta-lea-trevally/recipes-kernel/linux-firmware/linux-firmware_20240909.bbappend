FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Install the alternate N61x firmware name requested by the Trevally DT override.
# Add the actual binary file under:
#   meta-lea-trevally/recipes-kernel/linux-firmware/files/sduart_nw61x_v1.bin.se
#   pulled from https://github.com/nxp-imx/imx-firmware/tree/lf-6.12.49_2.2.0
SRC_URI:append:lea-trevally = " \
    file://sduart_nw61x_v1.bin.se;unpack=0 \
"

do_install:append:lea-trevally() {
    install -d ${D}${nonarch_base_libdir}/firmware/nxp
    install -m 0644 ${WORKDIR}/sduart_nw61x_v1.bin.se \
        ${D}${nonarch_base_libdir}/firmware/nxp/sduart_nw61x_v1.bin.se
}

FILES:${PN}-nxpiw612-sdio += " \
    ${nonarch_base_libdir}/firmware/nxp/sduart_nw61x_v1.bin.se \
"
