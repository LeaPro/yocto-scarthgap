# A script to put us in wired ethernet mode

# examples:
# ./wired-mode.sh                                                         (DHCP, no 802.1x)
# ./wired-mode.sh -a 192.168.1.44/24 -g 192.168.1.1                       (static IP, no DNS, no 802.1x)
# ./wired-mode.sh -a 192.168.1.44/24 -g 192.168.1.1 -1 8.8.8.8 -2 8.8.4.4 (static IP, w/DNS, no 802.1x)
# ./wired-mode.sh -m PEAP -i bill@plunkware.com -p whatever               (DHCP, 802.1x mode=PEAP)
# ./wired-mode.sh -s                                                      (just save certs)

usage() { echo "Usage: $0 [-a <ip addr>] [-g <gateway>] [-1 <DNS1>] [-2 <DNS2>] [-m <PEAP|TLS|TTLS>] [-i <802.1x identity>] [-p <802.1x password>] [-u <802.1x anonymous_identity>] [-d <802.1x domain>] [-s]" 1>&2; exit 1; }

while getopts ":a:g:1:2:m:i:p:u:ds" o; do
  case "${o}" in
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
    m)
      MODE=${OPTARG}
      if [[ $MODE != PEAP && $MODE != TLS && $MODE != TTLS ]]; then
        usage
      fi
      ;;
    i)
      IDENTITY=${OPTARG}
      ;;
    p)
      PASSWORD=${OPTARG}
      ;;
    u)
      ANONYMOUS_IDENTITY=${OPTARG}
      ;;
    d)
      DOMAIN=${OPTARG}
      ;;
    s)
      SAVE_CERTS=1
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [[ $MODE != TLS && $MODE != TTLS ]]; then
  if [[ ! -z $SAVE_CERTS ]]; then
    # when -s option present and TLS or TTLS mode not specified, just move the uploaded certs and exit
    mkdir -p /mnt/data/certs
    mv /mnt/data/uploaded-certs/*.pem /mnt/data/certs
    mv /mnt/data/uploaded-certs/*.key /mnt/data/certs
    exit 0
  fi
fi

pushd /etc/systemd/network &> /dev/null

# stop any networking stuff we may have running (WiFi STA mode, WiFi AP mode, Wired mode)
./disabled-mode.sh

echo "configuring eth0"
# create 10-eth0.network from eth0.network.dhcp or by using sed and eth0.network.static
if [[ -z $IP ]]; then
  echo "DHCP mode"
  cp eth0.network.dhcp 10-eth0.network
else
  echo "static IP mode"
  sed -e "s|Address=.*$|Address=$IP|" -e "s|Gateway=.*$|Gateway=$GATEWAY|" eth0.network.static > 10-eth0.network
  if [[ ! -z $DNS1 ]]; then
    echo DNS=$DNS1 >> 10-eth0.network
  fi
  if [[ ! -z $DNS2 ]]; then
    echo DNS=$DNS2 >> 10-eth0.network
  fi
fi

echo "restarting systemd-networkd.service"
systemctl restart systemd-networkd.service

echo "restarting web server"
systemctl restart lighttpd

echo "starting eth0"
ip link set eth0 up

if [[ $MODE == PEAP ]]; then # basic PEAP config
  sed -e "s|identity=.*$|identity=\"$IDENTITY\"|"  -e "s|password=.*$|password=\"$PASSWORD\"|" wpa_supplicant-wired-eth0-PEAP.conf > wpa_supplicant-wired-eth0.conf
elif [[ $MODE == TLS ]]; then # basic TLS config
  sed -e "s|identity=.*$|identity=\"$IDENTITY\"|"  -e "s|private_key_passwd=.*$|private_key_passwd=\"$PASSWORD\"|" wpa_supplicant-wired-eth0-TLS.conf > wpa_supplicant-wired-eth0.conf
elif [[ $MODE == TTLS ]]; then # basic TTLS config
  sed -e "s|identity=.*$|identity=\"$IDENTITY\"|"  -e "s|password=.*$|password=\"$PASSWORD\"|" wpa_supplicant-wired-eth0-TTLS.conf > wpa_supplicant-wired-eth0.conf
fi
if [[ $MODE == TLS || $MODE == TTLS ]]; then
  if [[ ! -z $ANONYMOUS_IDENTITY ]]; then # insert optional anonymous_identity into config before ca_path
    sed -i -e "/ca_path=.*$/ i anonymous_identity=\"$ANONYMOUS_IDENTITY\"" wpa_supplicant-wired-eth0.conf
  fi
  if [[ ! -z $DOMAIN ]]; then # insert optional domain into config before ca_path
    sed -i -e "/ca_path=.*$/ i domain=\"$DOMAIN\"" wpa_supplicant-wired-eth0.conf
  fi
  if [[ ! -z $SAVE_CERTS ]]; then
    # when -s option present and TLS or TTLS mode specified, move the uploaded certs before (re)starting wpa_supplicant-wired@eth0.service
    mkdir -p /mnt/data/certs
    mv /mnt/data/uploaded-certs/*.pem /mnt/data/certs
    mv /mnt/data/uploaded-certs/*.key /mnt/data/certs
  fi
fi
if [[ ! -z $MODE ]]; then
  cp wpa_supplicant-wired-eth0.conf /etc/wpa_supplicant/wpa_supplicant-wired-eth0.conf
  echo "(re)starting wpa_supplicant-wired@eth0.service"
  systemctl restart wpa_supplicant-wired@eth0.service
fi

ip link set wlan0 down &> /dev/null

sleep 2
systemctl start control4-sddpd &> /dev/null

# workaround for broadcasting with linklocal address
route add -net 255.255.255.255 netmask 255.255.255.255 dev eth0

popd &> /dev/null
