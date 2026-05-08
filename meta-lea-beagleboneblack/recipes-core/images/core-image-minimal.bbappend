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
IMAGE_INSTALL:append = " \
    kernel-module-mlan \
    kernel-module-moal \
    nxp-mwifiex \
    nxp-iw612-fw \
    linux-firmware-nxp8997-common \
    linux-firmware-nxpiw612-sdio \
    kernel-module-hci-uart \
    kernel-module-btnxpuart \
    bluez5 \
    iw \
    networkmanager \
"

# Install /etc/bluetooth/main.conf with AutoEnable=true.
# bluetoothd powers on hci0 via the MGMT interface immediately at startup,
# before the IW612 BT UART enters power-save sleep.
IMAGE_INSTALL:append = " nxp-bt-config"
