SHELL:=/bin/bash

BIN=leatcp-proxy
APPLICATION_DIR= ../../WebsocketAPI/$(BIN)
RECIPE_DIR=../meta-lea-dls/recipes-core/$(BIN)-service
SOURCE_FILES=$(shell find $(APPLICATION_DIR) -type f ! -name '*.txt')
SOURCE_FILES+=$(shell find $(RECIPE_DIR) -type f ! -name $(BIN))

# rebuild if any source files are newer than the service binary
$(RECIPE_DIR)/files/$(BIN): $(SOURCE_FILES)
	cd $(APPLICATION_DIR) && make clean
	cd $(APPLICATION_DIR) && ./build.sh -j4
	cp $(APPLICATION_DIR)/obj/$(BIN) $(RECIPE_DIR)/files
	./build-service.sh $(BIN)-service

# target to print variables; invoked with 'make print-VariableName'
print-%:
	@echo $* = $($*)