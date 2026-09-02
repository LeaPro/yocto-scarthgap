# Keep static archives out of runtime package to satisfy staticdev QA checks.
FILES:${PN}-staticdev += "${libdir}/alsa-lib/*.a"
FILES:${PN}:remove = "${libdir}/alsa-lib/*.a"
