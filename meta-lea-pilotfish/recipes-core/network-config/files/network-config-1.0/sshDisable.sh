# remove any existing iptables rules
iptables --flush
# block SSH access
iptables -A INPUT -p tcp -m tcp --dport 22 -j DROP
# allow LEA API access on port 1236 for loopback interface (internal clients)
iptables -A INPUT -i lo -p tcp --dport 1236 -j ACCEPT
# block LEA API access on port 1236 from other interfaces (external clients)
iptables -A INPUT -p tcp --dport 1236 -j DROP
iptables-save > /etc/iptables/iptables.rules