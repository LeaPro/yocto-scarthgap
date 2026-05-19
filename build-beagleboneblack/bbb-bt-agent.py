#!/usr/bin/env python3
"""
BlueZ D-Bus Agent for BeagleBone Black Bluetooth audio sink.
Handles pairing requests with auto-accept (JustWorks), sets adapter state,
registers as the default agent, and marks devices as Trusted for auto-reconnect.
"""

import sys
import signal
import logging
import os
from time import sleep
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

# Setup logging to stderr (captured by systemd)
LOG_LEVEL = os.getenv("BBB_BT_AGENT_LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format='%(asctime)s - bbb-bt-agent - %(levelname)s - %(message)s',
    stream=sys.stderr
)
log = logging.getLogger('bbb-bt-agent')

AGENT_PATH = "/org/bluez/agent/bbb"
AGENT_CAPS = "NoInputNoOutput"
BLUEZ_SERVICE = "org.bluez"
ADAPTER_PATH = "/org/bluez/hci0"
BLUEZ_PATH = "/org/bluez"
ADAPTER_IFACE = "org.bluez.Adapter1"
AGENT_IFACE = "org.bluez.Agent1"
AGENT_MGR_IFACE = "org.bluez.AgentManager1"
DEVICE_IFACE = "org.bluez.Device1"
A2DP_SOURCE_UUID = "0000110a-0000-1000-8000-00805f9b34fb"


def device_path_to_addr(device_path):
    """Convert BlueZ device object path to MAC-like string for easier logs."""
    if not isinstance(device_path, str):
        return "unknown"
    marker = "/dev_"
    if marker not in device_path:
        return device_path
    raw = device_path.split(marker, 1)[1]
    return raw.replace("_", ":")


class BlueZAgent(dbus.service.Object):
    """
    D-Bus object implementing org.bluez.Agent1 interface.
    Auto-accepts pairing and connection requests for JustWorks mode.
    Marks devices as Trusted immediately upon authorization.
    """

    def __init__(self, bus, path):
        dbus.service.Object.__init__(self, bus, path)
        self.bus = bus
        log.info(f"Agent initialized at {path}")

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        """Called by BlueZ when the agent is unregistered."""
        log.info("Agent released by BlueZ")

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        """Called when passkey needs to be displayed."""
        log.info("DisplayPasskey for %s (%s): %s entered=%s",
                 device_path_to_addr(device), device, passkey, entered)

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        """Called when PIN needs to be displayed."""
        log.info("DisplayPinCode for %s (%s): %s",
                 device_path_to_addr(device), device, pincode)

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        """
        Auto-accept JustWorks pairing.
        Called during pairing to confirm the passkey match.
        """
        log.info("RequestConfirmation accept: %s (%s), passkey=%s",
             device_path_to_addr(device), device, passkey)
        # Return without raising exception = accept

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        """Reject passkey request (NoInputNoOutput mode)."""
        log.warning("RequestPasskey from %s (%s); rejecting (NoInputNoOutput mode)",
                    device_path_to_addr(device), device)
        raise dbus.DBusException("org.bluez.Error.Rejected")

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        """Reject PIN request (NoInputNoOutput mode)."""
        log.warning("RequestPinCode from %s (%s); rejecting (NoInputNoOutput mode)",
                    device_path_to_addr(device), device)
        raise dbus.DBusException("org.bluez.Error.Rejected")

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        """Auto-authorize device-level requests in headless sink mode."""
        log.info("RequestAuthorization accept: %s (%s)",
                 device_path_to_addr(device), device)

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        """
        Auto-accept service authorization for A2DP and other audio profiles.
        Mark device as Trusted immediately so it can reconnect without re-pairing.
        """
        log.info("AuthorizeService request: %s (%s), uuid=%s",
                 device_path_to_addr(device), device, uuid)
        try:
            # Get device object and set Trusted property
            device_obj = self.bus.get_object(BLUEZ_SERVICE, device)
            props_iface = dbus.Interface(device_obj, "org.freedesktop.DBus.Properties")
            props_iface.Set(DEVICE_IFACE, "Trusted", dbus.Boolean(True))
            log.info("AuthorizeService accepted; set Trusted=True for %s (%s)",
                     device_path_to_addr(device), device)
        except dbus.DBusException as e:
            log.warning("AuthorizeService accepted but failed to set Trusted on %s (%s): %s",
                        device_path_to_addr(device), device, e)
            # Don't fail authorization over this; still accept the pairing

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        """Called if user or timeout cancels operation."""
        log.info("Operation cancelled")


def monitor_device_state(bus):
    """Log Device1 property changes to diagnose pairing/reconnect behavior."""

    def on_properties_changed(interface, changed, invalidated, path=None):
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

    bus.add_signal_receiver(
        on_properties_changed,
        dbus_interface="org.freedesktop.DBus.Properties",
        signal_name="PropertiesChanged",
        path_keyword="path"
    )
    log.info("Installed Device1 properties monitor")


def wait_for_adapter(bus, timeout_sec=30):
    """Poll D-Bus until adapter appears and its Properties interface is ready."""
    for attempt in range(timeout_sec):
        try:
            adapter = bus.get_object(BLUEZ_SERVICE, ADAPTER_PATH)
            # Verify the Properties interface is actually usable, not just the object path
            props_iface = dbus.Interface(adapter, "org.freedesktop.DBus.Properties")
            props_iface.GetAll(ADAPTER_IFACE)
            log.info(f"Adapter ready at {ADAPTER_PATH}")
            return adapter
        except dbus.DBusException as e:
            if attempt < timeout_sec - 1:
                log.debug(f"Adapter not ready ({attempt + 1}/{timeout_sec}), retrying...")
                sleep(1)
            else:
                log.error(f"Adapter {ADAPTER_PATH} not ready after {timeout_sec}s: {e}")
                raise


def set_adapter_properties(adapter):
    """Set adapter to Powered, Pairable, Discoverable."""
    try:
        props_iface = dbus.Interface(adapter, "org.freedesktop.DBus.Properties")
        props_iface.Set(ADAPTER_IFACE, "Powered", dbus.Boolean(True))
        props_iface.Set(ADAPTER_IFACE, "Pairable", dbus.Boolean(True))
        props_iface.Set(ADAPTER_IFACE, "Discoverable", dbus.Boolean(True))
        log.info("Adapter properties set: Powered, Pairable, Discoverable")
    except dbus.DBusException as e:
        log.error(f"Failed to set adapter properties: {e}")
        raise


def register_agent(bus, adapter):
    """Register this agent with BlueZ as the default agent."""
    try:
        manager_obj = bus.get_object(BLUEZ_SERVICE, BLUEZ_PATH)
        manager = dbus.Interface(manager_obj, AGENT_MGR_IFACE)
        manager.RegisterAgent(AGENT_PATH, AGENT_CAPS)
        manager.RequestDefaultAgent(AGENT_PATH)
        log.info(f"Agent registered at {AGENT_PATH} with capability {AGENT_CAPS}")
    except dbus.DBusException as e:
        log.error(f"Failed to register agent: {e}")
        raise


def reconnect_trusted_devices(bus, retry_delay=15):
    """Connect to trusted paired devices using ConnectProfile(A2DP Source).
    The phone's BT stack handles A2DP streaming once the profile connection is up.
    Reschedules itself until all trusted devices are connected.
    """
    try:
        obj_manager = dbus.Interface(
            bus.get_object(BLUEZ_SERVICE, "/"),
            "org.freedesktop.DBus.ObjectManager"
        )
        objects = obj_manager.GetManagedObjects()
        pending = False
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
                except dbus.DBusException as e:
                    log.warning("ConnectProfile %s failed: %s; will retry", addr, e)
                    pending = True
    except Exception as e:
        log.warning("reconnect_trusted_devices error: %s", e)
        pending = True

    if pending:
        GLib.timeout_add_seconds(
            retry_delay,
            lambda: reconnect_trusted_devices(bus, retry_delay) or False
        )


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    
    try:
        bus = dbus.SystemBus()
        log.info("Connected to system D-Bus")
    except dbus.DBusException as e:
        log.error(f"Failed to connect to D-Bus: {e}")
        sys.exit(1)

    try:
        adapter = wait_for_adapter(bus)
        set_adapter_properties(adapter)
        agent = BlueZAgent(bus, AGENT_PATH)
        register_agent(bus, adapter)
        monitor_device_state(bus)
        reconnect_trusted_devices(bus)
        log.info("BlueZ agent ready; waiting for phone to connect")

        mainloop = GLib.MainLoop()

        def signal_handler(signum, frame):
            log.info(f"Received signal {signum}; shutting down")
            mainloop.quit()

        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)

        mainloop.run()
        
    except Exception as e:
        log.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
