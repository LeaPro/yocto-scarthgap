SHELL:=/bin/bash

TARGET=dummy_make_target.out
RECIPE_DIR=../meta-lea-arc/recipes-kernel
SOURCE_FILES=$(shell find $(RECIPE_DIR) -type f ! -name $(TARGET))

# rebuild if any source files are newer than the make target
$(RECIPE_DIR)/$(TARGET): $(SOURCE_FILES)
	./build-kernel.sh
	touch $@

# target to print variables; invoked with 'make print-VariableName'
print-%:
	@echo $* = $($*)