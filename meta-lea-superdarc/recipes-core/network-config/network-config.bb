SUMMARY = "network config"
DESCRIPTION = "network configuration files"
LICENSE = "CLOSED"

PR = "1.0"

SRC_URI = " file://${BPN}-${PR}"

FILES:${PN} = "/*"

do_install() {
    #bbwarn "work is ${WORKDIR}"
    #bbwarn "S is ${S}"
    #bbwarn "D is ${D}"
    install -d ${D}/etc/systemd/network
    install -m 0755 ${S}/sshEnable.sh ${D}/etc/systemd/network/
    install -m 0755 ${S}/sshDisable.sh ${D}/etc/systemd/network/
    install -m 0755 ${S}/any.network.disabled ${D}/etc/systemd/network/
    install -m 0755 ${S}/10-eth0.network ${D}/etc/systemd/network/
    install -m 0755 ${S}/eth0.network.dhcp ${D}/etc/systemd/network/
    install -m 0755 ${S}/eth0.network.static ${D}/etc/systemd/network/
    install -m 0755 ${S}/10-wlan0.network ${D}/etc/systemd/network/
    install -m 0755 ${S}/wlan0.network.dhcp ${D}/etc/systemd/network/
    install -m 0755 ${S}/wlan0.network.static ${D}/etc/systemd/network/
    install -m 0755 ${S}/ap-mode.sh ${D}/etc/systemd/network/
    install -m 0755 ${S}/sta-mode.sh ${D}/etc/systemd/network/
    install -m 0755 ${S}/wired-mode.sh ${D}/etc/systemd/network/
    install -m 0755 ${S}/wpa_supplicant-wired-eth0-PEAP.conf ${D}/etc/systemd/network/
    install -m 0755 ${S}/wpa_supplicant-wired-eth0-TLS.conf ${D}/etc/systemd/network/
    install -m 0755 ${S}/wpa_supplicant-wired-eth0-TTLS.conf ${D}/etc/systemd/network/
    install -m 0755 ${S}/disabled-mode.sh ${D}/etc/systemd/network/
    install -m 0755 ${S}/print-ssid.sh ${D}/etc/systemd/network/
    install -m 0755 ${S}/wpa_supplicant-wlan0.example ${D}/etc/systemd/network/
    install -m 0755 ${S}/hostapd.example ${D}/etc/systemd/network/
    install -d ${D}/etc/wpa_supplicant
    install -m 0755 ${S}/wpa_supplicant-wlan0.conf ${D}/etc/wpa_supplicant/
    # WILC1000 firmware (using version 15.7 from https://github.com/linux4wilc/firmware)
    install -d ${D}/usr/lib/firmware/mchp
    install -m 0755 ${S}/wilc1000_wifi_firmware.bin ${D}/usr/lib/firmware/mchp/
}


