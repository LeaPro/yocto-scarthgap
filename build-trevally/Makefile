SHELL:=/bin/bash
.PHONY: help sdk image image-quick

BUILD_DIR=$(realpath .)
LEA_DIR=$(realpath ../..)
YOCTO_DIR=${LEA_DIR}/yocto-scarthgap
WEBSOCKETAPI_DIR=${LEA_DIR}/WebsocketAPI
TREVALLY_DIR=${LEA_DIR}/Trevally

YOCTO_IMAGE=core-image-minimal
KERNEL_RECIPE=virtual/kernel

SDK_SETUP_DIR:=$(realpath $(BUILD_DIR)/..)/sdk/trevally
SDK_SETUP_TARGET:=$(SDK_SETUP_DIR)/.dummy-target

SDK_INSTALLER_DIR:=$(realpath $(BUILD_DIR))/deploy-ti/sdk
SDK_INSTALLER_ARCHIVE:=$(BUILD_DIR)/sdk-installer.tar.bz2

TOOLCHAIN_SETUP:=$(realpath ${SDK_SETUP_DIR}/environment-setup-aarch64-oe-linux)

TMP_RCFILE:=$(shell mktemp)

REQUESTED_GOALS:=$(if $(MAKECMDGOALS),$(MAKECMDGOALS),all)
HOST_SAFE_GOALS:=help print-%

ifneq ($(filter-out $(HOST_SAFE_GOALS),$(REQUESTED_GOALS)),)
ifeq ($(LEA_YOCTO_SCARTHGAP_CONTAINER),)
$(error This Makefile must be run inside the Docker container. Use ./docker-run first)
endif
endif

SUBDIR_TARGETS:=application-server gpioTool fpgaTool kvsTool ipcTool stm32flash FPGA DSP
ACTIVE_SUBDIR_TARGET:=$(firstword $(filter $(SUBDIR_TARGETS),$(MAKECMDGOALS)))
EXTRA_SUBDIR_GOALS:=$(if $(ACTIVE_SUBDIR_TARGET),$(filter-out $(ACTIVE_SUBDIR_TARGET),$(MAKECMDGOALS)),)

ifneq ($(EXTRA_SUBDIR_GOALS),)
.PHONY: $(EXTRA_SUBDIR_GOALS)
$(EXTRA_SUBDIR_GOALS):
	@:
endif

all: u-boot application-server gpioTool kvsTool ipcTool image

sdk: $(SDK_SETUP_TARGET)

$(SDK_SETUP_TARGET): $(SDK_INSTALLER_ARCHIVE)
	$(firstword $(wildcard $(SDK_INSTALLER_DIR)/*.sh)) -y -d $(SDK_SETUP_DIR)
	touch $(SDK_SETUP_TARGET)

$(SDK_INSTALLER_ARCHIVE):
	cd ${YOCTO_DIR} && \
	export DISABLE_CUSTOM_SERVICE_BINARIES=1 && \
	export BB_ENV_PASSTHROUGH_ADDITIONS="$$BB_ENV_PASSTHROUGH_ADDITIONS DISABLE_CUSTOM_SERVICE_BINARIES" && \
	source poky/oe-init-build-env $(BUILD_DIR) && \
	DISABLE_CUSTOM_SERVICE_BINARIES=1 bitbake $(YOCTO_IMAGE) -c populate_sdk && \
	cd $(SDK_INSTALLER_DIR) && \
	tar -cjf $(SDK_INSTALLER_ARCHIVE) --exclude=*.tar.bz2 *

u-boot:
	@echo building $@
	cd ${LEA_DIR}/u-boot && ./build_lea_trevally.sh
	@cp --update ${LEA_DIR}/u-boot/lea_trevally/{tiboot3.bin,tispl.bin,u-boot.img} ${YOCTO_DIR}/meta-lea-trevally/recipes-core/sftp-monitor-service/files

application-server:
	@echo building $@
	@source ${TOOLCHAIN_SETUP} && $(MAKE) --directory=${TREVALLY_DIR}/application-server $(EXTRA_SUBDIR_GOALS)
	@if [[ -z "$(EXTRA_SUBDIR_GOALS)" ]]; then cp --update ${TREVALLY_DIR}/application-server/obj/application-server ${YOCTO_DIR}/meta-lea-trevally/recipes-core/application-server-service/files; fi

gpioTool:
	@echo building $@
	@source ${TOOLCHAIN_SETUP} && $(MAKE) --directory=${TREVALLY_DIR}/application-server/$@ $(EXTRA_SUBDIR_GOALS)
	@if [[ -z "$(EXTRA_SUBDIR_GOALS)" ]]; then cp --update ${TREVALLY_DIR}/application-server/$@/obj/$@ ${YOCTO_DIR}/meta-lea-trevally/recipes-core/application-server-service/files; fi

kvsTool:
	@echo building $@
	@source ${TOOLCHAIN_SETUP} && $(MAKE) --directory=${WEBSOCKETAPI_DIR}/kvsTool $(EXTRA_SUBDIR_GOALS)
	@if [[ -z "$(EXTRA_SUBDIR_GOALS)" ]]; then cp --update ${WEBSOCKETAPI_DIR}/kvsTool/obj/kvsTool ${YOCTO_DIR}/meta-lea-trevally/recipes-core/application-server-service/files; fi

ipcTool:
	@echo building $@
	@source ${TOOLCHAIN_SETUP} && $(MAKE) --directory=${WEBSOCKETAPI_DIR}/ipcTool $(EXTRA_SUBDIR_GOALS)
	@if [[ -z "$(EXTRA_SUBDIR_GOALS)" ]]; then cp --update ${WEBSOCKETAPI_DIR}/ipcTool/obj/ipcTool ${YOCTO_DIR}/meta-lea-trevally/recipes-core/application-server-service/files; fi

image-quick:
	@echo building $@
	cd ${YOCTO_DIR} && source poky/oe-init-build-env $(BUILD_DIR) && bitbake $(YOCTO_IMAGE)
	mkdir -p ${BUILD_DIR}/postBuild/images
	@cp $(BUILD_DIR)/deploy-ti/images/lea-trevally/core-image-minimal-lea-trevally.rootfs.tar.xz ${BUILD_DIR}/postBuild/images

image: u-boot application-server gpioTool kvsTool ipcTool image-quick

kernel:
	@echo building $@
	cd ${YOCTO_DIR} && source poky/oe-init-build-env $(BUILD_DIR) && bitbake $(KERNEL_RECIPE) -c cleansstate && bitbake $(KERNEL_RECIPE)

dtb:
	@echo building $@
	cd ${YOCTO_DIR} && source poky/oe-init-build-env $(BUILD_DIR) && bitbake $(KERNEL_RECIPE) -f -c rebuild_dtb

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
	@echo "  gpioTool"
	@echo "  kvsTool"
	@echo "  ipcTool"
	@echo "  image (kernel + device tree binary + rootfs)"
	@echo "  kernel (clean sstate-cache and rebuild kernel)"
	@echo "  dtb (DTB-only kernel task)"
	@echo "  bitbake-shell"
	@echo "  sdk-shell"
