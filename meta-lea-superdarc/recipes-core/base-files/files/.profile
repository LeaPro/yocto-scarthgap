function ipAddr() {
  ifconfig | grep inet.*cast | awk '{print $2}' | awk '{print $2}' FS=":"
}
PS1='\u@\h($(ipAddr)):\w\$ '