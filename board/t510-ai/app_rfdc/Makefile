APP_DIR := $(CURDIR)
BUILD_DIR := $(APP_DIR)/build
CMAKE_ARGS :=

ifdef TOOLCHAIN_FILE
CMAKE_ARGS += -DCMAKE_TOOLCHAIN_FILE=$(TOOLCHAIN_FILE)
endif

.PHONY: all configure build clean rebuild

all: build

configure:
	cmake -S $(APP_DIR) -B $(BUILD_DIR) $(CMAKE_ARGS)

build: configure
	cmake --build $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

rebuild: clean build
