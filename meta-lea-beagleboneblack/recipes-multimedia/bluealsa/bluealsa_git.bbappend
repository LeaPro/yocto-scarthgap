# BBB + MAYA acts as a Bluetooth audio sink (speaker endpoint).
# Keep BlueALSA focused on A2DP sink profile for this image.
SYSTEMD_BLUEALSA_ARGS = "-p a2dp-sink"

# Route A2DP audio to the McASP/PCM5102A DAC (card 0, device 0).
# Use plug: so ALSA's rate-conversion layer handles phones that send 44100 Hz
# while the McASP hardware only accepts 48000 Hz.
SYSTEMD_BLUEALSA_APLAY_ARGS = "--pcm=plughw:0\,0"

SYSTEMD_AUTO_ENABLE:${PN}-aplay = "enable"
