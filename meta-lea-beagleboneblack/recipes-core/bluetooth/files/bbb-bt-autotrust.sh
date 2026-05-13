#!/bin/sh

set -eu

# Poll paired devices and trust them so reconnect/stream works without
# manual bluetoothctl trust commands.
while true; do
    bluetoothctl devices | awk '{print $2}' | while IFS= read -r mac; do
        [ -n "$mac" ] || continue
        trusted=$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/Trusted:/ { print $2; exit }')
        if [ "$trusted" != "yes" ]; then
            bluetoothctl trust "$mac" >/dev/null 2>&1 || true
        fi
    done
    sleep 2
done
