# Include WiFi/BT drivers and firmware needed for MAYA-W271 bring-up.
#
# - nxp-mwifiex provides:
#     mlan.ko + moal.ko (NXP out-of-tree driver for IW612 / SD9177)
#     /etc/modprobe.d/nxp-wlan.conf  (mod_para= option for moal)
#     /etc/modules-load.d/nxp-wlan.conf  (auto-load at boot via systemd)
# - nxp-iw612-fw provides:
#     /lib/firmware/nxp/sduart_nw61x_v1.bin.se  (SDIO+UART combo firmware)
#     /lib/firmware/nxp/wifi_mod_para.conf       (chip parameter config)
# - linux-firmware-nxp8997-common provides BT helper blob for btnxpuart
#   (helper_uart_3000000.bin)
# - linux-firmware-nxpiw612-sdio provides iw612 BT runtime blob
#   (uartspi_n61x_v1.bin.se)
# - kernel-module-hci-uart: HCI UART for BT half of IW612
# - bluez5-noinst-tools provides btmgmt for non-interactive adapter control
IMAGE_INSTALL:append = " \
    linux-firmware-nxp8997-common \
    linux-firmware-nxpiw612-sdio \
    kernel-module-hci-uart \
    kernel-module-btnxpuart \
    kernel-module-snd-soc-ti-edma \
    kernel-module-snd-soc-davinci-mcasp \
    kernel-module-snd-soc-simple-card \
    kernel-module-snd-soc-pcm5102a \
    bluez5 \
    bluez5-noinst-tools \
    bluealsa \
    bluealsa-aplay \
    alsa-utils \
    alsa-plugins \
    iw \
    networkmanager \
"

# Install /etc/bluetooth/main.conf with AutoEnable=true.
# bluetoothd powers on hci0 via the MGMT interface immediately at startup,
# before the IW612 BT UART enters power-save sleep.
IMAGE_INSTALL:append = " nxp-bt-config"
