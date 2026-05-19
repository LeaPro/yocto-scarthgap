# build-beagleboneblack

This build target is for BeagleBone Black using:
- MACHINE = beaglebone (from meta-ti/meta-beagle)
- DISTRO = poky (default Yocto distro)

## Build in Docker

```bash
docker run --rm --mac-address="a4:4c:c8:29:84:c4" -it \
	-v "$HOME":"$HOME" \
	-v /media/wap/HDD/yocto-scarthgap-shared/downloads:/media/wap/HDD/yocto-scarthgap-shared/downloads \
	-v /media/wap/HDD/yocto-scarthgap-shared/sstate-cache:/media/wap/HDD/yocto-scarthgap-shared/sstate-cache \
	lea-yocto-scarthgap

cd ~/LEA/yocto-scarthgap/
. poky/oe-init-build-env build-beagleboneblack/
bitbake core-image-minimal
```

## Build SDK

```bash
bitbake core-image-minimal -f -c populate_sdk
find deploy-ti/sdk -name "*toolchain-*.sh"
```

Install SDK example:

```bash
cd deploy-ti/sdk
./poky-glibc-x86_64-core-image-minimal-cortexa8hf-neon-beaglebone-toolchain-<version>.sh
```

## Deploy To SD Card

Prerequisites:
- SD card is already partitioned with rootfs mounted at /media/$SUDO_USER/rootfs
- Run from build-beagleboneblack directory

```bash
sudo ./copy2SDCard.sh
```

Optional auto-unmount after copy:

```bash
sudo ./copy2SDCard.sh umount
```

## Deploy To NFS Rootfs

```bash
sudo ./copy2nfs.sh
```

Default NFS target path:
- /nfs/LEA/beagleboneblack/rootfs


## BBB to u-blox EVK-MAYA-271 UART connections

BeagleBone Black UART1 pinout (P9 header):

Signal	Pin	Description
RXD	P9.26	Receive (BBB ← IW612)
TXD	P9.24	Transmit (BBB → IW612)
CTS	P9.20	Clear To Send (BBB ← IW612 RTS)
RTS	P9.19	Request To Send (BBB → IW612 CTS)
GND	P9.1, P9.2	Ground (connect both for stability)

## stop wifi scanning on BBB
systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true
pkill -f wpa_supplicant 2>/dev/null || true
pkill -f iw 2>/dev/null || true
ip link set uap0 down 2>/dev/null || true
ip link set wfd0 down 2>/dev/null || true
ip link set mlan0 down

##  start normal WiFi management again later
ip link set mlan0 up
systemctl start NetworkManager

## WiFi testing
nmcli radio wifi on
nmcli device status
nmcli device wifi list ifname mlan0
nmcli device wifi connect "PLUNKWARE" password "soph9295" ifname mlan0
nmcli device wifi connect "PLUNKWARE" password "soph9295" ifname mlan0

## BT Pairing Data Persistence (Production TODO)

Bluetooth pairing data (link keys, trust records) is stored in `/var/lib/bluetooth/` on the
root filesystem. This means **every firmware update wipes pairing data**, requiring the user
to forget and re-pair the device from their phone.

For production, `/var/lib/bluetooth/` should be relocated to a dedicated persistent data
partition that survives flashing (similar to an Android `/data` partition). This requires:
- A separate data partition in the Yocto image partition layout (e.g. `wks` file)
- A bind-mount or symlink from `/var/lib/bluetooth` → `/data/bluetooth` at boot
- The data partition must not be erased by the OTA/flash update procedure

Until this is implemented, users must re-pair after every firmware update.

## BT testing
modprobe btnxpuart
sleep 2
systemctl status bluetooth
bluetoothctl show
bluetoothctl power on
bluetoothctl scan on
hciconfig -a
dmesg | grep -Ei "bluetooth|hci|ttyS1|nxp|firmware"
cat /proc/tty/driver/serial | grep -E "ttyS1|uart:"

## BT audio streaming sink (BBB)

Easiest embedded setup: BlueZ for pairing/control plus BlueALSA for audio routing.

This image now includes a boot-time helper that powers Bluetooth on and leaves the BBB
discoverable/pairable, so phones should be able to find it without manual setup.
It also enables BlueALSA's `bluealsa-aplay` sink service so A2DP audio can actually
start the McASP clocks when the phone begins playback.

Goal:
- make the BBB always discoverable and pairable
- accept simple/Just Works pairings
- trust the device once paired so it can reconnect and stream automatically

Typical `bluetoothctl` flow:

```bash
bluetoothctl
power on
agent NoInputNoOutput
default-agent
discoverable on
pairable on
scan on
# when a source appears:
#   pair <MAC>
#   trust <MAC>
#   connect <MAC>
```

Notes:
- Most phones/laptops still require the user to confirm pairing on the source side.
- After the first pairing, `trust <MAC>` lets the device reconnect without more prompts.
- For streaming, keep the Bluetooth audio service running (BlueALSA or the equivalent audio bridge in your image) and route its output to the McASP ALSA device.
- For a minimal BBB image, BlueALSA is usually simpler than a full desktop audio stack.

Known-good validation sequence after each fresh boot:

```bash
# 1) Core services should be active
systemctl status bluetooth bbb-bt-discoverable bbb-bt-autotrust bluealsa bluealsa-aplay

# 2) Adapter should be powered/discoverable/pairable
bluetoothctl show

# 3) bluealsa-aplay should be running as a single process
pgrep -a bluealsa-aplay

# 4) Pair/connect from phone, then verify trust + connection state
bluetoothctl devices
bluetoothctl info <PHONE_MAC>

# Expected: Paired: yes, Bonded: yes, Trusted: yes, Connected: yes

# 5) Start playback from phone and verify the stream appears
bluealsa-aplay --list-devices
```

If the phone is paired but `Trusted: no`, inspect autotrust logs:

```bash
journalctl -u bbb-bt-autotrust -n 100 --no-pager
```


## McASP audio-only sine test (BBB)

Use this to validate only the ALSA/McASP/PCM5102A path before testing BT audio streaming.

Hardware note (important):
- Some PCM5102A breakout boards leave `XSMT` (soft mute) floating or pull it low.
- If `XSMT` is not held high, BCK/LRCK/DIN can look correct but audio output remains muted.
- Tie `XSMT` to 3.3V for normal line-level output.

```bash
# 1) Confirm kernel audio path is present
dmesg | grep -Ei "mcasp|pcm5102|simple-audio-card|asoc|snd"

# 2) Confirm ALSA sees the sound card/device
aplay -l

# 3) Generate a 1 kHz stereo sine tone for 5 seconds
# If your card/device differs, replace hw:0,0 with the values from aplay -l
speaker-test -D hw:0,0 -c 2 -r 48000 -F S16_LE -t sine -f 1000 -l 1

# Optional: continuous tone (stop with Ctrl+C)
speaker-test -D hw:0,0 -c 2 -r 48000 -F S16_LE -t sine -f 1000 -l 0
```

Expected result:
- `aplay -l` shows the McASP/simple-audio-card device.
- `speaker-test` runs without `Input/output error` and audible tone is present at the DAC output.



IMPORTANT:
- Do not use `hciconfig hci0 up` for initial bring-up on this platform state.
- It can block indefinitely when the IW612 BT side is asleep.
- Use `bluetoothctl power on` (MGMT path via bluetoothd) instead.

## notes regarding f/w download to this combo WiFi/BT module

The IW612 is a single combo chip handling both WiFi (SDIO) and BT (UART). Its firmware
is shared — whichever interface initializes first loads the combined firmware image.

### Case 1: WiFi + BT (both in use)
The SDIO/WiFi driver (mwifiex) loads first at boot and downloads the combo firmware
(`nxp/sduart_nw61x_v1.bin.se`). By the time btnxpuart probes, the chip firmware is
already running. The driver detects this via a 1-second boot-signature timeout and logs
`hci0: FW already running.` — this is normal and expected.

The BT UART side of the IW612 still comes up at **115200** even after the SDIO firmware
is loaded by the WiFi driver. btnxpuart probes at fw-init-baudrate (115200), gets no
bootloader signature (1-second timeout), logs `hci0: FW already running.`, and proceeds
with HCI init at 115200. The driver then negotiates the link to a higher operating speed
via vendor HCI commands after the initial handshake.

`fw-init-baudrate = <115200>` is therefore correct for **both** the warm-firmware and
cold-firmware paths.

The BT-specific firmware files (`nxp/uart8997_bt_v4.bin`, `nxp/helper_uart_3000000.bin`)
are NOT downloaded in this path — they are only used in the cold/BT-first path described below.

### Case 2: BT only (no WiFi, or WiFi not yet initialized)
If btnxpuart probes before or without the WiFi SDIO driver, the chip is in bootloader
mode at 115200 baud. The driver detects the bootloader signature and downloads:
1. `nxp/helper_uart_3000000.bin` — switches the chip to 3 Mbaud
2. `nxp/uart8997_bt_v4.bin` — main BT firmware

In this case `fw-init-baudrate` should be **115200** (or omitted, as that is the default).
Both firmware files must be present in `/lib/firmware/nxp/` (provided by
`linux-firmware-nxp8997-common`).

### Case 3: WiFi only (no BT)
No uart1 DTS node or btnxpuart module needed. WiFi operates independently via SDIO.

### Summary table
| Scenario         | fw-init-baudrate | BT fw files needed | Notes                          |
|------------------|------------------|--------------------|--------------------------------|
| WiFi + BT        | 115200           | No                 | BT UART starts at 115200; driver negotiates speed after HCI init |
| BT only (cold)   | 115200           | Yes                | btnxpuart downloads fw itself  |
| WiFi only        | N/A              | N/A                | No uart1/bluetooth node needed |

## NXP-based known-good checklist (IW612)

This checklist aligns with NXP's public IW612 patterns (linux-imx btnxpuart +
meta-imx firmware packaging) and removes trial-and-error.

### 1) Required image content
- Kernel driver: `kernel-module-btnxpuart`
- WiFi stack used in this project: `kernel-module-mlan`, `kernel-module-moal`
- Firmware packages:
  - `linux-firmware-nxpiw612-sdio` (contains `nxp/uartspi_n61x_v1.bin.se`)
  - `linux-firmware-nxp8997-common` (contains `nxp/helper_uart_3000000.bin`, `nxp/uart8997_bt_v4.bin`)

### 2) Required DTS shape for BT over UART1
- UART1 enabled with 4-wire flow-control pinmux (RX, TX, CTS, RTS)
- Child bluetooth node:
  - `compatible = "nxp,88w8997-bt";`
  - `fw-init-baudrate = <115200>;` (correct for both warm-firmware and cold-firmware paths)
- Keep DTS property ordering valid: properties before subnodes.

### 3) Fast validation on target (WiFi + BT scenario)
```sh
modprobe btnxpuart
sleep 2
hciconfig -a
dmesg | grep -Ei "btnxpuart|bluetooth|hci0|firmware|fw already running|failed"
```

Pass criteria:
- `hci0` exists
- no repeated `Opcode 0x0c03 failed: -110`
- no repeated `Setting wake-up method failed`
- non-zero Bluetooth address in `hciconfig -a`

### 4) If BT still fails: isolate from WiFi runtime activity
```sh
systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true
ip link set mlan0 down 2>/dev/null || true
ip link set uap0 down 2>/dev/null || true
ip link set wfd0 down 2>/dev/null || true
modprobe -r moal mlan 2>/dev/null || true
modprobe -r btnxpuart 2>/dev/null || true
modprobe btnxpuart
sleep 2
hciconfig -a
dmesg | tail -80
```

### 5) Notes for manual UART probing
- With serdev-bound bluetooth DT node active, `/dev/ttyS1` raw testing is often not usable.
- If raw UART probing is needed, temporarily remove/disable the bluetooth child node,
  rebuild, deploy, and test ttyS1 directly.
- Minimal images may not include `timeout`; avoid scripts that require it unless installed.

## IW612 driver init sequence and inter-driver dependencies

The IW612 is a single combo chip with two independent host interfaces: SDIO (WiFi)
and UART (BT). Each interface has its own kernel driver, but they share the same
chip firmware. The relative timing of the two drivers has direct consequences for
BT bring-up reliability.

### Boot timeline overview

Timestamps marked [measured] are from actual dmesg/journal output captured during
bring-up on this hardware. Timestamps marked [estimated] are approximations.
The values below reflect the eMMC boot captured on 2026-05-08.

```
t=0s     Power on
         │
         ├─ kernel boot, SDIO bus enumeration
         │
t=8.693s ├─ mlan module loads  [measured: dmesg]
t=10.289s├─ moal attaches to SDIO card  [measured: dmesg]
         │    └─ moal probes SDIO device → begins downloading combo firmware
         │         (nxp/sduart_nw61x_v1.bin.se, over SDIO)
         │         During this window: MAYA_RTS is deasserted (high)
         │                             → BBB UART1_CTS is high
         │                             → all BBB UART1 TX is hardware-blocked
         │
t=?      ├─ systemd-modules-load: loads btnxpuart (same batch as mlan/moal) [estimated]
         │    └─ nxp_serdev_probe() runs: registers hci0, NO UART traffic yet
         │
t=10.578s├─ moal requests firmware  [measured: dmesg]
t=12.888s├─ moal firmware download complete  [measured: dmesg]
         │    └─ MAYA_RTS asserted (low) → BBB UART1_CTS low → UART TX unblocked
         │
t=32.753s├─ Bluetooth HCI core registered  [measured: dmesg]
         │
t~34s    ├─ bluetooth.service starts  [measured: wall-clock 13:20:07 UTC]
         │    └─ hci_dev_open() → nxp_setup() runs
         │
t=34.386s└─ "hci0: FW already running."  [measured: dmesg]
               └─ baud negotiation → power-save init → hci0 UP
```

### WiFi driver phases (mlan + moal)

**Module load** (`systemd-modules-load`, `/etc/modules-load.d/nxp-wlan.conf`):
- `mlan` loads first (moal depends on it for exported symbols).
- `moal` loads second, probes the SDIO device, and immediately begins firmware download.

**Firmware download** (moal, measured 2.31 seconds in this boot):
- Downloads `nxp/sduart_nw61x_v1.bin.se` over the SDIO bus.
- The IW612 chip holds `MAYA_RTS` deasserted (logic high) for the entire duration.
- `MAYA_RTS` is wired to BBB `P9.20` (`UART1_CTS`). With CTS high, the AM335x UART
  hardware flow control blocks all UART1 TX unconditionally — no bytes leave the host.
- This is a hardware constraint of the IW612, not a software timing coincidence.

**Download complete**:
- moal signals readiness; chip asserts `MAYA_RTS` low → `UART1_CTS` goes low → TX unblocked.
- WiFi interfaces (`mlan0`, `uap0`, `wfd0`) appear. NetworkManager starts scanning.
- The BT UART is now ready to accept commands at 115200 baud.

### BT driver phases (btnxpuart)

#### Phase 1 — Module load (`nxp_serdev_probe`)
Triggered by: `systemd-modules-load` (same batch as mlan/moal, typically ~2 seconds
after boot).

- Reads `fw-init-baudrate` from DT (defaults to 115200 if absent).
- Sets `BTNXPUART_FW_DOWNLOADING` flag.
- Allocates and registers `hci0` with the HCI core.
- Initialises power-save timer and work structs.
- **The UART serdev is not yet open — no bytes flow on UART1.**

This phase completes in milliseconds. `hci0` is visible in `hciconfig -a` at this point
but is `DOWN` and `Powered: no`.

#### Phase 2 — HCI device open (`btnxpuart_open`)
Triggered by: the first entity that calls `hci_dev_open()` on `hci0`.

Two callers:
- **bluetoothd** via MGMT `Set Powered = on`: triggered by `bluetoothctl power on` or
  automatically at daemon startup when `AutoEnable=true` is in `/etc/bluetooth/main.conf`.
- **`hciconfig hci0 up`**: calls the same `hci_dev_open()` path via ioctl `HCIDEVUP`.

The difference is purely timing — bluetoothd starts late enough (after moal firmware
download completes) that UART TX is unblocked. `hciconfig hci0 up` run earlier will
block. See "Timing hazard" below.

What happens:
- `serdev_device_open()` — UART1 TX/RX become active.
- `BTNXPUART_SERDEV_OPEN` flag is set.

#### Phase 3 — Setup (`nxp_setup`)
Triggered by: HCI core immediately after `btnxpuart_open`, within the same
`hci_dev_open()` call.

**3a — Boot-signature check** (`nxp_check_boot_sign`, up to 1 second):
- Host UART set to `fw_init_baudrate` (115200), flow control enabled.
- Waits up to 1 second for a bootloader packet (`0xaa` V1 or `0xab` V3) from chip.

**Cold path** (bootloader reply received — BT-only boot, moal not loaded):
- Chip replies with chip-ID packet; driver selects firmware by chip ID.
  - IW612 (`CHIP_ID_IW612 = 0x7601`): downloads `nxp/uartspi_n61x_v1.bin.se` (V3
    protocol).
  - W8997 (`CHIP_ID_W9098 etc.`): downloads `nxp/helper_uart_3000000.bin` first
    (reprograms chip UART registers to 3 Mbaud, host switches to match), then
    `nxp/uart8997_bt_v4.bin`.
- During download, host UART switches to `HCI_NXP_SEC_BAUDRATE` (3 Mbaud) after the
  chip's UART divisor registers have been reprogrammed.
- After download: 1.2 second settle delay, flow control re-enabled.

**Warm path** (1 second timeout — firmware already running, normal WiFi+BT boot):
- Logs: `hci0: FW already running.`
- No firmware files downloaded. Proceeds immediately to baud negotiation.

**3b — Baud-rate negotiation** (both paths):
```
serdev_set_baudrate(fw_init_baudrate)      // host UART → 115200
HCI_NXP_SET_OPER_SPEED (0xfc09)           // vendor cmd: tell chip → 3 Mbaud
  └─ on success: serdev_set_baudrate(3000000)   // host UART → 3 Mbaud
```
`HCI_NXP_SEC_BAUDRATE = 3000000` is a hardcoded compile-time constant; it is not
configurable via Kconfig, module parameters, or DTS.

**3c — Power-save init** (`ps_init`):
- Host RTS briefly toggled (deassert → assert, 5–10 ms each step).
- UART BREAK asserted then cleared to establish the wake signal baseline.
- Two vendor commands queued via HCI sync workqueue:
  - `HCI_NXP_WAKEUP_METHOD (0xfc53)` — chip configured to use BREAK as host→chip
    wake signal (default; DTR is the alternative).
  - `HCI_NXP_AUTO_SLEEP_MODE (0xfc23)` — power save enabled; idle timer = 2000 ms.

#### Phase 4 — Power-save operation (ongoing)
- After 2000 ms of TX inactivity, kernel timer fires → `ps_work_func` →
  `ps_control(SLEEP)` → UART BREAK asserted → chip sleeps.
- On next outgoing packet: `ps_wakeup()` deasserts BREAK, waits ~20 ms for chip to
  wake, then resumes TX.
- This is the state the chip is in when a user runs `hciconfig hci0 up` after an idle
  period — the chip is asleep and BREAK must be toggled first. bluetoothd handles this
  correctly via the MGMT layer; raw ioctl callers do not.

### Timing hazard: the CTS blocking window

```
t=0      t=10.578s        t=12.888s      t=34.386s
 │        │                │              │
 │  moal loads            │  moal FW     │  bluetoothd
 │  FW download starts ───→  complete   │  opens hci0 ✓  [measured]
 │        │  [measured]    │              │
 │  btnxpuart loads        │              │
 │  (hci0 registered,      │              │
 │   UART closed)          │              │
 │        │                │              │
 │        ╔════════════════╗              │
 │        ║ UART1_CTS HIGH ║              │
 │        ║  (TX blocked)  ║              │
 │        ╚════════════════╝              │
 │        │                │              │
 │  hciconfig hci0 up ─────→ hangs here  │
 │  (if run in this window)               │
```

Root cause:
1. During moal SDIO firmware download (2.31 s in this measured boot), `MAYA_RTS` is held high by the IW612.
2. This deasserts `UART1_CTS` on the BBB, blocking all UART1 TX at the hardware level.
3. `nxp_setup` calls `serdev_device_write_buf()` which blocks indefinitely waiting for
   CTS to be asserted.
4. Any caller of `hci_dev_open()` — whether `hciconfig hci0 up` or bluetoothd — will
   hang if run during this window.
5. `bluetoothd` with `AutoEnable=true` happens to start after moal firmware
  download completes because systemd's bluetooth.service starts later in the boot
   sequence. It is not immune to the hang; it just races past it reliably in practice.

For robust production use, a hard ordering guarantee should be established:
btnxpuart module load (and any `hci_dev_open` call) must be sequenced *after* moal
confirms firmware download complete. The current setup works empirically but relies on
timing rather than an explicit ordering dependency.

### Module removal (`nxp_serdev_remove`)
Before unregistering `hci0`, the driver reverts the chip BT UART back to
`fw_init_baudrate` (115200) via `HCI_NXP_SET_OPER_SPEED`. This ensures that after
`modprobe -r btnxpuart` or clean shutdown, the chip UART is at 115200 and a clean
re-probe at `fw_init_baudrate` will succeed.

## Out-of-tree kernel build process (Yocto)

This project uses two different build paths for kernel-side WiFi/BT support:

- **In-tree kernel modules** (built as part of `linux-bb.org`):
  - `btnxpuart` (`CONFIG_BT_NXPUART=m`)
  - `hci_uart` (`CONFIG_BT_HCIUART=m`, `CONFIG_BT_HCIUART_H4=y`)
- **Out-of-tree kernel modules** (separate recipe, built against staged kernel build artifacts):
  - `mlan.ko`
  - `moal.ko`

### Where each piece is defined

- Kernel customization (DTS + config fragment + DTB append):
  - `meta-lea-beagleboneblack/recipes-kernel/linux/linux-bb.org_%.bbappend`
  - `meta-lea-beagleboneblack/recipes-kernel/linux/files/maya-w271.cfg`
- Out-of-tree NXP WiFi driver recipe:
  - `meta-lea-beagleboneblack/recipes-kernel/nxp-mwifiex/nxp-mwifiex_git.bb`
- IW612 SDIO firmware recipe:
  - `meta-lea-beagleboneblack/recipes-kernel/nxp-mwifiex/nxp-iw612-fw_git.bb`
- Image composition:
  - `meta-lea-beagleboneblack/recipes-core/images/core-image-minimal.bbappend`

### Out-of-tree module task flow (`nxp-mwifiex_git.bb`)

The recipe inherits `module`, which comes from Yocto:

- `poky/meta/classes-recipe/module.bbclass`
- `poky/meta/classes-recipe/kernel-module-split.bbclass`

That class supplies the standard external-module flow:

1. `do_fetch`: clone `github.com/nxp-imx/mwifiex` at pinned `SRCREV`.
2. `do_unpack`: unpack into `${WORKDIR}/git` (set as `S`).
3. `do_patch`: apply any recipe-level patches (none currently in this recipe).
4. `do_compile`: call `oe_runmake` with kernel toolchain + staged kernel paths.
5. `do_install`: run module install target into `${D}` under `/lib/modules/${KERNEL_VERSION}`.
6. `do_package`: split `.ko` outputs into `kernel-module-*` packages and create metadata.

### Why `EXTRA_OEMAKE` is critical

`nxp-mwifiex_git.bb` sets:

- `KERNEL_SRC=${STAGING_KERNEL_BUILDDIR}`
- `KERNELDIR=${STAGING_KERNEL_BUILDDIR}`
- `INSTALLDIR=${D}/lib/modules/${KERNEL_VERSION}`

and explicit `CONFIG_*` toggles to build only the IW612/SD9177 SDIO path.

This is necessary because NXP's Makefile expects kernel build-tree variables and otherwise may
select unsupported interface/chip variants.

### Why `MODULES_INSTALL_TARGET = "install"`

`module.bbclass` defaults to `modules_install`, but this NXP driver tree provides
an `install` target. The recipe overrides:

- `MODULES_INSTALL_TARGET = "install"`

so Yocto calls the correct install rule.

### Runtime auto-load behavior from the out-of-tree recipe

`nxp-mwifiex_git.bb` installs:

- `/etc/modules-load.d/nxp-wlan.conf` with:
  - `mlan`
  - `moal`
- `/etc/modprobe.d/nxp-wlan.conf` with:
  - `options moal mod_para=nxp/wifi_mod_para.conf`

So at boot, `systemd-modules-load` loads `mlan` then `moal` in-order (required because
`moal` depends on symbols exported by `mlan`).

### How artifacts reach the final image

`core-image-minimal.bbappend` includes:

- `kernel-module-mlan`
- `kernel-module-moal`
- `kernel-module-hci-uart`
- `kernel-module-btnxpuart`
- firmware packages (`nxp-iw612-fw`, `linux-firmware-nxpiw612-sdio`, `linux-firmware-nxp8997-common`)

So a single image build contains:

- in-tree BT UART stack
- out-of-tree NXP WiFi stack
- required firmware blobs
- module-load and modprobe policy files

### Practical rebuild commands for out-of-tree changes

Use these when iterating quickly on the external module recipe:

```bash
. poky/oe-init-build-env build-beagleboneblack/
bitbake -c cleanall nxp-mwifiex
bitbake nxp-mwifiex
bitbake core-image-minimal
```

If only module code changed and image packaging is unchanged, you can often skip `cleanall`
and just run:

```bash
bitbake nxp-mwifiex -f -c compile
bitbake core-image-minimal
```



---

## C++ BlueZ D-Bus Agent Design

### Purpose

Define how to implement a BlueZ pairing agent in C++ as an object hosted inside the
product primary application process.

The objective is to replace the Python prototype (`bbb-bt-agent.py`) with a
deterministic, testable component that owns pairing, trust policy, Bluetooth
authorization behavior, and A2DP reconnect logic, while exposing control and telemetry
through the product websocket API.

---

### Validated Baseline (Python prototype)

Before implementing in C++, the following behavior was validated on hardware with the
Python prototype. The C++ implementation must reproduce all of it exactly.

#### A2DP connection direction

The BBB is an **A2DP Sink**. BlueAlsa runs as `bluealsa -p a2dp-sink` and registers
a passive incoming handler — it does **not** initiate outbound A2DP connections.

Consequence:
- `Device1.Connect()` always fails immediately with `org.bluez.Error.Failed: Input/output error`
  because there is no outgoing A2DP profile handler registered.
- The correct call to initiate reconnect from the BBB side is:

```
Device1.ConnectProfile("0000110a-0000-1000-8000-00805f9b34fb")
```

This is the A2DP **Source** UUID — it connects the BBB to the phone's source role.
BlueAlsa's registered sink handles the incoming stream once the profile connection is up.

#### Reconnect sequence on boot

1. Wait for adapter to appear and BlueAlsa to register its profiles with BlueZ.
2. Set adapter `Powered`, `Pairable`, `Discoverable`.
3. Register agent and `RequestDefaultAgent`.
4. For each trusted+paired device that is not yet connected: call `ConnectProfile(A2DP_SOURCE_UUID)`.
5. If `br-connection-unknown` is returned, phone BT radio is asleep — retry every ~15 s.
6. Stop retrying once `Device1.Connected = true`.

`br-connection-unknown` is not an error; it is the normal response when the remote
device's BT radio has not yet polled. No special handling needed beyond retry.

#### Pairing not allowed / link key mismatch

`Pairing Not Allowed (0x18)` from the phone during `ConnectProfile` means the stored
link key on the BBB does not match what the phone has. Root cause is usually:

- BBB filesystem was reflashed without removing the pairing from the phone first.
- A previous session left a stale `[LinkKey]` in `/var/lib/bluetooth/<adapter>/<device>/info`.

Recovery: remove device from both sides and re-pair from scratch. After fresh pairing,
`ConnectProfile` succeeds on the first attempt on every subsequent power cycle.

#### Pairing with LE disabled

With `ControllerMode = bredr` and `DisableLE = true` in `main.conf`, the phone will
not offer LE keys during pairing. This avoids the kernel boot warning:

```
Bluetooth: hci0: Invalid link address type 1 for <addr>
```

which appeared when the device was previously paired while LE was still enabled and
BlueZ tried to load the stored LE identity on boot. With LE disabled at pairing time
the warning does not occur.

#### `main.conf` required settings

```ini
[General]
DiscoverableTimeout = 0
PairableTimeout = 0
ControllerMode = bredr

[Policy]
AutoEnable = true
JustWorksRepairing = always

[GATT]
DisableLE = true
```

Key points:
- `AutoEnable = true` is required for the NXP IW612 to power on reliably at bluetoothd startup.
- `JustWorksRepairing = always` allows already-paired phones to reconnect without a
  new pairing confirmation dialog.
- `ControllerMode = bredr` restricts to classic BT only; combined with `DisableLE = true`
  this prevents LE key storage and avoids the `Invalid link address type` warning.
- `Experimental = true` is **not** needed. `Device1.ConnectProfile` is a standard
  BlueZ API. Experimental interfaces (`Adapter1.ConnectDevice`, `PreferredBearer`) are
  only relevant for dual-mode bearer steering, which is not needed here.

#### Service ordering

The agent service must start after both `bluetooth.service` **and** `bluealsa.service`:

```ini
[Unit]
After=bluetooth.service bluealsa.service
Requires=bluetooth.service bluealsa.service
```

If `bbb-bt-agent` starts before BlueAlsa has registered its A2DP sink profile with
BlueZ, `ConnectProfile` will fail because BlueZ has no handler for the profile yet.

---

### Product Assumptions

- The Bluetooth agent is a normal application object created by the primary service.
- The application framework supports object lifecycle hooks, optional worker threads,
  and periodic update callbacks.
- A websocket API already exists and is the control and monitoring plane for product objects.
- BlueZ is running as `bluetoothd` on the system bus and remains the Bluetooth stack authority.
- BlueAlsa (`bluealsa -p a2dp-sink`) handles A2DP media — the agent does not touch audio.
- Target mode is headless audio sink with `NoInputNoOutput` pairing capability.

---

### Scope

**In scope:**
- `org.bluez.Agent1` implementation and registration.
- Adapter state management at startup (`Powered`, `Pairable`, `Discoverable`).
- Pairing confirmation and service authorization policy.
- Device trust state management.
- Boot-time `ConnectProfile` reconnect with retry loop.
- Websocket commands and events for operations and observability.

**Out of scope:**
- Replacing BlueZ media profile internals.
- Audio pipeline implementation details.
- Kernel or firmware transport changes.
- BlueAlsa configuration.

---

### D-Bus Interfaces and Methods

BlueZ interfaces used:

- `org.bluez.AgentManager1`
- `org.bluez.Agent1`
- `org.bluez.Adapter1`
- `org.bluez.Device1`
- `org.freedesktop.DBus.Properties`
- `org.freedesktop.DBus.ObjectManager`

#### Agent methods to implement

| Method | Inputs | Behavior |
|--------|--------|----------|
| `Release` | — | Mark agent unregistered; trigger re-registration |
| `RequestPinCode` | device | Reject (`org.bluez.Error.Rejected`) — `NoInputNoOutput` mode |
| `DisplayPinCode` | device, pin | Log and emit websocket event |
| `RequestPasskey` | device | Reject — `NoInputNoOutput` mode |
| `DisplayPasskey` | device, passkey, entered | Log and emit websocket event |
| `RequestConfirmation` | device, passkey | Accept (JustWorks) or await websocket approval with timeout |
| `RequestAuthorization` | device | Accept for trusted/policy-approved devices |
| `AuthorizeService` | device, uuid | Accept audio UUIDs; set `Device1.Trusted = true` here |
| `Cancel` | — | Clear pending transaction; emit cancellation event |

> **Note:** `AuthorizeService` is the correct place to set `Trusted = true`. It is
> called once per profile connection during the pairing flow, providing the device
> object path needed to write the property.

#### Agent registration flow

```
AgentManager1.RegisterAgent(agentPath, "NoInputNoOutput")
AgentManager1.RequestDefaultAgent(agentPath)
ObjectManager.GetManagedObjects()  // enumerate existing devices
Subscribe: ObjectManager InterfacesAdded/Removed
Subscribe: Device1 PropertiesChanged (Connected, Trusted, Paired)
```

#### Reconnect call

```
Device1.ConnectProfile("0000110a-0000-1000-8000-00805f9b34fb")  // A2DP Source UUID
```

Call this after registration for each device where `Trusted=true`, `Paired=true`,
`Connected=false`. Retry on `br-connection-unknown`. Stop when `Connected=true`.

---

### C++ Object Model

| Class | Responsibility |
|-------|---------------|
| `BluetoothAgentObject` | Lifecycle, config, state machine. Public API for app object manager. |
| `BlueZBusClient` | Thin wrapper over sd-bus or sdbus-c++. Method calls, signal subscriptions. |
| `BlueZAgentAdaptor` | Hosts `org.bluez.Agent1` object path. Converts BlueZ callbacks to internal events. |
| `PairingPolicyEngine` | Accept/deny decisions: mode matrix, UUID allowlist, websocket approval with timeout fallback. |
| `ReconnectManager` | Boot-time and post-disconnect `ConnectProfile` retry loop. Monitors `PropertiesChanged` to cancel when connected. |
| `DeviceRegistry` | In-memory cache keyed by address and object path. Mirrors `Paired`, `Bonded`, `Trusted`, `Connected`, `UUIDs`, `Alias`. |
| `BluetoothWsBridge` | Maps websocket commands to agent actions; emits normalized BT events and snapshots. |

---

### Threading and Event Loop Strategy

**Model A — Dedicated Bluetooth thread (recommended):**

- Run D-Bus event loop and all BlueZ interactions on one worker thread.
- App framework posts commands via thread-safe queue.
- Preferred: deterministic ordering, no race conditions on BlueZ state.
- Keep websocket handlers off the D-Bus thread; forward through queue.

**Model B — Periodic update integration:**

- D-Bus dispatch pumped from periodic update callback.
- Only viable if update cadence is tight and non-blocking.
- Higher risk of delayed callback handling under load.

Use Model A for production. Keep all BlueZ state mutations single-threaded.

---

### Pairing and Trust Policy

Base policy for headless sink:

- **Capability:** `NoInputNoOutput`
- **Unknown device pairing:**
  - `PairingMode = Open` → auto-accept `RequestConfirmation`
  - `PairingMode = Managed` → queue for websocket operator approval with timeout
- **`Trusted` flag:** set in `AuthorizeService` after successful pairing when policy
  says remember device. Do not trust for session-only pairings.
- **`AuthorizeService` UUID filter:** accept only known audio profile UUIDs
  (A2DP Source `0000110a`, AVRCP Target `0000110c`, AVRCP `0000110e`, HFP AG `0000111f`, etc.)
- **Timeout:** pending websocket confirmation expires after configurable deadline;
  auto-reject and emit `bluetooth.pairing.timeout` on expiry.

---

### Websocket API Integration

#### Commands

| Command | Payload |
|---------|---------|
| `bluetooth.set_mode` | `mode`: `open` \| `managed` \| `locked` |
| `bluetooth.start_pairing_window` | `durationSec` |
| `bluetooth.stop_pairing_window` | — |
| `bluetooth.set_device_trust` | `address`, `trusted` |
| `bluetooth.remove_device` | `address` |
| `bluetooth.get_state` | — |
| `bluetooth.reconnect` | `address` (optional; reconnect all trusted if omitted) |

#### Events

| Event | When |
|-------|------|
| `bluetooth.agent.ready` | Agent registered and adapter configured |
| `bluetooth.agent.recovered` | Re-registered after bluetoothd restart |
| `bluetooth.pairing.requested` | `RequestConfirmation` received in managed mode |
| `bluetooth.pairing.accepted` | Pairing confirmed |
| `bluetooth.pairing.rejected` | Pairing denied or timed out |
| `bluetooth.device.paired` | New device paired and trusted |
| `bluetooth.device.trust.changed` | `Trusted` property changed |
| `bluetooth.device.connected` | `Connected` property went true |
| `bluetooth.device.disconnected` | `Connected` property went false |
| `bluetooth.reconnect.attempt` | `ConnectProfile` called for a device |
| `bluetooth.reconnect.failed` | `ConnectProfile` returned non-retryable error |
| `bluetooth.error` | Unrecoverable D-Bus or adapter error |

#### Suggested event payload fields

```json
{
  "timestampUtc": "...",
  "adapterAddress": "20:BA:36:53:87:14",
  "deviceAddress": "34:39:16:65:8E:67",
  "deviceName": "Pixel 9a",
  "bluezObjectPath": "/org/bluez/hci0/dev_34_39_16_65_8E_67",
  "reasonCode": "br-connection-unknown",
  "correlationId": "..."
}
```

---

### Lifecycle and Recovery

#### Startup sequence

1. Create `BluetoothAgentObject` from app object factory.
2. Connect to system D-Bus; verify `org.bluez` is present.
3. Wait for adapter object path (`/org/bluez/hci0`) — poll via `ObjectManager`.
4. Wait for BlueAlsa to register A2DP sink profile (check via `ObjectManager` or fixed delay).
5. Set adapter `Powered`, `Pairable`, `Discoverable`.
6. Register agent; call `RequestDefaultAgent`.
7. Enumerate trusted+paired+disconnected devices; call `ConnectProfile` for each.
8. Publish `bluetooth.agent.ready`.

#### Shutdown sequence

1. Stop accepting new pairing requests.
2. Cancel pending reconnect retries.
3. Unregister default agent and agent D-Bus object.
4. Flush pending websocket responses with terminal status.
5. Publish `bluetooth.agent.stopped`.

#### Recovery on bluetoothd restart

Subscribe to `org.freedesktop.DBus.NameOwnerChanged` for `org.bluez`. On ownership
change:

1. Invalidate all cached proxies and device registry state.
2. Re-run startup sequence from step 3.
3. Publish `bluetooth.agent.recovered`.

---

### Observability

#### Log categories

- `lifecycle` — start, stop, recover
- `dbus.call` — every outgoing method call with result
- `dbus.signal` — every received signal with key property changes
- `policy` — pairing accept/reject decisions and reasons
- `reconnect` — ConnectProfile attempts, outcomes, retry scheduling
- `websocket` — command receipt and event dispatch
- `error` — unexpected failures

#### Metrics

| Metric | Description |
|--------|-------------|
| `pairing_requests_total` | Total pairing requests received |
| `pairing_accept_total` | Auto-accepted pairings |
| `pairing_reject_total` | Rejected pairings |
| `pairing_timeout_total` | Managed-mode pairings that timed out |
| `trust_set_total` | Times `Trusted = true` was written |
| `agent_recoveries_total` | bluetoothd restart recoveries |
| `reconnect_attempts_total` | `ConnectProfile` calls made |
| `reconnect_success_total` | `ConnectProfile` calls that resulted in `Connected = true` |
| `pending_pairing_requests` | Current queue depth (gauge) |
| `known_devices` | Devices in registry (gauge) |

---

### Security and Operational Controls

- Restrict websocket command access using existing app authn/authz.
- Validate MAC address format and UUID format before any D-Bus call.
- Rate-limit pairing commands and mode switches.
- Enforce bounded pending-request queue; reject when full.
- Default production mode: `managed` or `locked`. Use `open` only during controlled
  commissioning windows.
- Never pass unvalidated websocket input as D-Bus method arguments.

---

### Yocto Integration Notes

Build/runtime dependencies:

- `bluez5`
- `dbus`
- D-Bus C++ binding: `libsystemd` (sd-bus) or `sdbus-c++`
- `bluealsa` (runtime dependency; must start before agent)

Packaging:

- Ship as part of the main application package.
- Keep `main.conf` in the recipe-managed config file (`nxp-bt-config` recipe or equivalent).
- systemd unit `After=bluetooth.service bluealsa.service`; `Requires=` both.
- Keep systemd focused on launching the main app; do not add reconnect scripts.

---

### Testing Plan

#### Unit tests

- `PairingPolicyEngine` decisions across mode matrix (`open`/`managed`/`locked`) and UUID filter.
- `DeviceRegistry` updates from synthetic `PropertiesChanged` signal sequences.
- `ReconnectManager` retry scheduling: verify fires on `br-connection-unknown`, stops on `Connected=true`.
- Websocket command validation and command-to-action mapping.

#### Integration tests

- Mock BlueZ D-Bus service for `Agent1` callback sequences.
- Verify re-registration on simulated `NameOwnerChanged`.
- Validate property writes for `Powered`, `Pairable`, `Discoverable`, and `Trusted`.
- Simulate `ConnectProfile` returning `br-connection-unknown` N times then succeeding; verify retry count and final state.
- Simulate link key mismatch (`Authentication Failure`); verify agent logs error and does not retry indefinitely.

#### Hardware tests

- Cold boot pairing in `open` and `managed` mode.
- Power cycle with trusted device present: verify `ConnectProfile` succeeds on first or subsequent attempt.
- Power cycle with phone screen off: verify `br-connection-unknown` retries until phone wakes.
- Re-flash BBB without forgetting from phone: verify `Pairing Not Allowed` is detected and logged; recover by re-pairing.
- Verify `aplay -l` and audio pass-through after repeated connect/disconnect cycles.
- Verify no `Invalid link address type` warning in kernel log after pairing with LE disabled.

---

### Phased Implementation Plan

**Phase 1 — Infrastructure**
- Add `BlueZBusClient` and `BlueZAgentAdaptor` scaffolding.
- Register agent; log all callbacks.
- Set adapter properties on startup.

**Phase 2 — Reconnect**
- Implement `ReconnectManager` with `ConnectProfile` + retry loop.
- Subscribe to `PropertiesChanged` to cancel retry when `Connected = true`.
- Emit `bluetooth.reconnect.*` events.

**Phase 3 — Policy and websocket control**
- Implement `PairingPolicyEngine` with mode matrix and UUID filter.
- Add websocket commands/events and mode control.
- Implement managed-mode approval queue with timeout.

**Phase 4 — Trust and recovery hardening**
- Explicit trust management APIs.
- `NameOwnerChanged` recovery for bluetoothd restart.
- Metrics instrumentation.

**Phase 5 — Validation and rollout**
- Complete integration and hardware test matrix above.
- Enable by default on target products; monitor field telemetry.