#!/bin/sh
# btProgDisable.sh
# Restore the production DTB (with the bluetooth serdev node) after BT module
# programming is complete, then reboot to return to normal Bluetooth operation.
#
# Usage: /etc/systemd/network/btProgDisable.sh

BOOT_DIR=/boot
PROD_DTB="${BOOT_DIR}/am3352-lea-pilotfish.dtb"
BACKUP_DTB="${BOOT_DIR}/am3352-lea-pilotfish.dtb.bak"

if [ ! -f "${BACKUP_DTB}" ]; then
    echo "btProgDisable: no backup DTB found at ${BACKUP_DTB} – already in production mode?" >&2
    exit 1
fi

echo "btProgDisable: restoring production DTB ..."
cp "${BACKUP_DTB}" "${PROD_DTB}"
rm "${BACKUP_DTB}"
sync

echo "btProgDisable: DTB restored. Rebooting to normal Bluetooth operation ..."
reboot
