#!/usr/bin/env python3
"""
BlueZ D-Bus Agent for Trevally Bluetooth audio sink.
Handles pairing requests with auto-accept, sets adapter state,
registers as default agent, and marks devices as Trusted.
"""

import sys
import signal
import logging
import os
import socket
from time import sleep
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

LOG_LEVEL = os.getenv("TREVALLY_BT_AGENT_LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s - trevally-bt-agent - %(levelname)s - %(message)s",
    stream=sys.stderr,
)
log = logging.getLogger("trevally-bt-agent")

AGENT_PATH = "/org/bluez/agent/trevally"
AGENT_CAPS = "DisplayYesNo"
BLUEZ_SERVICE = "org.bluez"
ADAPTER_PATH = "/org/bluez/hci0"
BLUEZ_PATH = "/org/bluez"
ADAPTER_IFACE = "org.bluez.Adapter1"
AGENT_IFACE = "org.bluez.Agent1"
AGENT_MGR_IFACE = "org.bluez.AgentManager1"
DEVICE_IFACE = "org.bluez.Device1"
A2DP_SOURCE_UUID = "0000110a-0000-1000-8000-00805f9b34fb"
RECONNECT_INTERVAL_SEC = 15
LEGACY_PIN = os.getenv("TREVALLY_BT_LEGACY_PIN", "0000")


def device_path_to_addr(device_path):
    if not isinstance(device_path, str):
        return "unknown"
    marker = "/dev_"
    if marker not in device_path:
        return device_path
    raw = device_path.split(marker, 1)[1]
    return raw.replace("_", ":")


class BlueZAgent(dbus.service.Object):
    def __init__(self, bus, path):
        dbus.service.Object.__init__(self, bus, path)
        self.bus = bus
        log.info("Agent initialized at %s", path)

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        log.info("Agent released by BlueZ")

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        log.info(
            "DisplayPasskey for %s (%s): %s entered=%s",
            device_path_to_addr(device),
            device,
            passkey,
            entered,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        log.info(
            "DisplayPinCode for %s (%s): %s",
            device_path_to_addr(device),
            device,
            pincode,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        log.info(
            "RequestConfirmation accept: %s (%s), passkey=%s",
            device_path_to_addr(device),
            device,
            passkey,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        log.warning(
            "RequestPasskey from %s (%s); rejecting (NoInputNoOutput mode)",
            device_path_to_addr(device),
            device,
        )
        raise dbus.DBusException("org.bluez.Error.Rejected")

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        log.warning(
            "RequestPinCode from %s (%s); returning legacy PIN %s",
            device_path_to_addr(device),
            device,
            LEGACY_PIN,
        )
        return dbus.String(LEGACY_PIN)

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        log.info(
            "RequestAuthorization accept: %s (%s)",
            device_path_to_addr(device),
            device,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        log.info(
            "AuthorizeService request: %s (%s), uuid=%s",
            device_path_to_addr(device),
            device,
            uuid,
        )
        try:
            device_obj = self.bus.get_object(BLUEZ_SERVICE, device)
            props_iface = dbus.Interface(device_obj, "org.freedesktop.DBus.Properties")
            props_iface.Set(DEVICE_IFACE, "Trusted", dbus.Boolean(True))
            log.info(
                "AuthorizeService accepted; set Trusted=True for %s (%s)",
                device_path_to_addr(device),
                device,
            )
        except dbus.DBusException as err:
            log.warning(
                "AuthorizeService accepted but failed to set Trusted on %s (%s): %s",
                device_path_to_addr(device),
                device,
                err,
            )

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        log.info("Operation cancelled")


def monitor_device_state(bus):
    def on_properties_changed(interface, changed, invalidated, path=None):
        del invalidated
        if interface != DEVICE_IFACE:
            return
        interesting = {}
        for key in ("Paired", "Bonded", "Trusted", "Connected", "ServicesResolved", "RSSI"):
            if key in changed:
                interesting[key] = changed[key]
        if not interesting:
            return
        addr = device_path_to_addr(path) if path else "unknown"
        log.info("Device state change %s (%s): %s", addr, path or "", dict(interesting))

        # React quickly to disconnect/pairing state transitions.
        if any(k in interesting for k in ("Connected", "Paired", "Trusted")):
            reconnect_trusted_devices(bus)

    bus.add_signal_receiver(
        on_properties_changed,
        dbus_interface="org.freedesktop.DBus.Properties",
        signal_name="PropertiesChanged",
        path_keyword="path",
    )
    log.info("Installed Device1 properties monitor")


def wait_for_adapter(bus, timeout_sec=30):
    for attempt in range(timeout_sec):
        try:
            adapter = bus.get_object(BLUEZ_SERVICE, ADAPTER_PATH)
            props_iface = dbus.Interface(adapter, "org.freedesktop.DBus.Properties")
            props_iface.GetAll(ADAPTER_IFACE)
            log.info("Adapter ready at %s", ADAPTER_PATH)
            return adapter
        except dbus.DBusException as err:
            if attempt < timeout_sec - 1:
                sleep(1)
            else:
                log.error("Adapter %s not ready after %ss: %s", ADAPTER_PATH, timeout_sec, err)
                raise


def set_adapter_properties(adapter):
    props_iface = dbus.Interface(adapter, "org.freedesktop.DBus.Properties")
    props_iface.Set(ADAPTER_IFACE, "Powered", dbus.Boolean(True))
    props_iface.Set(ADAPTER_IFACE, "Pairable", dbus.Boolean(True))
    props_iface.Set(ADAPTER_IFACE, "Discoverable", dbus.Boolean(True))
    adapter_address = str(props_iface.Get(ADAPTER_IFACE, "Address"))
    hostname = socket.gethostname().strip()
    props_iface.Set(ADAPTER_IFACE, "Alias", dbus.String(hostname))
    log.info(
        "Adapter properties set: Powered, Pairable, Discoverable, Address=%s, Alias=%s",
        adapter_address,
        hostname,
    )


def register_agent(bus):
    manager_obj = bus.get_object(BLUEZ_SERVICE, BLUEZ_PATH)
    manager = dbus.Interface(manager_obj, AGENT_MGR_IFACE)
    manager.RegisterAgent(AGENT_PATH, AGENT_CAPS)
    manager.RequestDefaultAgent(AGENT_PATH)
    log.info("Agent registered at %s with capability %s", AGENT_PATH, AGENT_CAPS)


def reconnect_trusted_devices(bus):
    try:
        obj_manager = dbus.Interface(
            bus.get_object(BLUEZ_SERVICE, "/"),
            "org.freedesktop.DBus.ObjectManager",
        )
        objects = obj_manager.GetManagedObjects()
        for path, interfaces in objects.items():
            if DEVICE_IFACE not in interfaces:
                continue
            props = interfaces[DEVICE_IFACE]
            if props.get("Trusted") and props.get("Paired") and not props.get("Connected"):
                addr = str(props.get("Address", ""))
                if not addr:
                    continue
                log.info("ConnectProfile A2DP Source -> %s", addr)
                try:
                    device_obj = bus.get_object(BLUEZ_SERVICE, path)
                    device_iface = dbus.Interface(device_obj, DEVICE_IFACE)
                    device_iface.ConnectProfile(A2DP_SOURCE_UUID)
                    log.info("ConnectProfile succeeded for %s", addr)
                except dbus.DBusException as err:
                    log.warning("ConnectProfile %s failed: %s", addr, err)
    except Exception as err:  # broad-except kept to mirror source resilience
        log.warning("reconnect_trusted_devices error: %s", err)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

    try:
        bus = dbus.SystemBus()
    except dbus.DBusException as err:
        log.error("Failed to connect to D-Bus: %s", err)
        sys.exit(1)

    try:
        adapter = wait_for_adapter(bus)
        set_adapter_properties(adapter)
        BlueZAgent(bus, AGENT_PATH)
        register_agent(bus)
        monitor_device_state(bus)
        reconnect_trusted_devices(bus)
        GLib.timeout_add_seconds(
            RECONNECT_INTERVAL_SEC,
            lambda: reconnect_trusted_devices(bus) or True,
        )
        log.info("BlueZ agent ready; waiting for phone to connect")

        mainloop = GLib.MainLoop()

        def signal_handler(signum, frame):
            del frame
            log.info("Received signal %s; shutting down", signum)
            mainloop.quit()

        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        mainloop.run()
    except Exception as err:  # broad-except kept to mirror source resilience
        log.error("Fatal error: %s", err, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
