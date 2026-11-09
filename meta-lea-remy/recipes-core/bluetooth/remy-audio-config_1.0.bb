SUMMARY = "ALSA routing for Remy unified 4-channel DSP audio"
DESCRIPTION = "Installs ALSA configuration exposing bt_audio and net_audio sinks on one 4-channel MCASP path."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://asound.conf"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/asound.conf ${D}${sysconfdir}/asound.conf
}

FILES:${PN} = "${sysconfdir}/asound.conf"
