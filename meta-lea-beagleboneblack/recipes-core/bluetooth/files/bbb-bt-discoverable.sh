#!/bin/sh

set -eu

# BlueZ property updates are done through bt-adapter so we follow the
# documented bluez-tools path instead of driving bluetoothctl interactively.
bt-adapter --set Powered on || true
bt-adapter --set DiscoverableTimeout 0 || true
bt-adapter --set PairableTimeout 0 || true
bt-adapter --set Discoverable on || true
bt-adapter --set Pairable on || true

# Register a headless agent. The wildcard pin file lets the agent accept
# pairing requests without user interaction while still using the upstream
# bt-agent code path.
exec bt-agent --capability NoInputNoOutput --daemon --pin /etc/bluetooth/bt-agent.pin