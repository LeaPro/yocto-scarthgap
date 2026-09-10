SUMMARY = "Bluetooth configuration for NXP MAYA-W261 on Trevally"
DESCRIPTION = "Installs BlueZ D-Bus pairing agent and bluetooth configuration for headless A2DP audio sink mode."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://main.conf \
    file://trevally-bt-agent.py \
    file://trevally-bt-agent.service \
    file://bluealsa-aplay-override.conf \
    file://asound.conf \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "trevally-bt-agent.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${sysconfdir}/bluetooth
    install -d ${D}${libexecdir}
    install -d ${D}${systemd_system_unitdir}
    install -d ${D}${sysconfdir}/systemd/system/bluealsa-aplay.service.d
    install -d ${D}${sysconfdir}

    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/main.conf
    install -m 0755 ${WORKDIR}/trevally-bt-agent.py ${D}${libexecdir}/trevally-bt-agent.py
    install -m 0644 ${WORKDIR}/trevally-bt-agent.service ${D}${systemd_system_unitdir}/trevally-bt-agent.service
    install -m 0644 ${WORKDIR}/bluealsa-aplay-override.conf ${D}${sysconfdir}/systemd/system/bluealsa-aplay.service.d/override.conf
    install -m 0644 ${WORKDIR}/asound.conf ${D}${sysconfdir}/asound.conf
}

FILES:${PN} = "${sysconfdir}/bluetooth/main.conf ${libexecdir}/trevally-bt-agent.py ${systemd_system_unitdir}/trevally-bt-agent.service ${sysconfdir}/systemd/system/bluealsa-aplay.service.d/override.conf ${sysconfdir}/asound.conf"
RDEPENDS:${PN} += "python3-core python3-dbus python3-pygobject"
