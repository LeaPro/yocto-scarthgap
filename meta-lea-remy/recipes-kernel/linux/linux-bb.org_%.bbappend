FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:lea-remy = " \
	file://am62x-lea-remy.dts;subdir=git/arch/arm64/boot/dts/ti \
	file://k3-am625-remy-pinmux.dtsi;subdir=git/arch/arm64/boot/dts/ti \
	file://0002-sound-soc-dummy-add-of-match.patch \
	file://disable-audit.cfg \
	file://remy-maya-bt.cfg \
	"
# file://0001-mfd-tps65219-restart-handler-high-priority.patch

KERNEL_CONFIG_FRAGMENTS:append:lea-remy = " ${WORKDIR}/remy-maya-bt.cfg"

COMPATIBLE_MACHINE:lea-remy = "lea-remy"

do_rebuild_dtb() {
	oe_runmake -C ${B} ${KERNEL_DEVICETREE}
	bbplain "DTB rebuilt at: ${B}/arch/arm64/boot/dts/${KERNEL_DEVICETREE}"
}

addtask rebuild_dtb after do_configure

do_rebuild_dtb[dirs] = "${B}"
