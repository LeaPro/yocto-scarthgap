SUMMARY = "Bluetooth configuration for NXP IW612 on BeagleBone Black"
DESCRIPTION = "Installs /etc/bluetooth/main.conf with AutoEnable=true so \
bluetoothd (via MGMT interface) powers on hci0 automatically at startup, \
before the chip enters BT power-save sleep."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://main.conf \
    file://bbb-bt-discoverable.sh \
    file://bbb-bt-discoverable.service \
    file://bbb-bt-autotrust.sh \
    file://bbb-bt-autotrust.service \
    file://bbb-bt-agent.pin \
    file://bluealsa-aplay-override.conf \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "bbb-bt-discoverable.service bbb-bt-autotrust.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${sysconfdir}/bluetooth
    install -d ${D}${libexecdir}
    install -d ${D}${systemd_system_unitdir}
    install -d ${D}${sysconfdir}/systemd/system/bluealsa-aplay.service.d
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/main.conf
    install -m 0644 ${WORKDIR}/bbb-bt-agent.pin ${D}${sysconfdir}/bluetooth/bt-agent.pin
    install -m 0755 ${WORKDIR}/bbb-bt-discoverable.sh ${D}${libexecdir}/bbb-bt-discoverable.sh
    install -m 0755 ${WORKDIR}/bbb-bt-autotrust.sh ${D}${libexecdir}/bbb-bt-autotrust.sh
    install -m 0644 ${WORKDIR}/bbb-bt-discoverable.service ${D}${systemd_system_unitdir}/bbb-bt-discoverable.service
    install -m 0644 ${WORKDIR}/bbb-bt-autotrust.service ${D}${systemd_system_unitdir}/bbb-bt-autotrust.service
    install -m 0644 ${WORKDIR}/bluealsa-aplay-override.conf ${D}${sysconfdir}/systemd/system/bluealsa-aplay.service.d/override.conf
}

FILES:${PN} = "${sysconfdir}/bluetooth/main.conf ${sysconfdir}/bluetooth/bt-agent.pin ${libexecdir}/bbb-bt-discoverable.sh ${libexecdir}/bbb-bt-autotrust.sh ${systemd_system_unitdir}/bbb-bt-discoverable.service ${systemd_system_unitdir}/bbb-bt-autotrust.service ${sysconfdir}/systemd/system/bluealsa-aplay.service.d/override.conf"
RDEPENDS:${PN} += "bluez-tools"
