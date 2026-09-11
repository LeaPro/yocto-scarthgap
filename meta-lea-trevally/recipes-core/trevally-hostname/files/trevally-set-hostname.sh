#!/bin/sh

set -eu

PREFIX="lea-trevally"
ETH0_ADDR_FILE="/sys/class/net/eth0/address"

if [ ! -r "$ETH0_ADDR_FILE" ]; then
    exit 0
fi

mac_addr=$(cat "$ETH0_ADDR_FILE")
[ -n "$mac_addr" ] || exit 0
[ "$mac_addr" != "00:00:00:00:00:00" ] || exit 0

mac_hex=$(echo "$mac_addr" | tr -d ':' | tr '[:upper:]' '[:lower:]')
[ "${#mac_hex}" -ge 4 ] || exit 0
suffix=${mac_hex#${mac_hex%????}}
target_hostname="${PREFIX}-${suffix}"

current_hostname=""
if [ -r /proc/sys/kernel/hostname ]; then
    current_hostname=$(cat /proc/sys/kernel/hostname)
fi

if [ "$current_hostname" != "$target_hostname" ]; then
    echo "$target_hostname" > /proc/sys/kernel/hostname
fi

if [ ! -f /etc/hostname ] || ! grep -qx "$target_hostname" /etc/hostname; then
    echo "$target_hostname" > /etc/hostname
fi
