# monitor the kernel log for ethernet PHY errors
# when a new error is detected:
# 1 - log the error to /mnt/data/phy-errors.txt (to faciliate an error count sensor in the application-server network/ethernet object)
# 2 - restart the application server (this has the side-effect of reinitializing the ethernet PHY and avoids race conditions with the network/ethernet object)
mkdir -p /mnt/data
mount /dev/mmcblk1p4 /mnt/data
PHY_ERROR_FILE=/mnt/data/phy-errors.txt
PHY_ERROR_PATTERN="/ethernet-phy.*not found on slave 0/ || /WARNING.*phy_state_machine/"
journalctl -fk -n 0 | awk "$PHY_ERROR_PATTERN { print \$0; fflush(); }" | while read -r LINE ; do
  echo $LINE >> $PHY_ERROR_FILE
  systemctl restart application-server
done
