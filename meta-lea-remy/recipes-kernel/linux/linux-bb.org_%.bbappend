FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:lea-remy = " \
	file://am62x-lea-remy.dts;subdir=git/arch/arm64/boot/dts/ti \
	file://k3-am625-remy-pinmux.dtsi;subdir=git/arch/arm64/boot/dts/ti \
	file://disable-audit.cfg \
	file://0001-mfd-tps65219-restart-handler-high-priority.patch \
	"

COMPATIBLE_MACHINE:lea-remy = "lea-remy"

do_recompile_dtb() {
	oe_runmake -C ${B} ${KERNEL_DEVICETREE}
	bbplain "DTB built at: ${B}/arch/arm64/boot/dts/${KERNEL_DEVICETREE}"
}

do_recompile_dtb[nostamp] = "1"

addtask recompile_dtb after do_configure before do_compile
