# A script to print the wifi ssid if in AP or STA mode, otherwise print nothing

# are we in AP mode?
systemctl is-active --quiet hostapd
if [ $? == 0 ]; then
  # example output of "hostapd_cli get_config | grep ^ssid":
  # ssid=LEA-ARC
  hostapd_cli get_config | sed -n 's/^ssid=\(.*\)$/\1/p'
  exit
fi

# are we in STA mode?
ip link show wlan0 | grep "BROADCAST,MULTICAST,UP,LOWER_UP" &> /dev/null
if [ $? == 0 ]; then
  # example output of "wpa_cli list_networks | grep CURRENT":
  # 0       LEA PRO ROCKS       any     [CURRENT]
  wpa_cli list_networks | sed -n 's/\S\+\s\+\(.*\)\s\+\S\+\s\+\[.*CURRENT.*\].*$/\1/p'
  exit
fi
