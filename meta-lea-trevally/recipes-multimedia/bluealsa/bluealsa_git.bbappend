# Keep static archives out of runtime package to satisfy staticdev QA checks.
FILES:${PN}-staticdev += "${libdir}/alsa-lib/*.a"
FILES:${PN}:remove = "${libdir}/alsa-lib/*.a"

# Trevally + MAYA-W261 acts as a Bluetooth audio sink endpoint.
SYSTEMD_BLUEALSA_ARGS = "-p a2dp-sink"
SYSTEMD_BLUEALSA_APLAY_ARGS = "--pcm=bt_audio"

SYSTEMD_AUTO_ENABLE:${PN}-aplay = "enable"
