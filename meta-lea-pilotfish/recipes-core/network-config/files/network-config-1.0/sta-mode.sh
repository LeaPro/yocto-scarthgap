# A script to put us in WiFi STA mode

# examples:
# ./sta-mode.sh -s SSID                                                                     (ssid=SSID, no password, dhcp)
# ./sta-mode.sh -s SSID -p PASSWORD                                                         (ssid=SSID, password=PASSWORD, dhcp)
# ./sta-mode.sh -s SSID -a 192.168.1.44/24 -g 192.168.1.1                                   (ssid=SSID, no password, static ip)
# ./sta-mode.sh -s SSID -p PASSWORD -a 192.168.1.44/24 -g 192.168.1.1                       (ssid=SSID, password=PASSWORD, static ip)
# ./sta-mode.sh -s SSID -p PASSWORD -a 192.168.1.44/24 -g 192.168.1.1 -1 8.8.8.8 -2 8.8.4.4 (ssid=SSID, password=PASSWORD, static ip, DNS)

usage() { echo "Usage: $0 -s <SSID> [-p <password>] [-a <ip addr>] [-g <gateway>] [-1 <DNS1>] [-2 <DNS2>] " 1>&2; exit 1; }

while getopts ":s:p:a:g:1:2:" o; do
  case "${o}" in
    s)
      SSID=${OPTARG}
      ;;
    p)
      PASSWORD=${OPTARG}
      ;;
    a)
      IP=${OPTARG}
      ;;
    g)
      GATEWAY=${OPTARG}
      ;;
    1)
      DNS1=${OPTARG}
      ;;
    2)
      DNS2=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [[ -z $SSID ]]; then
  usage
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
  modprobe wilc-sdio
  sleep 5
fi

echo "configuring wlan0 and wpa_supplicant"
# create /etc/wpa_supplicant/wpa_supplicant-wlan0.conf using sed and wpa_supplicant-wlan0.example
if [[ ! -z $PASSWORD ]]; then
  sed -e "s|ssid=.*$|ssid=\"$SSID\"|" -e "s|psk=.*$|psk=\"$PASSWORD\"|" wpa_supplicant-wlan0.example > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
else
  sed -e "s|ssid=.*$|ssid=\"$SSID\"|" -e "s|key_mgmt=.*$|key_mgmt=NONE|" -e "/^.*psk=/ d" wpa_supplicant-wlan0.example > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
fi
# create 10-wlan0.network from wlan0.network.dhcp or by using sed and wlan0.network.static
if [[ -z $IP ]]; then
  cp wlan0.network.dhcp 10-wlan0.network
else
  sed -e "s|Address=.*$|Address=$IP|" -e "s|Gateway=.*$|Gateway=$GATEWAY|" wlan0.network.static > 10-wlan0.network
  if [[ ! -z $DNS1 ]]; then
    echo DNS=$DNS1 >> 10-wlan0.network
  fi
  if [[ ! -z $DNS2 ]]; then
    echo DNS=$DNS2 >> 10-wlan0.network
  fi
fi

echo "restarting systemd-networkd.service"
systemctl restart systemd-networkd.service

echo "restarting web server"
systemctl restart lighttpd

echo "starting wlan0 and wpa_supplicant"
ip link set wlan0 up
sleep 1
systemctl restart wpa_supplicant@wlan0.service

ip link set eth0 down &> /dev/null

sleep 2
systemctl start control4-sddpd &> /dev/null

popd &> /dev/null
