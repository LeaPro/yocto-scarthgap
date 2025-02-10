# A script to disable networking

pushd /etc/systemd/network &> /dev/null

# stop any networking stuff we may have running (WiFi STA mode, WiFi AP mode, Wired mode)
echo "shutting down network"

# stop control4-sddpd service; keep network alive until it is stopped
systemctl stop control4-sddpd &> /dev/null
while [[ true ]] ; do
  systemctl is-active control4-sddpd
  if [[ $? = 0 ]] ; then
    sleep 0.1
  else
    break 1
  fi
  systemctl stop control4-sddpd
done

systemctl stop wpa_supplicant@wlan0.service &> /dev/null
systemctl stop wpa_supplicant-wired@eth0.service &> /dev/null
systemctl stop dnsmasq &> /dev/null
systemctl stop hostapd &> /dev/null
ip link set eth0 down &> /dev/null
ip link set wlan0 down &> /dev/null
ip addr flush dev eth0 &> /dev/null
ip addr flush dev wlan0 &> /dev/null
cp any.network.disabled 10-eth0.network
cp any.network.disabled 10-wlan0.network

modprobe -r wilc-sdio

# put WILC in reset

# reset
echo 49 > /sys/class/gpio/export 2> /dev/null
while [[ ! (-e /sys/class/gpio/gpio49/direction && -e /sys/class/gpio/gpio49/value) ]] ; do
  sleep 1
done
sleep 1
echo low > /sys/class/gpio/gpio49/direction 2> /dev/null

# chip_en
echo 58 > /sys/class/gpio/export 2> /dev/null
while [[ ! (-e /sys/class/gpio/gpio58/direction && -e /sys/class/gpio/gpio58/value) ]] ; do
  sleep 1
done
sleep 1
echo low > /sys/class/gpio/gpio58/direction 2> /dev/null

sleep 1

popd &> /dev/null