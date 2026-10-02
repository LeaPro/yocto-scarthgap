SUMMARY = "LVGL (LEA Linux port fork) for Trevally"
DESCRIPTION = "LEA's fork of LVGL's lv_port_linux template, built for the Trevally \
target with the DRM (dumb-buffer) display backend and evdev input backend, so \
application-server can hold the LVGL thread at runtime."
HOMEPAGE = "https://github.com/LeaPro/LEA-LVGL"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=802d3d83ae80ef5f343050bf96cce3a4"

SRC_URI = "gitsm://github.com/LeaPro/LEA-LVGL.git;protocol=https;branch=master \
           file://trevally.defconfig \
           "
SRCREV = "7c521552bdd34434e0a872f67ab5d1aaa086a206"

S = "${WORKDIR}/git"

inherit cmake

DEPENDS = "libdrm libevdev hidapi pkgconfig-native"

# Build lvgl/lvgl_linux as shared libraries so application-server can link
# against them from the SDK and load them at runtime on target, matching the
# existing runtime-library delivery pattern used elsewhere in this layer.
#
# LV_BUILD_INSTALL defaults to off because lvgl core is added as a nested
# add_subdirectory() (the port project is the CMake top level, not lvgl
# itself), so its own install(TARGETS lvgl ...) rule is skipped unless forced
# on here -- without it, liblvgl.so is built but never copied into ${D},
# leaving application-server's link step unable to find -llvgl.
EXTRA_OECMAKE = "-DBUILD_SHARED_LIBS=ON -DLV_BUILD_INSTALL=ON"

# The port's CMakeLists.txt only honors a Kconfig defconfig when no .config
# exists yet at the source root; place ours there before cmake configures so
# it picks up the Trevally DRM+evdev selection instead of get_started.defconfig.
do_configure:prepend() {
    install -m 0644 ${WORKDIR}/trevally.defconfig ${S}/.config
}

# Neither lvgl core nor the lvgl_linux wrapper set a SOVERSION on their shared
# libraries, so OE's default packaging treats the unversioned .so files as
# dev-only symlinks and leaves the main package empty. Keep them in the main
# runtime package instead, matching the vendored-library convention used
# elsewhere in this layer (see application-server-service.bb/libsplayer-1.so).
FILES_SOLIBSDEV = ""
FILES:${PN} += "${libdir}/*.so"
