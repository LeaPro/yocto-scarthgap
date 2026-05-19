SUMMARY = "Bluetooth configuration for NXP IW612 on BeagleBone Black"
DESCRIPTION = "Installs BlueZ D-Bus pairing agent and bluetooth configuration \
for headless A2DP audio sink mode. The agent handles pairing acceptance and \
trust management with no user interaction."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://main.conf \
    file://bbb-bt-agent.py \
    file://bbb-bt-agent.service \
    file://bluealsa-aplay-override.conf \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "bbb-bt-agent.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${sysconfdir}/bluetooth
    install -d ${D}${libexecdir}
    install -d ${D}${systemd_system_unitdir}
    install -d ${D}${sysconfdir}/systemd/system/bluealsa-aplay.service.d
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/main.conf
    install -m 0755 ${WORKDIR}/bbb-bt-agent.py ${D}${libexecdir}/bbb-bt-agent.py
    install -m 0644 ${WORKDIR}/bbb-bt-agent.service ${D}${systemd_system_unitdir}/bbb-bt-agent.service
    install -m 0644 ${WORKDIR}/bluealsa-aplay-override.conf ${D}${sysconfdir}/systemd/system/bluealsa-aplay.service.d/override.conf
}

FILES:${PN} = "${sysconfdir}/bluetooth/main.conf ${libexecdir}/bbb-bt-agent.py ${systemd_system_unitdir}/bbb-bt-agent.service ${sysconfdir}/systemd/system/bluealsa-aplay.service.d/override.conf"
RDEPENDS:${PN} += "python3-dbus python3-pygobject"
