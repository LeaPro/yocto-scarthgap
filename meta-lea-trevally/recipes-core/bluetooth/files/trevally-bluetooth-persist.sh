#!/bin/sh

set -eu

DATA_DIR="/mnt/data"
PERSIST_BT_DIR="${DATA_DIR}/bluetooth"
RUNTIME_BT_DIR="/var/lib/bluetooth"

# On SD-card bootstrap images there may be no separate data partition.
# In that case, simply skip Bluetooth persistence and keep the rootfs default.
if [ ! -e /dev/disk/by-label/data ] && [ ! -e /dev/mmcblk0p4 ] && [ ! -e /dev/mmcblk1p4 ]; then
    echo "trevally-bluetooth-persist: no persistent data partition found; skipping bind mount"
    exit 0
fi

mkdir -p "$DATA_DIR"

if ! grep -q " $DATA_DIR " /proc/mounts; then
    mount "$DATA_DIR" || true
fi

if ! grep -q " $DATA_DIR " /proc/mounts; then
    echo "trevally-bluetooth-persist: $DATA_DIR not mounted; using rootfs bond store"
    exit 0
fi

mkdir -p "$PERSIST_BT_DIR"
chmod 0755 "$PERSIST_BT_DIR"

mkdir -p "$RUNTIME_BT_DIR"

if ! grep -q " $RUNTIME_BT_DIR " /proc/mounts; then
    mount --bind "$PERSIST_BT_DIR" "$RUNTIME_BT_DIR"
fi
