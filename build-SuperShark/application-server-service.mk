SHELL:=/bin/bash

BIN=application-server
APPLICATION_DIR=../../SuperShark/$(BIN)
STM32FLASH_DIR=../../WebsocketAPI/stm32flash
IPCTOOL_DIR=../../WebsocketAPI/ipcTool
KVSTOOL_DIR=../../WebsocketAPI/kvsTool
RECIPE_DIR=../meta-lea-supershark/recipes-core/$(BIN)-service
SOURCE_FILES=$(shell find $(APPLICATION_DIR) -type f)
SOURCE_FILES+=$(shell find $(STM32FLASH_DIR) -type f ! -name '*.txt')
SOURCE_FILES+=$(shell find $(IPCTOOL_DIR) -type f ! -name '*.txt')
SOURCE_FILES+=$(shell find $(KVSTOOL_DIR) -type f ! -name '*.txt')
SOURCE_FILES+=$(shell find $(RECIPE_DIR) -type f ! -name $(BIN))
SOURCE_FILES+=$(shell find $(RECIPE_DIR)/files -type f -name readHwRev.sh)

# rebuild if any source files are newer than the service binary
$(RECIPE_DIR)/files/$(BIN): $(SOURCE_FILES)
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

clean:
	rm $(RECIPE_DIR)/files/$(BIN)
	cd $(APPLICATION_DIR) && make clean

# target to print variables; invoked with 'make print-VariableName'
print-%:
	@echo $* = $($*)
