function ipAddr() {
  if ifconfig --version 2>/dev/null | grep -qi "net-tools"; then
    ifconfig | grep inet.*cast | awk '{print $2}'
  else
    ifconfig | grep inet.*cast | awk '{print $2}' | awk '{print $2}' FS=":"
  fi
}
PS1='\u@\h($(ipAddr)):\w\$ '
cd /usr/sbin