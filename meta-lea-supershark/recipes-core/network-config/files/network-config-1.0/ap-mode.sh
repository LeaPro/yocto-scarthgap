# A script to put us in WiFi AP mode

# ./ap-mode.sh CH SSID          # ch=CH, ssid=SSID, no password
# ./ap-mode.sh CH SSID PASSWORD # ch=CH, ssid=SSID, password=PASSWORD

if [ $# == 3 ]; then
  CH=$1
  SSID=$2
  PASSWORD=$3
elif [ $# == 2 ]; then
  CH=$1
  SSID=$2
  PASSWORD=0
else
  echo "bogus arguments"
  exit 1
fi

pushd /etc/systemd/network &> /dev/null

# stop any networking stuff we may have running (WiFi STA mode, WiFi AP mode, Wired mode)
./disabled-mode.sh

# release WILC from reset
# chip_en
echo 1 > /sys/class/gpio/gpio58/value 2> /dev/null
usleep 10000
# reset
echo 1 > /sys/class/gpio/gpio49/value 2> /dev/null
sleep 5

# load wilc driver if necessary
lsmod | grep wilc
if [[ $? != 0 ]] ; then
  echo "loading wilc-sdio driver"
  #sleep 1
  modprobe wilc-sdio
  sleep 5
fi

echo "configuring hostapd"
# create /etc/hostapd.conf using sed and hostapd.example
if [[ $PASSWORD != 0 ]]; then
  sed -e "s|^channel=.*|channel=$CH|" -e "s|^ssid=.*$|ssid=$SSID|" -e "s|^#wpa=.*$|wpa=3|" -e "s|^#wpa_passphrase=.*$|wpa_passphrase=$PASSWORD|" hostapd.example > /etc/hostapd.conf
else
  sed -e "s|^channel=.*|channel=$CH|" -e "s|^ssid=.*$|ssid=$SSID|" hostapd.example > /etc/hostapd.conf
fi

echo "restarting systemd-networkd.service"
systemctl restart systemd-networkd.service

echo "restarting web server"
systemctl restart lighttpd

# fire-up WiFi w/static ip + AP + DHCP server
ip addr add 192.168.1.1/24 brd + dev wlan0
ip link set wlan0 up
systemctl restart hostapd
systemctl restart dnsmasq
ip route add default via 192.168.1.1 dev wlan0

ip link set eth0 down &> /dev/null

sleep 2
systemctl start control4-sddpd &> /dev/null

popd &> /dev/null
