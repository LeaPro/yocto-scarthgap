SHELL:=/bin/bash
.PHONY: help sdk recompile-dtb

BUILD_DIR=$(realpath .)
LEA_DIR=$(realpath ../..)
YOCTO_DIR=${LEA_DIR}/yocto-scarthgap
WEBSOCKETAPI_DIR=${LEA_DIR}/WebsocketAPI
REMY_DIR=${LEA_DIR}/Remora

YOCTO_IMAGE=core-image-minimal
KERNEL_RECIPE=virtual/kernel

SDK_SETUP_DIR:=$(realpath $(BUILD_DIR)/..)/sdk/remy
SDK_SETUP_TARGET:=$(SDK_SETUP_DIR)/.dummy-target

SDK_INSTALLER_DIR:=$(realpath $(BUILD_DIR))/tmp/deploy/sdk
SDK_INSTALLER_ARCHIVE:=$(BUILD_DIR)/sdk-installer.tar.bz2

TOOLCHAIN_SETUP:=$(realpath ${SDK_SETUP_DIR}/environment-setup-aarch64-poky-linux)

TMP_RCFILE:=$(shell mktemp)

all: u-boot application-server kvsTool ipcTool stm32flash dsp image

sdk: $(SDK_SETUP_TARGET)

$(SDK_SETUP_TARGET): $(SDK_INSTALLER_ARCHIVE)
	$(firstword $(wildcard $(SDK_INSTALLER_DIR)/*.sh)) -y -d $(SDK_SETUP_DIR)
	touch $(SDK_SETUP_TARGET)

$(SDK_INSTALLER_ARCHIVE):
	cd ${YOCTO_DIR} && \
	export DISABLE_CUSTOM_SERVICE_BINARIES=1 && \
	export BB_ENV_PASSTHROUGH_ADDITIONS="$$BB_ENV_PASSTHROUGH_ADDITIONS DISABLE_CUSTOM_SERVICE_BINARIES" && \
	source poky/oe-init-build-env $(BUILD_DIR) && \
	DISABLE_CUSTOM_SERVICE_BINARIES=1 bitbake $(YOCTO_IMAGE) -f -c populate_sdk && \
	cd $(SDK_INSTALLER_DIR) && \
	tar -cjf $(SDK_INSTALLER_ARCHIVE) --exclude=*.tar.bz2 *

u-boot:
	@echo building $@
	cd ${LEA_DIR}/u-boot && ./build_lea_remy.sh
	@cp --update ${LEA_DIR}/u-boot/lea_remy/{tiboot3.bin,tispl.bin,u-boot.img} ${YOCTO_DIR}/meta-lea-remy/recipes-core/sftp-monitor-service/files

application-server:
	@echo building $@
	@source ${TOOLCHAIN_SETUP} && make --directory=${REMY_DIR}/application-server $(MAKEFLAGS)
	@cp --update ${REMY_DIR}/application-server/obj/application-server ${YOCTO_DIR}/meta-lea-remy/recipes-core/application-server-service/files

kvsTool:
	@echo building $@
	@source ${TOOLCHAIN_SETUP} && make --directory=${WEBSOCKETAPI_DIR}/kvsTool $(MAKEFLAGS)
	@cp --update ${WEBSOCKETAPI_DIR}/kvsTool/obj/kvsTool ${YOCTO_DIR}/meta-lea-remy/recipes-core/application-server-service/files

ipcTool:
	@echo building $@
	@source ${TOOLCHAIN_SETUP} && make --directory=${WEBSOCKETAPI_DIR}/ipcTool $(MAKEFLAGS)
	@cp --update ${WEBSOCKETAPI_DIR}/ipcTool/obj/ipcTool ${YOCTO_DIR}/meta-lea-remy/recipes-core/application-server-service/files

stm32flash:
	@echo building $@
	@source ${TOOLCHAIN_SETUP} && make --directory=${WEBSOCKETAPI_DIR}/stm32flash $(MAKEFLAGS)
	@cp --update ${WEBSOCKETAPI_DIR}/stm32flash/stm32flash ${YOCTO_DIR}/meta-lea-remy/recipes-core/application-server-service/files

dsp:
	@echo building $@
	# note:  on linux cces returns bogus exit code 4 when the build succeeds but 'Failed to regenerate sources' due to a hard-coded check for the Windows-specific file, SourceGen.exe
	cd ${FIX_ME} && ( /opt/analog/cces/2.10.1/Eclipse/cces -application com.analog.crosscore.headlesstools -noSplash -data /tmp/workspace -project ${FIX_ME} -regensrc -cleanBuild Release-Linux || [ $$? -eq 4 ] )
	@cp --update FULL_PATH_TO_REMY_DSP.ldr ${YOCTO_DIR}/meta-lea-remy/recipes-core/application-server-service/files

dsp-fast:
	@echo building $@
	cd .${FIX_ME} && //opt/analog/cces/2.10.1/Eclipse/cces -application com.analog.crosscore.headlesstools -noSplash -data /tmp/workspace -project ${FIX_ME} -build Release-Linux
	@cp --update FULL_PATH_TO_REMY_DSP.ldr  ${YOCTO_DIR}/meta-lea-remy/recipes-core/application-server-service/files

image:
	@echo building $@
	cd ${YOCTO_DIR} && source poky/oe-init-build-env $(BUILD_DIR) && bitbake $(YOCTO_IMAGE)
	mkdir -p ${BUILD_DIR}/postBuild/images
	@cp $(BUILD_DIR)/deploy-ti/images/lea-remy/core-image-minimal-lea-remy.rootfs.tar.xz ${BUILD_DIR}/postBuild/images

kernel:
	@echo building $@
	cd ${YOCTO_DIR} && source poky/oe-init-build-env $(BUILD_DIR) && bitbake virtual/kernel -c cleansstate && bitbake virtual/kernel

dtb:
	@echo building $@
	cd ${YOCTO_DIR} && source poky/oe-init-build-env $(BUILD_DIR) && bitbake $(KERNEL_RECIPE) -c recompile_dtb

bitbake-shell:
	@echo 'PS1=$$PS1\<bitbake-shell\>$$\ ' > $(TMP_RCFILE)
	@cd ${YOCTO_DIR} && source poky/oe-init-build-env $(BUILD_DIR) && bash --rcfile $(TMP_RCFILE) -i

sdk-shell:
	@cp ${TOOLCHAIN_SETUP} $(TMP_RCFILE)
	@echo 'PS1=$$PS1\<sdk-shell\>$$' >> $(TMP_RCFILE)
	@bash --rcfile $(TMP_RCFILE) -i

# target to print variables; invoked with 'make print-VariableName'
print-%:
	@echo $* = $($*)
	
help:
	@echo "available targets:"
	@echo "  sdk"
	@echo "  u-boot"
	@echo "  application-server"
	@echo "  kvsTool"
	@echo "  ipcTool"
	@echo "  stm32flash"
	@echo "  dsp"
	@echo "  dsp-fast"
	@echo "  image (kernel + device tree binary + rootfs)"
	@echo "  kernel (clean sstate-cache and rebuild kernel)"
	@echo "  dtb (DTB-only kernel task)"
	@echo "  bitbake-shell"
	@echo "  sdk-shell"
