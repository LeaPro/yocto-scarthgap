SHELL:=/bin/bash

TARGET=dummy_make_target.out
RECIPE_DIR=../meta-lea-dls/recipes-core/sftp-monitor-service
SOURCE_FILES=$(shell find $(RECIPE_DIR) -type f ! -name $(TARGET) ! -name '*.dio')

# rebuild if any source files are newer than the make target
$(RECIPE_DIR)/$(TARGET): $(SOURCE_FILES)
	./build-service.sh sftp-monitor-service
	touch $@

# target to print variables; invoked with 'make print-VariableName'
print-%:
	@echo $* = $($*)