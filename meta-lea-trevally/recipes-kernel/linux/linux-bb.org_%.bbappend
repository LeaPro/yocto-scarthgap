FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:lea-trevally = " \
	file://am62x-lea-trevally.dts;subdir=git/arch/arm64/boot/dts/ti \
	file://k3-am625-trevally-pinmux.dtsi;subdir=git/arch/arm64/boot/dts/ti \
	file://0002-sound-soc-dummy-add-of-match.patch \
	file://disable-audit.cfg \
	file://trevally-maya-bt.cfg \
	"
# file://0001-mfd-tps65219-restart-handler-high-priority.patch

KERNEL_CONFIG_FRAGMENTS:append:lea-trevally = " ${WORKDIR}/trevally-maya-bt.cfg"

COMPATIBLE_MACHINE:lea-trevally = "lea-trevally"

do_rebuild_dtb() {
	oe_runmake -C ${B} ${KERNEL_DEVICETREE}
	bbplain "DTB rebuilt at: ${B}/arch/arm64/boot/dts/${KERNEL_DEVICETREE}"
}

addtask rebuild_dtb after do_configure before do_compile

do_rebuild_dtb[dirs] = "${B}"
do_rebuild_dtb[nostamp] = "1"
