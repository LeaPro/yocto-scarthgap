# Keep static archives out of runtime package to satisfy staticdev QA checks.
FILES:${PN}-staticdev += "${libdir}/alsa-lib/*.a"
FILES:${PN}:remove = "${libdir}/alsa-lib/*.a"

# Trevally + MAYA-W261 acts as a Bluetooth audio sink endpoint.
# --initial-volume: a new phone stream starts at 25 % instead of BlueALSA's default 100 %. Phones that restore their own
# level for this device (absolute volume) still override it.
SYSTEMD_BLUEALSA_ARGS = "-p a2dp-sink --initial-volume=25"
SYSTEMD_BLUEALSA_APLAY_ARGS = "--pcm=bt_audio"

SYSTEMD_AUTO_ENABLE:${PN}-aplay = "enable"
