# linux-bb.org_%.bbappend
# BeagleBone Black + u-blox MAYA-W271 EVK: adds MAYA DTS and kernel config
#
# This bbappend applies to all linux-bb.org versions (%).
# FILESEXTRAPATHS must point to our files/ directory first.
#
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Add the MAYA-W271 DTS patch and kernel config fragment.
# NOTE: this kernel uses setup-defconfig.inc which overrides do_configure and
# uses KERNEL_CONFIG_FRAGMENTS (not SRC_URI *.cfg) to apply config fragments.
SRC_URI:append:beaglebone = " \
    file://0001-boneblack-maya-w271-sdio-uart1.patch \
    file://maya-w271.cfg \
"

# Add fragment to KERNEL_CONFIG_FRAGMENTS so setup-defconfig.inc picks it up.
KERNEL_CONFIG_FRAGMENTS:append:beaglebone = " ${WORKDIR}/maya-w271.cfg"

# Add our new DTB to the list of DTBs to build.
# The beaglebone machine.conf already sets KERNEL_DEVICETREE via
# KERNEL_DEVICETREE:bsp-bb_org-6_12 override.  We append here so both
# DTBs (stock + maya) are built and available on the FAT partition.
KERNEL_DEVICETREE:append:beaglebone = " \
    ti/omap/am335x-boneblack-maya.dtb \
"
