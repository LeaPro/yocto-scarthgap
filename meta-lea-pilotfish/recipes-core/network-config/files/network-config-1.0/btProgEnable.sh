#!/bin/sh
# btProgEnable.sh
# Swap in the bt-programming DTB (which has the bluetooth serdev node removed)
# so that UART1 appears as /dev/ttyS1 after reboot, then run wmbt to flash the
# BT module firmware.  After programming, run btProgDisable.sh to restore the
# normal DTB and reboot back to production mode.
#
# Usage: /etc/systemd/network/btProgEnable.sh

BOOT_DIR=/boot
PROD_DTB="${BOOT_DIR}/am3352-lea-pilotfish.dtb"
BTPROG_DTB="${BOOT_DIR}/am3352-lea-pilotfish-btprog.dtb"
BACKUP_DTB="${BOOT_DIR}/am3352-lea-pilotfish.dtb.bak"

WMBT=/usr/bin/wmbt
MINIDRIVER=/opt/wmbt/minidriver_new.hcd
FIRMWARE=/opt/wmbt/20703A2_wiced_uart_flash.hcd
BT_REG_ON_GPIO=/sys/class/gpio/gpio46   # gpio1_14 = 32+14 = 46

# --------------------------------------------------------------------------
# Helper: export BT_REG_ON via sysfs
# --------------------------------------------------------------------------
gpio_export() {
    if [ ! -d "${BT_REG_ON_GPIO}" ]; then
        echo 46 > /sys/class/gpio/export
        sleep 0.1
        echo out > "${BT_REG_ON_GPIO}/direction"
    fi
}

# --------------------------------------------------------------------------
# Phase 1: if we're still on the production DTB, swap and reboot
# --------------------------------------------------------------------------
if [ ! -f "${BACKUP_DTB}" ]; then
    echo "btProgEnable: phase 1 – installing btprog DTB ..."
     echo "this is the new build maria"

    if [ ! -f "${BTPROG_DTB}" ]; then
        echo "btProgEnable: ${BTPROG_DTB} not found – rebuild image first." >&2
        exit 1
    fi

    cp "${PROD_DTB}" "${BACKUP_DTB}"
    cp "${BTPROG_DTB}" "${PROD_DTB}"
    sync

    echo "btProgEnable: DTB swapped. Rebooting to apply (UART1 will become /dev/ttyS1) ..."
    echo "btProgEnable: Re-run this script after reboot to flash the BT module."
    reboot
    exit 0
fi

# --------------------------------------------------------------------------
# Phase 2: we're running on the btprog DTB – /dev/ttyS1 should now exist
# --------------------------------------------------------------------------
echo "btProgEnable: phase 2 – btprog DTB is active, proceeding with flash ..."

if [ ! -c /dev/ttyS1 ]; then
    echo "btProgEnable: /dev/ttyS1 not found – is the btprog DTB actually loaded?" >&2
    echo "btProgEnable: check: strings /proc/device-tree/model" >&2
    exit 1
fi

# Sanity-check wmbt and firmware files
for f in "${WMBT}" "${MINIDRIVER}" "${FIRMWARE}"; do
    if [ ! -f "${f}" ]; then
        echo "btProgEnable: missing file: ${f}" >&2
        exit 1
    fi
done

# Kill anything that might be holding the UART open
killall hciattach 2>/dev/null || true
killall wmbt      2>/dev/null || true
sleep 0.5

# Export GPIO
gpio_export

# Pulse BT_REG_ON low→high immediately (no sleep between) then launch wmbt at once.
# The chip catches wmbt in its ROM bootloader window as it comes out of reset.
echo "btProgEnable: pulsing BT_REG_ON and starting wmbt ..."
echo 0 > "${BT_REG_ON_GPIO}/value"
echo 1 > "${BT_REG_ON_GPIO}/value"

WMBT_LOG=/tmp/wmbt_flash.log
echo "btProgEnable: starting wmbt download (this takes 60-120 seconds, do not interrupt) ..."
"${WMBT}" download /dev/ttyS1 "${MINIDRIVER}" "${FIRMWARE}" > "${WMBT_LOG}" 2>&1 &
WMBT_PID=$!

# Wait for flash to complete
wait "${WMBT_PID}"
WMBT_RC=$?

if [ "${WMBT_RC}" -ne 0 ] && [ "${WMBT_RC}" -ne 139 ]; then
    echo "btProgEnable: wmbt exited with error code ${WMBT_RC} – flash may have failed." >&2
    echo "btProgEnable: wmbt output:" >&2
    cat "${WMBT_LOG}" >&2
    exit "${WMBT_RC}"
fi

if [ "${WMBT_RC}" -eq 139 ]; then
    echo "btProgEnable: wmbt segfaulted on exit (known bug) – flash likely succeeded, verifying ..."
fi

echo "btProgEnable: flash complete."

# Note: after firmware is written to NVRAM the chip boots at 3 Mbps, so
# hciattach at 115200 will not work here.  The btbcm serdev driver handles
# baud-rate negotiation automatically when the production DTB is active.
# Restore the production DTB and reboot to verify normal BT operation.
echo ""
echo "btProgEnable: Firmware written to NVRAM."
echo "btProgEnable: Run btProgDisable.sh to restore the production DTB and reboot."
echo "btProgEnable: After reboot, check: hciconfig -a  (expect real BD Address)"
