SHELL:=/bin/bash

BIN=application-server
APPLICATION_DIR= ../../AngelShark/Linux/$(BIN)
FWUPDATE_DIR= ../../AngelShark/Linux/fwUpdate
STM32FLASH_DIR= ../../WebsocketAPI/stm32flash
IPCTOOL_DIR=../../WebsocketAPI/ipcTool
KVSTOOL_DIR=../../WebsocketAPI/kvsTool
RECIPE_DIR=../meta-lea-arc/recipes-core/$(BIN)-service
SOURCE_FILES=$(shell find $(APPLICATION_DIR) -type f)
SOURCE_FILES+=$(shell find $(FWUPDATE_DIR) -type f)
SOURCE_FILES+=$(shell find $(STM32FLASH_DIR) -type f ! -name '*.txt')
SOURCE_FILES+=$(shell find $(IPCTOOL_DIR) -type f ! -name '*.txt')
SOURCE_FILES+=$(shell find $(KVSTOOL_DIR) -type f ! -name '*.txt')
SOURCE_FILES+=$(shell find $(RECIPE_DIR) -type f ! -name $(BIN))
SOURCE_FILES+=$(shell find $(RECIPE_DIR)/files -type f -name readHwRev.sh)

# rebuild if any source files are newer than the service binary
$(RECIPE_DIR)/files/$(BIN): $(SOURCE_FILES)
	cd $(FWUPDATE_DIR) && make clean
	cd $(FWUPDATE_DIR) && ./build.sh -j4
	cp $(FWUPDATE_DIR)/obj/fwUpdate $(RECIPE_DIR)/files
	cd $(STM32FLASH_DIR) && make clean
	cd $(STM32FLASH_DIR) && ./build.sh -j4
	cp $(STM32FLASH_DIR)/stm32flash $(RECIPE_DIR)/files
	cd $(IPCTOOL_DIR) && make clean
	cd $(IPCTOOL_DIR) && ./build.sh -j4
	cp $(IPCTOOL_DIR)/obj/ipcTool $(RECIPE_DIR)/files
	cd $(KVSTOOL_DIR) && make clean
	cd $(KVSTOOL_DIR) && ./build.sh -j4
	cp $(KVSTOOL_DIR)/obj/kvsTool $(RECIPE_DIR)/files
	cd $(APPLICATION_DIR) && make clean
	cd $(APPLICATION_DIR) && ./build.sh -j4
	cp $(APPLICATION_DIR)/obj/$(BIN) $(RECIPE_DIR)/files
	./build-service.sh $(BIN)-service

# target to print variables; invoked with 'make print-VariableName'
print-%:
	@echo $* = $($*)
