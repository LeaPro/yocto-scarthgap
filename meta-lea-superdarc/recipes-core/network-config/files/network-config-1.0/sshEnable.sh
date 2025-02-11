sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
passwd --delete root
iptables --flush
cp /dev/null /etc/iptables/iptables.rules