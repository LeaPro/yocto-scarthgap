sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
passwd --delete root
# remove any existing iptables rules
iptables --flush
# allow LEA API access on port 1236 for loopback interface (internal clients)
iptables -A INPUT -i lo -p tcp --dport 1236 -j ACCEPT
# block LEA API access on port 1236 from other interfaces (external clients)
iptables -A INPUT -p tcp --dport 1236 -j DROP
iptables-save > /etc/iptables/iptables.rules