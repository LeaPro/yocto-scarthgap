FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:lea-remy = " file://am62x-lea-remy.dts;subdir=git/arch/arm64/boot/dts/ti \
                               file://k3-am625-remy-pinmux.dtsi;subdir=git/arch/arm64/boot/dts/ti "

COMPATIBLE_MACHINE:lea-remy = "lea-remy"
