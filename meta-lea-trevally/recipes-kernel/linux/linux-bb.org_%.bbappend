FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:lea-trevally = " \
	file://am62x-lea-trevally.dts;subdir=git/arch/arm64/boot/dts/ti \
	file://k3-am625-trevally-pinmux.dtsi;subdir=git/arch/arm64/boot/dts/ti \
	file://disable-audit.cfg \
	"
# file://0001-mfd-tps65219-restart-handler-high-priority.patch

COMPATIBLE_MACHINE:lea-trevally = "lea-trevally"

do_rebuild_dtb() {
	oe_runmake -C ${B} ${KERNEL_DEVICETREE}
	bbplain "DTB rebuilt at: ${B}/arch/arm64/boot/dts/${KERNEL_DEVICETREE}"
}

addtask rebuild_dtb after do_configure before do_compile

do_rebuild_dtb[dirs] = "${B}"
do_rebuild_dtb[nostamp] = "1"
