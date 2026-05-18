SUMMARY = "NXP IW612 (SD9177) SDIO WiFi firmware and moal parameter file"
DESCRIPTION = "Provides the SDIO+UART combo firmware image for the IW612 / SD9177 \
chip (sduart_nw61x_v1.bin.se) and the moal chip-parameter file (wifi_mod_para.conf) \
fetched from github.com/nxp-imx/imx-firmware. \
The .se suffix indicates NXP signed/encrypted firmware; moal handles decryption."
LICENSE = "CLOSED"

# Branch names in nxp-imx/imx-firmware use underscores, not dashes.
SRC_URI = "git://github.com/nxp-imx/imx-firmware.git;branch=lf-6.6.36_2.1.0;protocol=https"
SRCREV = "1b26d19284d202b1531837ce37a05afc49ad1d98"
PV = "1.0"

S = "${WORKDIR}/git"

do_configure() {
    :
}

do_compile() {
    :
}

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/nxp

    # SDIO+UART combo firmware for SD9177 / IW612.
    # This is the file moal looks for by default (SD9177_DEFAULT_COMBO_V1_FW_NAME).
    install -m 0644 \
        ${S}/nxp/FwImage_IW612_SD/sduart_nw61x_v1.bin.se \
        ${D}${nonarch_base_libdir}/firmware/nxp/

    # Chip-parameter config consumed by moal at load time via
    # "options moal mod_para=nxp/wifi_mod_para.conf".
    install -m 0644 \
        ${S}/nxp/wifi_mod_para.conf \
        ${D}${nonarch_base_libdir}/firmware/nxp/
}

FILES:${PN} = " \
    ${nonarch_base_libdir}/firmware/nxp/sduart_nw61x_v1.bin.se \
    ${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf \
"
