FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://system.pa \
    file://pulseaudio-system.service \
"

inherit useradd systemd

# Add the pulse user to the bluetooth group on first boot (after bluez5
# has already created it) so PulseAudio system-mode can talk to bluetoothd
# over D-Bus for A2DP/BlueZ5 support.
# GROUPMEMS_PARAM would run at package install time (before bluez5 creates
# the bluetooth group), so we use a deferred postinst instead.
USERADD_PACKAGES += "${PN}-server"

pkg_postinst_ontarget:${PN}-server() {
    # Create bluetooth group if it doesn't exist (bluez5 may not create it)
    getent group bluetooth > /dev/null 2>&1 || groupadd -r bluetooth
    # Add pulse user to bluetooth group so system-mode PulseAudio can
    # communicate with bluetoothd over D-Bus for A2DP/BlueZ5 support
    usermod -a -G bluetooth pulse
}

do_install:append() {
    # Install system.pa for system-mode daemon
    install -d ${D}${sysconfdir}/pulse
    install -m 0644 ${WORKDIR}/system.pa ${D}${sysconfdir}/pulse/system.pa

    # Install systemd system service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/pulseaudio-system.service ${D}${systemd_system_unitdir}/pulseaudio-system.service

    # Hardcode the enable symlink — SYSTEMD_AUTO_ENABLE is overridden by
    # the upstream pulseaudio recipe for this package, so do it directly.
    install -d ${D}${sysconfdir}/systemd/system/multi-user.target.wants
    ln -sf ${systemd_system_unitdir}/pulseaudio-system.service \
        ${D}${sysconfdir}/systemd/system/multi-user.target.wants/pulseaudio-system.service
}

FILES:${PN}-server += " \
    ${sysconfdir}/pulse/system.pa \
    ${systemd_system_unitdir}/pulseaudio-system.service \
    ${sysconfdir}/systemd/system/multi-user.target.wants/pulseaudio-system.service \
"

SYSTEMD_SERVICE:${PN}-server = "pulseaudio-system.service"
SYSTEMD_AUTO_ENABLE:${PN}-server = "enable"
