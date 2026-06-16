FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"

SRC_URI += "file://main.conf \
            file://bluetooth-discoverable.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/bluetooth
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/main.conf

    install -d ${D}${systemd_system_unitdir}/bluetooth.service.d
    install -m 0644 ${WORKDIR}/bluetooth-discoverable.conf \
        ${D}${systemd_system_unitdir}/bluetooth.service.d/bluetooth-discoverable.conf
}

FILES:${PN} += "${systemd_system_unitdir}/bluetooth.service.d/bluetooth-discoverable.conf"
