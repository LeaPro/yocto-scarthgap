ROOTFS_POSTPROCESS_COMMAND:append:lea-trevally = " remove_bone_i2c_overlays; "

remove_bone_i2c_overlays() {
    rm -f ${IMAGE_ROOTFS}/boot/dtb/ti/BONE-I2C*.dtbo
}

# Remove unused fitImage and EFI boot files
ROOTFS_POSTPROCESS_COMMAND:append:lea-trevally = " remove_fitimage_and_efi; "

remove_fitimage_and_efi() {
    rm -f ${IMAGE_ROOTFS}/boot/fitImage ${IMAGE_ROOTFS}/boot/fitImage-*
    rm -rf ${IMAGE_ROOTFS}/boot/EFI
}

# Move DTB from /boot/dtb/ti to /boot
ROOTFS_POSTPROCESS_COMMAND:append:lea-trevally = " move_dtb_to_boot; "

move_dtb_to_boot() {
    if [ -f ${IMAGE_ROOTFS}/boot/dtb/ti/am62x-lea-trevally.dtb ]; then
        mv -f ${IMAGE_ROOTFS}/boot/dtb/ti/am62x-lea-trevally.dtb ${IMAGE_ROOTFS}/boot/am62x-lea-trevally.dtb
    fi
    rmdir --ignore-fail-on-non-empty ${IMAGE_ROOTFS}/boot/dtb/ti 2>/dev/null || true
    rmdir --ignore-fail-on-non-empty ${IMAGE_ROOTFS}/boot/dtb 2>/dev/null || true
}
