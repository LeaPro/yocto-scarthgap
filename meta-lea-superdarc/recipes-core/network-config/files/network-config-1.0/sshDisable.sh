iptables -A INPUT -p tcp -m tcp --dport 22 -j DROP
iptables-save > /etc/iptables/iptables.rules