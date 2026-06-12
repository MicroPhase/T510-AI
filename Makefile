SHELL := /bin/bash
.DEFAULT_GOAL := all

BOARD ?= t510-ai
BOARD_MK_FILES := $(wildcard $(CURDIR)/board/*/board.mk)
AVAILABLE_BOARDS := $(sort $(patsubst $(CURDIR)/board/%/board.mk,%,$(BOARD_MK_FILES)))
BOARD_DIR := $(CURDIR)/board/$(BOARD)

ifeq ($(filter $(BOARD),$(AVAILABLE_BOARDS)),)
$(error Unknown BOARD '$(BOARD)'. Available boards: $(AVAILABLE_BOARDS))
endif

include versions.mk
include board/common.mk
include board/$(BOARD)/board.mk

ifeq ($(filter 0 1,$(CONSOLE_UART)),)
$(error Unsupported CONSOLE_UART '$(CONSOLE_UART)'. Expected 0 or 1)
endif

NPROC ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 8)
UBOOT_JOBS ?= 1

BUILD_ROOT ?= $(CURDIR)/build
BUILD_DIR ?= $(BUILD_ROOT)/$(BOARD)
SOURCE_STAMP_DIR ?= $(CURDIR)/.source-stamps
BUILDROOT_DIR ?= $(CURDIR)/buildroot-xilinx
BUILDROOT_OUTPUT_ROOT ?= $(BUILDROOT_DIR)/output
BUILDROOT_O ?= $(BUILDROOT_OUTPUT_ROOT)/$(BOARD)
BUILDROOT_HOST_DIR := $(BUILDROOT_O)/host
CROSS_COMPILE ?= $(BUILDROOT_CROSS)
ATF_CROSS_COMPILE ?= $(CROSS_COMPILE)
VIVADO_SETTINGS ?= $(CURDIR)/scripts/xilinx-settings.sh
BUILDROOT_TOOLCHAIN_GCC := $(BUILDROOT_HOST_DIR)/bin/$(CROSS_COMPILE)gcc
BUILDROOT_TOOLCHAIN_STAMP := $(BUILDROOT_O)/.toolchain.stamp
BUILDROOT_TOOLCHAIN_FIX_STAMP := $(BUILDROOT_O)/.toolchain-fix.stamp
BUILDROOT_DROPBEAR_REFRESH_STAMP := $(BUILDROOT_O)/.dropbear-refresh-uart$(CONSOLE_UART).stamp
BUILDROOT_OUTPUT_PATH_STAMP := $(BUILDROOT_O)/.output-path.stamp
TOOLCHAIN_GCC ?= $(BUILDROOT_TOOLCHAIN_GCC)
HOST_PATH = PATH="$(BUILDROOT_HOST_DIR)/bin:$(PATH)"
SAFE_ENV = env -u LD_LIBRARY_PATH
SUBMAKE_ENV = env -u BOARD -u MAKEFLAGS -u MFLAGS
STAMP_DIR := $(BUILD_DIR)/.stamps
UBOOT_BUILD_FLAGS := $(if $(UBOOT_DTS_NAME),DEVICE_TREE=$(UBOOT_DTS_NAME))
XILINX_VERSION ?= 2022.2
VITIS_AARCH64_LINUX_DIR ?= $(if $(filter /%,$(CROSS_COMPILE)),$(patsubst %/bin/aarch64-linux-gnu-,%,$(CROSS_COMPILE)),/opt/Xilinx/Vitis/$(XILINX_VERSION)/gnu/aarch64/lin/aarch64-linux)

FETCH_SCRIPT := $(CURDIR)/scripts/fetch_repo.sh
DTC_PATCH_SCRIPT := $(CURDIR)/scripts/patch_legacy_dtc.sh
UBOOT_DTS_SYNC_SCRIPT := $(CURDIR)/scripts/sync_u_boot_dts.sh
CONSOLE_RENDER_SCRIPT := $(CURDIR)/scripts/render_ps_uart_config.py
BUILDROOT_RELOCATION_CHECK_SCRIPT := $(CURDIR)/scripts/check_buildroot_output_relocation.sh
SOURCE_RESET_SCRIPT := $(CURDIR)/scripts/reset_shared_sources.sh
SOURCE_BOARD_GUARD_SCRIPT := $(CURDIR)/scripts/check_shared_source_board.sh
ACTIVE_BOARD_FILE := $(SOURCE_STAMP_DIR)/active-board
SOURCE_PATCH_BOARD ?= $(shell if [ -f "$(ACTIVE_BOARD_FILE)" ]; then cat "$(ACTIVE_BOARD_FILE)"; else printf '%s' "$(BOARD)"; fi)

HARDWARE_FILE := $(BUILD_DIR)/$(notdir $(HW_FILE))
BITSTREAM_FILE := $(BUILD_DIR)/$(notdir $(HW_BIT))

FSBL_ELF := $(BUILD_DIR)/sdk/fsbl/Release/fsbl.elf
PMUFW_ELF := $(BUILD_DIR)/sdk/pmufw/Release/pmufw.elf
BL31_ELF := $(BUILD_DIR)/bl31.elf
BL31_BIN := $(BUILD_DIR)/bl31.bin
UBOOT_ELF := $(BUILD_DIR)/u-boot.elf

ROOTFS_CPIO := $(BUILDROOT_O)/images/rootfs.cpio.gz
ROOTFS_EXT4 := $(BUILDROOT_O)/images/rootfs.ext4
KERNEL_IMAGE := $(CURDIR)/linux-xlnx/arch/arm64/boot/Image
DT_DIR := $(BUILD_DIR)/devicetree
DT_SOURCE := $(DT_DIR)/system-top.dts
DTB_FILE := $(BUILD_DIR)/system-top.dtb
URAMDISK_FILE := $(BUILD_DIR)/$(SD_RAMDISK_NAME)

FIT_ITS := $(BUILD_DIR)/image.its
IMAGE_UB := $(BUILD_DIR)/image.ub
BOOT_BIF := $(BUILD_DIR)/boot.bif
BOOT_BIN := $(BUILD_DIR)/BOOT.BIN
BOOT_PROFILE_STAMP := $(BUILD_DIR)/.boot-profile

SD_DIR := $(BUILD_DIR)/sd
EMMC_DIR := $(BUILD_DIR)/emmc
QSPI_DIR := $(BUILD_DIR)/qspi
QSPI_IMAGE := $(QSPI_DIR)/flash_$(BOARD).bin
QSPI_LAYOUT := $(QSPI_DIR)/layout.txt
EMMC_BOOT_BIN_FILE := $(EMMC_DIR)/$(SD_BOOT_IMAGE_NAME)
QSPI_BOOT_BIN_FILE := $(QSPI_DIR)/BOOT.BIN
QSPI_IMAGE_UB_FILE := $(QSPI_DIR)/image.ub
SD_BITSTREAM_FILE = $(if $(strip $(SD_BITSTREAM_NAME)),$(SD_DIR)/$(SD_BITSTREAM_NAME))
CONSOLE_DIR := $(BUILD_DIR)/console-uart$(CONSOLE_UART)
CONSOLE_STAMP := $(STAMP_DIR)/console-uart$(CONSOLE_UART)
RENDERED_SYSTEM_USER_DTSI := $(CONSOLE_DIR)/system-user.dtsi
RENDERED_UENV_FILE := $(CONSOLE_DIR)/uEnv.txt
EMMC_UENV_FILE ?= $(BOARD_BOOT_DIR)/uEnv-emmc-ext4.txt
RENDERED_EMMC_UENV_FILE := $(CONSOLE_DIR)/uEnv-emmc-ext4.txt
RENDERED_UBOOT_CONFIG_FRAGMENT := $(CONSOLE_DIR)/fragment.config
RENDERED_BUILDROOT_POST_BUILD_SCRIPT := $(CONSOLE_DIR)/post-build.sh
RENDERED_BUILDROOT_DEFCONFIG_FILE := $(CONSOLE_DIR)/defconfig
RENDERED_UBOOT_DTS_SOURCE := $(if $(and $(UBOOT_DTS_NAME),$(UBOOT_DTS_SOURCE)),$(CONSOLE_DIR)/$(UBOOT_DTS_NAME).dts)
ACTIVE_UBOOT_DTS_SOURCE := $(if $(RENDERED_UBOOT_DTS_SOURCE),$(RENDERED_UBOOT_DTS_SOURCE),$(UBOOT_DTS_SOURCE))
LINUX_PATCH_FILES := $(sort $(wildcard $(BOARD_DIR)/patches/linux/*.patch))
BUILDROOT_PATCH_FILES := $(sort $(wildcard $(BOARD_DIR)/patches/buildroot/*.patch))
ROOTFS_OVERLAY_FILES := $(shell if [ -d "$(BOARD_BUILDROOT_DIR)/rootfs-overlay" ]; then find "$(BOARD_BUILDROOT_DIR)/rootfs-overlay" -type f -o -type l | sort; fi)
BOARD_LINUX_FILES := $(shell if [ -d "$(BOARD_LINUX_DIR)" ]; then find "$(BOARD_LINUX_DIR)" \( -type f -o -type l \) ! -name '*.o' ! -name '*.cmd' ! -name '.*.cmd' ! -name 'built-in.a' ! -name 'modules.*' | sort; fi)
U_BOOT_STAMP := $(STAMP_DIR)/u-boot-uart$(CONSOLE_UART)
U_BOOT_CONFIG_STAMP := $(STAMP_DIR)/u-boot-config-uart$(CONSOLE_UART)
BSP_STAMP := $(STAMP_DIR)/sdk-uart$(CONSOLE_UART)
DTC_COMPAT_STAMP := $(STAMP_DIR)/dtc-compat
UBOOT_DTS_STAMP := $(STAMP_DIR)/u-boot-dts-uart$(CONSOLE_UART)
BUILDROOT_DEFCONFIG_STAMP := $(BUILDROOT_O)/.defconfig-uart$(CONSOLE_UART).stamp
LINUX_CONFIG_STAMP := $(STAMP_DIR)/linux-config
BUILDROOT_FETCH_STAMP := $(SOURCE_STAMP_DIR)/buildroot-$(BUILDROOT_REPO_REF).stamp
LINUX_FETCH_STAMP := $(SOURCE_STAMP_DIR)/linux-xlnx-$(LINUX_REPO_REF).stamp
UBOOT_FETCH_STAMP := $(SOURCE_STAMP_DIR)/u-boot-xlnx-$(UBOOT_REPO_REF).stamp
ATF_FETCH_STAMP := $(SOURCE_STAMP_DIR)/arm-trusted-firmware-$(ATF_REPO_REF).stamp
EMBEDDEDSW_FETCH_STAMP := $(SOURCE_STAMP_DIR)/embeddedsw-$(EMBEDDEDSW_REPO_REF).stamp
DEVICE_TREE_FETCH_STAMP := $(SOURCE_STAMP_DIR)/device-tree-xlnx-$(DEVICE_TREE_REPO_REF).stamp

.PHONY: FORCE help list-boards show-config scaffold-board purge-sources reset-sources check-source-board all fetch repos toolchain rootfs rootfs-ext4 ramdisk kernel u-boot fsbl pmufw atf dt imageub bootbin sd emmc-package qspi clean distclean

FORCE:

all: check-source-board $(BOOT_BIN) $(IMAGE_UB) sd qspi

help:
	@echo "Targets:"
	@echo "  make list-boards - list available board names"
	@echo "  make show-config - print resolved board configuration"
	@echo "  make scaffold-board NAME=<board> [DESC=...] - create a new board skeleton"
	@echo "  make purge-sources - remove fetched upstream component repositories"
	@echo "  make reset-sources - reset shared upstream source trees before switching boards"
	@echo "  make fetch     - clone or update all external repositories"
	@echo "  make all       - build BOOT.BIN, image.ub, SD package and QSPI image"
	@echo "  make sd        - assemble SD card boot files under build/<board>/sd/"
	@echo "                  outputs: $(SD_BOOT_IMAGE_NAME), Image, uEnv.txt, $(SD_DTB_NAME), $(SD_RAMDISK_NAME)"
	@echo "  make emmc-package - assemble persistent eMMC ext4 boot package under build/<board>/emmc/"
	@echo "  make qspi      - assemble raw QSPI image under build/<board>/qspi/"
	@echo "  make clean     - remove build outputs"
	@echo "  make distclean - remove build outputs and fetched repositories"
	@echo
	@echo "Important variables:"
	@echo "  BOARD=$(BOARD)"
	@echo "  CONSOLE_UART=$(CONSOLE_UART)"
	@echo "  SOURCE_PATCH_BOARD=$(SOURCE_PATCH_BOARD)"
	@echo "  BUILD_DIR=$(BUILD_DIR)"
	@echo "  BUILDROOT_O=$(BUILDROOT_O)"
	@echo "  VIVADO_SETTINGS=$(VIVADO_SETTINGS)"
	@echo "  BOOT_BIN_INCLUDE_BITSTREAM=$(BOOT_BIN_INCLUDE_BITSTREAM)"
	@echo "  SD_BITSTREAM_NAME=$(SD_BITSTREAM_NAME)"

list-boards:
	@printf '%s\n' $(AVAILABLE_BOARDS)

show-config:
	@echo "BOARD=$(BOARD)"
	@echo "BOARD_NAME=$(BOARD_NAME)"
	@echo "BOARD_DESC=$(BOARD_DESC)"
	@echo "SOC_FAMILY=$(SOC_FAMILY)"
	@echo "HW_FILE=$(HW_FILE)"
	@echo "HW_BIT=$(HW_BIT)"
	@echo "CONSOLE_UART=$(CONSOLE_UART)"
	@echo "CONSOLE_TTY=$(CONSOLE_TTY)"
	@echo "CONSOLE_UART_BASE=$(CONSOLE_UART_BASE)"
	@echo "FSBL_STDIO=$(FSBL_STDIO)"
	@echo "FSBL_BOOT_PROFILE=$(FSBL_BOOT_PROFILE)"
	@echo "FSBL_DEBUG_LEVEL=$(FSBL_DEBUG_LEVEL)"
	@echo "PMUFW_STDIO=$(PMUFW_STDIO)"
	@echo "PMUFW_ENABLE_EFUSE_ACCESS=$(PMUFW_ENABLE_EFUSE_ACCESS)"
	@echo "ATF_MAKE_FLAGS=$(ATF_MAKE_FLAGS)"
	@echo "BOOT_BIN_INCLUDE_BITSTREAM=$(BOOT_BIN_INCLUDE_BITSTREAM)"
	@echo "BUILD_DIR=$(BUILD_DIR)"
	@echo "BUILDROOT_O=$(BUILDROOT_O)"
	@echo "BUILDROOT_DEFCONFIG_FILE=$(BUILDROOT_DEFCONFIG_FILE)"
	@echo "LINUX_DEFCONFIG=$(LINUX_DEFCONFIG)"
	@echo "UBOOT_DEFCONFIG=$(UBOOT_DEFCONFIG)"
	@echo "ATF_PLAT=$(ATF_PLAT)"
	@echo "BOOTGEN_ARCH=$(BOOTGEN_ARCH)"

scaffold-board:
	test -n "$(NAME)"
	bash "$(CURDIR)/scripts/new_board.sh" "$(NAME)" "$(if $(DESC),$(DESC),$(NAME) firmware builder)"

purge-sources:
	rm -rf buildroot-xilinx linux-xlnx u-boot-xlnx arm-trusted-firmware embeddedsw device-tree-xlnx $(SOURCE_STAMP_DIR)

reset-sources:
	bash "$(SOURCE_RESET_SCRIPT)" "$(FETCH_SCRIPT)" \
		"$(CURDIR)/board" "$(ACTIVE_BOARD_FILE)" "$(SOURCE_PATCH_BOARD)" \
		"$(BUILDROOT_REPO_URL)" "$(BUILDROOT_REPO_REF)" "$(BUILDROOT_DIR)" \
		"$(LINUX_REPO_URL)" "$(LINUX_REPO_REF)" "$(CURDIR)/linux-xlnx" \
		"$(UBOOT_REPO_URL)" "$(UBOOT_REPO_REF)" "$(CURDIR)/u-boot-xlnx" \
		"$(ATF_REPO_URL)" "$(ATF_REPO_REF)" "$(CURDIR)/arm-trusted-firmware" \
		"$(EMBEDDEDSW_REPO_URL)" "$(EMBEDDEDSW_REPO_REF)" "$(CURDIR)/embeddedsw" \
		"$(DEVICE_TREE_REPO_URL)" "$(DEVICE_TREE_REPO_REF)" "$(CURDIR)/device-tree-xlnx"
	rm -rf "$(SOURCE_STAMP_DIR)"
	find "$(BUILD_ROOT)" -path '*/.stamps/*' -type f -delete 2>/dev/null || true
	find "$(BUILDROOT_OUTPUT_ROOT)" -name '.defconfig-*.stamp' -type f -delete 2>/dev/null || true

check-source-board: | $(SOURCE_STAMP_DIR)
	bash "$(SOURCE_BOARD_GUARD_SCRIPT)" "$(ACTIVE_BOARD_FILE)" "$(BOARD)" \
		"$(CURDIR)/linux-xlnx" \
		"$(CURDIR)/u-boot-xlnx" \
		"$(CURDIR)/buildroot-xilinx"

fetch: repos $(DTC_COMPAT_STAMP)

repos: \
	$(BUILDROOT_FETCH_STAMP) \
	$(LINUX_FETCH_STAMP) \
	$(UBOOT_FETCH_STAMP) \
	$(ATF_FETCH_STAMP) \
	$(EMBEDDEDSW_FETCH_STAMP) \
	$(DEVICE_TREE_FETCH_STAMP)

$(BUILDROOT_FETCH_STAMP): | $(SOURCE_STAMP_DIR)
	$(FETCH_SCRIPT) "$(BUILDROOT_REPO_URL)" "$(BUILDROOT_REPO_REF)" "$(BUILDROOT_DIR)"
	touch $@

$(LINUX_FETCH_STAMP): | $(SOURCE_STAMP_DIR)
	$(FETCH_SCRIPT) "$(LINUX_REPO_URL)" "$(LINUX_REPO_REF)" "$(CURDIR)/linux-xlnx"
	touch $@

$(UBOOT_FETCH_STAMP): | $(SOURCE_STAMP_DIR)
	$(FETCH_SCRIPT) "$(UBOOT_REPO_URL)" "$(UBOOT_REPO_REF)" "$(CURDIR)/u-boot-xlnx"
	touch $@

$(ATF_FETCH_STAMP): | $(SOURCE_STAMP_DIR)
	$(FETCH_SCRIPT) "$(ATF_REPO_URL)" "$(ATF_REPO_REF)" "$(CURDIR)/arm-trusted-firmware"
	touch $@

$(EMBEDDEDSW_FETCH_STAMP): | $(SOURCE_STAMP_DIR)
	$(FETCH_SCRIPT) "$(EMBEDDEDSW_REPO_URL)" "$(EMBEDDEDSW_REPO_REF)" "$(CURDIR)/embeddedsw"
	touch $@

$(DEVICE_TREE_FETCH_STAMP): | $(SOURCE_STAMP_DIR)
	$(FETCH_SCRIPT) "$(DEVICE_TREE_REPO_URL)" "$(DEVICE_TREE_REPO_REF)" "$(CURDIR)/device-tree-xlnx"
	touch $@

$(DTC_COMPAT_STAMP): $(UBOOT_FETCH_STAMP) $(LINUX_FETCH_STAMP) $(DTC_PATCH_SCRIPT) | check-source-board $(STAMP_DIR)
	bash "$(DTC_PATCH_SCRIPT)" "$(CURDIR)/u-boot-xlnx/scripts/dtc/dtc-lexer.l"
	bash "$(DTC_PATCH_SCRIPT)" "$(CURDIR)/linux-xlnx/scripts/dtc/dtc-lexer.l"
	touch $@

$(CONSOLE_STAMP): | $(STAMP_DIR)
	printf '%s\n' \
		'CONSOLE_UART=$(CONSOLE_UART)' \
		'CONSOLE_TTY=$(CONSOLE_TTY)' \
		'CONSOLE_UART_BASE=$(CONSOLE_UART_BASE)' \
		'FSBL_STDIO=$(FSBL_STDIO)' \
		'PMUFW_STDIO=$(PMUFW_STDIO)' \
		'FSBL_DEBUG_LEVEL=$(FSBL_DEBUG_LEVEL)' \
		'PMUFW_ENABLE_EFUSE_ACCESS=$(PMUFW_ENABLE_EFUSE_ACCESS)' \
		'ATF_MAKE_FLAGS=$(ATF_MAKE_FLAGS)' > $@

$(CONSOLE_DIR):
	mkdir -p $@

$(RENDERED_SYSTEM_USER_DTSI): $(SYSTEM_USER_DTSI) $(CONSOLE_RENDER_SCRIPT) | $(CONSOLE_DIR)
	python3 "$(CONSOLE_RENDER_SCRIPT)" linux-dtsi --source "$<" --output "$@" --console-uart "$(CONSOLE_UART)"

$(RENDERED_UENV_FILE): $(UENV_FILE) $(CONSOLE_RENDER_SCRIPT) | $(CONSOLE_DIR)
	python3 "$(CONSOLE_RENDER_SCRIPT)" uenv --source "$<" --output "$@" --console-uart "$(CONSOLE_UART)"

$(RENDERED_EMMC_UENV_FILE): $(EMMC_UENV_FILE) $(CONSOLE_RENDER_SCRIPT) | $(CONSOLE_DIR)
	python3 "$(CONSOLE_RENDER_SCRIPT)" uenv --source "$<" --output "$@" --console-uart "$(CONSOLE_UART)"

$(RENDERED_UBOOT_CONFIG_FRAGMENT): $(UBOOT_CONFIG_FRAGMENT) $(CONSOLE_RENDER_SCRIPT) | $(CONSOLE_DIR)
	python3 "$(CONSOLE_RENDER_SCRIPT)" uboot-fragment --source "$<" --output "$@" --console-uart "$(CONSOLE_UART)"

$(RENDERED_BUILDROOT_POST_BUILD_SCRIPT): $(BOARD_BUILDROOT_DIR)/post-build.sh $(CONSOLE_RENDER_SCRIPT) | $(CONSOLE_DIR)
	python3 "$(CONSOLE_RENDER_SCRIPT)" post-build --source "$<" --output "$@" --console-uart "$(CONSOLE_UART)"
	chmod +x "$@"

$(RENDERED_BUILDROOT_DEFCONFIG_FILE): $(BUILDROOT_DEFCONFIG_FILE) $(RENDERED_BUILDROOT_POST_BUILD_SCRIPT) $(CONSOLE_RENDER_SCRIPT) | $(CONSOLE_DIR)
	python3 "$(CONSOLE_RENDER_SCRIPT)" buildroot-defconfig \
		--source "$<" \
		--output "$@" \
		--console-uart "$(CONSOLE_UART)" \
		--post-build-script "$(abspath $(RENDERED_BUILDROOT_POST_BUILD_SCRIPT))"

ifneq ($(strip $(RENDERED_UBOOT_DTS_SOURCE)),)
$(RENDERED_UBOOT_DTS_SOURCE): $(UBOOT_DTS_SOURCE) $(CONSOLE_RENDER_SCRIPT) | $(CONSOLE_DIR)
	python3 "$(CONSOLE_RENDER_SCRIPT)" uboot-dts --source "$<" --output "$@" --console-uart "$(CONSOLE_UART)"
endif

$(UBOOT_DTS_STAMP): $(UBOOT_FETCH_STAMP) $(ACTIVE_UBOOT_DTS_SOURCE) $(UBOOT_DTS_SYNC_SCRIPT) | check-source-board $(STAMP_DIR)
	if [ -n "$(UBOOT_DTS_NAME)" ] && [ -n "$(UBOOT_DTS_SOURCE)" ]; then \
		bash "$(UBOOT_DTS_SYNC_SCRIPT)" \
			"$(ACTIVE_UBOOT_DTS_SOURCE)" \
			"$(CURDIR)/u-boot-xlnx/arch/arm/dts/$(UBOOT_DTS_NAME).dts" \
			"$(CURDIR)/u-boot-xlnx/arch/arm/dts/Makefile" \
			"$(UBOOT_DTS_NAME)"; \
	fi
	touch $@

toolchain: $(BUILDROOT_TOOLCHAIN_FIX_STAMP)

$(BUILDROOT_OUTPUT_PATH_STAMP): $(BUILDROOT_RELOCATION_CHECK_SCRIPT)
	bash "$(BUILDROOT_RELOCATION_CHECK_SCRIPT)" "$(BUILDROOT_O)" "$@"

$(BUILDROOT_DEFCONFIG_STAMP): $(BUILDROOT_FETCH_STAMP) $(RENDERED_BUILDROOT_DEFCONFIG_FILE) $(BOARD_DIR)/apply-buildroot-patches.sh $(BUILDROOT_PATCH_FILES) | check-source-board $(BUILDROOT_OUTPUT_PATH_STAMP)
	if [ -f "$(BOARD_DIR)/apply-buildroot-patches.sh" ]; then \
		bash "$(BOARD_DIR)/apply-buildroot-patches.sh" "$(BUILDROOT_DIR)"; \
	fi
	$(SAFE_ENV) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C $(BUILDROOT_DIR) O=$(BUILDROOT_O) BR2_EXTERNAL=$(CURDIR)/buildroot-external BR2_DEFCONFIG=$(RENDERED_BUILDROOT_DEFCONFIG_FILE) defconfig
	touch $@

$(BUILDROOT_TOOLCHAIN_STAMP): $(BUILDROOT_DEFCONFIG_STAMP) | $(BUILDROOT_OUTPUT_PATH_STAMP)
	$(SAFE_ENV) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C $(BUILDROOT_DIR) O=$(BUILDROOT_O) toolchain
	touch $@

$(BUILDROOT_TOOLCHAIN_FIX_STAMP): $(BUILDROOT_TOOLCHAIN_STAMP) scripts/fix_vitis_toolchain_wrappers.sh | $(BUILDROOT_OUTPUT_PATH_STAMP)
	bash scripts/fix_vitis_toolchain_wrappers.sh "$(BUILDROOT_HOST_DIR)/bin" "$(VITIS_AARCH64_LINUX_DIR)"
	touch $@

$(BUILDROOT_DROPBEAR_REFRESH_STAMP): $(BUILDROOT_DEFCONFIG_STAMP) $(BUILDROOT_TOOLCHAIN_FIX_STAMP) | $(BUILDROOT_OUTPUT_PATH_STAMP)
	@if grep -q '^BR2_PACKAGE_DROPBEAR=y' "$(BUILDROOT_O)/.config"; then \
		$(SAFE_ENV) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C $(BUILDROOT_DIR) O=$(BUILDROOT_O) dropbear-dirclean; \
	fi
	touch $@

$(ROOTFS_CPIO): $(BUILDROOT_DEFCONFIG_STAMP) $(BUILDROOT_TOOLCHAIN_FIX_STAMP) $(BUILDROOT_DROPBEAR_REFRESH_STAMP) $(EMBEDDEDSW_FETCH_STAMP) $(RENDERED_BUILDROOT_POST_BUILD_SCRIPT) $(ROOTFS_OVERLAY_FILES) | $(BUILDROOT_OUTPUT_PATH_STAMP)
	$(SAFE_ENV) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C $(BUILDROOT_DIR) O=$(BUILDROOT_O)

$(ROOTFS_EXT4): $(ROOTFS_CPIO)
	test -s "$@"

$(HARDWARE_FILE): $(HW_FILE) | $(BUILD_DIR)
	cp $< $@

$(BITSTREAM_FILE): $(HW_BIT) | $(BUILD_DIR)
	cp $< $@

$(LINUX_CONFIG_STAMP): $(LINUX_FETCH_STAMP) $(DTC_COMPAT_STAMP) $(BUILDROOT_TOOLCHAIN_FIX_STAMP) $(BOARD_DIR)/apply-linux-patches.sh $(LINUX_PATCH_FILES) $(BOARD_LINUX_FILES) | check-source-board $(STAMP_DIR)
	# Apply Linux kernel patches if available
	if [ -f "$(BOARD_DIR)/apply-linux-patches.sh" ]; then \
		bash "$(BOARD_DIR)/apply-linux-patches.sh" "$(CURDIR)/linux-xlnx"; \
	fi
	$(HOST_PATH) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C linux-xlnx ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) $(LINUX_DEFCONFIG)

	touch $@

$(KERNEL_IMAGE): $(LINUX_CONFIG_STAMP)
	$(HOST_PATH) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C linux-xlnx -j $(NPROC) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) Image
	touch $@

$(U_BOOT_CONFIG_STAMP): $(UBOOT_FETCH_STAMP) $(DTC_COMPAT_STAMP) $(UBOOT_DTS_STAMP) $(BUILDROOT_TOOLCHAIN_FIX_STAMP) $(RENDERED_UBOOT_CONFIG_FRAGMENT) | $(STAMP_DIR)
	$(HOST_PATH) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C u-boot-xlnx ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) $(UBOOT_BUILD_FLAGS) $(UBOOT_DEFCONFIG)
	cd u-boot-xlnx && ./scripts/kconfig/merge_config.sh -m .config $(RENDERED_UBOOT_CONFIG_FRAGMENT)
	$(HOST_PATH) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C u-boot-xlnx ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) $(UBOOT_BUILD_FLAGS) olddefconfig
	touch $@

$(U_BOOT_STAMP): $(U_BOOT_CONFIG_STAMP) | $(STAMP_DIR)
	$(HOST_PATH) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C u-boot-xlnx -j $(UBOOT_JOBS) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) $(UBOOT_BUILD_FLAGS) u-boot.elf tools
	touch $@

$(UBOOT_ELF): $(U_BOOT_STAMP) | $(BUILD_DIR)
	cp u-boot-xlnx/u-boot.elf $@

$(BL31_ELF): $(ATF_FETCH_STAMP) $(BUILDROOT_TOOLCHAIN_FIX_STAMP) $(CONSOLE_STAMP) | $(BUILD_DIR)
	$(HOST_PATH) $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C arm-trusted-firmware -j $(NPROC) \
		PLAT=$(ATF_PLAT) RESET_TO_BL31=1 CROSS_COMPILE=$(ATF_CROSS_COMPILE) \
		CFLAGS=-fno-stack-protector \
		$(ATF_MAKE_FLAGS) bl31
	cp arm-trusted-firmware/build/$(ATF_PLAT)/release/bl31/bl31.elf $@
	cp arm-trusted-firmware/build/$(ATF_PLAT)/release/bl31.bin $(BL31_BIN)

$(BSP_STAMP): $(HARDWARE_FILE) $(EMBEDDEDSW_FETCH_STAMP) scripts/build_zynqmp_bsp.tcl $(CONSOLE_STAMP) | $(STAMP_DIR)
	test -n "$(VIVADO_SETTINGS)"
	source "$(VIVADO_SETTINGS)" && command -v xsct >/dev/null && \
		xsct scripts/build_zynqmp_bsp.tcl "$(HARDWARE_FILE)" "$(BUILD_DIR)/sdk" "$(CURDIR)/embeddedsw" "$(FSBL_PROC)" "$(PMUFW_PROC)" "$(FSBL_STDIO)" "$(PMUFW_STDIO)" "$(FSBL_BOOT_PROFILE)" "$(FSBL_DEBUG_LEVEL)" "$(PMUFW_ENABLE_EFUSE_ACCESS)"
	touch $@

$(FSBL_ELF): $(BSP_STAMP)
	test -n "$(VIVADO_SETTINGS)"
	source "$(VIVADO_SETTINGS)" && command -v aarch64-none-elf-gcc >/dev/null && \
		$(MAKE) -C "$(BUILD_DIR)/sdk/hw_0/zynqmp_fsbl" clean all
	mkdir -p "$(dir $@)"
	cp "$(BUILD_DIR)/sdk/hw_0/zynqmp_fsbl/executable.elf" "$@"

$(PMUFW_ELF): $(BSP_STAMP)
	test -n "$(VIVADO_SETTINGS)"
	source "$(VIVADO_SETTINGS)" && command -v mb-gcc >/dev/null && \
		$(MAKE) -C "$(BUILD_DIR)/sdk/hw_0/zynqmp_pmufw" clean all
	mkdir -p "$(dir $@)"
	cp "$(BUILD_DIR)/sdk/hw_0/zynqmp_pmufw/executable.elf" "$@"

$(DT_SOURCE): $(HARDWARE_FILE) $(DEVICE_TREE_FETCH_STAMP) scripts/gen_dt.tcl $(RENDERED_SYSTEM_USER_DTSI) | $(DT_DIR)
	test -n "$(VIVADO_SETTINGS)"
	source "$(VIVADO_SETTINGS)" && command -v xsct >/dev/null && \
		xsct scripts/gen_dt.tcl "$(HARDWARE_FILE)" "$(CURDIR)/device-tree-xlnx" "$(DT_DIR)" "$(DT_PROC)" "$(RENDERED_SYSTEM_USER_DTSI)"

$(DTB_FILE): $(DT_SOURCE) | $(BUILD_DIR)
	cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -P \
		-I $(DT_DIR) \
		-I $(CURDIR)/linux-xlnx \
		-I $(CURDIR)/linux-xlnx/include \
		-I $(CURDIR)/linux-xlnx/arch/arm64/boot/dts \
		-I $(CURDIR)/linux-xlnx/arch/arm64/boot/dts/xilinx \
		$(DT_SOURCE) > $(BUILD_DIR)/system-top.pp.dts
	dtc -@ -I dts -O dtb -o $@ $(BUILD_DIR)/system-top.pp.dts

$(FIT_ITS): scripts/gen_image_its.sh $(KERNEL_IMAGE) $(DTB_FILE) $(ROOTFS_CPIO) | $(BUILD_DIR)
	scripts/gen_image_its.sh "$@" "$(KERNEL_IMAGE)" "$(DTB_FILE)" "$(ROOTFS_CPIO)" "$(FIT_DESCRIPTION)" "$(FIT_KERNEL_LOAD_ADDR)" "$(FIT_KERNEL_ENTRY_ADDR)"

$(IMAGE_UB): $(FIT_ITS) $(U_BOOT_STAMP) $(KERNEL_IMAGE) $(DTB_FILE) $(ROOTFS_CPIO) | $(BUILD_DIR)
	$(HOST_PATH) u-boot-xlnx/tools/mkimage -f $(FIT_ITS) $@ || \
	{ \
		test -s "$@" && \
		fdtget "$@" / description >/dev/null 2>&1 && \
		fdtget "$@" /configurations default >/dev/null 2>&1 && \
		fdtget "$@" /images/kernel@1 type >/dev/null 2>&1; \
	}

$(URAMDISK_FILE): $(ROOTFS_CPIO) $(U_BOOT_STAMP) | $(BUILD_DIR)
	$(HOST_PATH) u-boot-xlnx/tools/mkimage -A arm64 -O linux -T ramdisk -C gzip -n "$(BOARD_DESC) initramfs" -d "$(ROOTFS_CPIO)" "$@"

$(BOOT_BIF): $(FSBL_ELF) $(PMUFW_ELF) $(BL31_ELF) $(UBOOT_ELF) $(if $(filter y,$(BOOT_BIN_INCLUDE_BITSTREAM)),$(BITSTREAM_FILE)) | $(BUILD_DIR)
	{ \
		echo 'the_ROM_image:'; \
		echo '{'; \
		echo '  [bootloader, destination_cpu=a53-0] $(FSBL_ELF)'; \
		echo '  [pmufw_image] $(PMUFW_ELF)'; \
		if [ "$(BOOT_BIN_INCLUDE_BITSTREAM)" = "y" ]; then \
			echo '  [destination_device=pl] $(BITSTREAM_FILE)'; \
		fi; \
		echo '  [destination_cpu=a53-0, exception_level=el-3, trustzone] $(BL31_ELF)'; \
		echo '  [destination_cpu=a53-0, exception_level=el-2] $(UBOOT_ELF)'; \
		echo '}'; \
	} > $@

$(BOOT_BIN): $(BOOT_BIF) $(FSBL_ELF) $(PMUFW_ELF) $(BL31_ELF) $(UBOOT_ELF) $(if $(filter y,$(BOOT_BIN_INCLUDE_BITSTREAM)),$(BITSTREAM_FILE)) | $(BUILD_DIR)
	test -n "$(VIVADO_SETTINGS)"
	source "$(VIVADO_SETTINGS)" && command -v bootgen >/dev/null && \
		bootgen -arch $(BOOTGEN_ARCH) -image "$(BOOT_BIF)" -o "$@" -w on
	printf '%s\n' "$(FSBL_BOOT_PROFILE)|$(BOOT_BIN_INCLUDE_BITSTREAM)" > "$(BOOT_PROFILE_STAMP)"

$(SD_DIR)/$(SD_BOOT_IMAGE_NAME): $(BOOT_BIN) | $(SD_DIR)
	cp $< $@

$(SD_DIR)/$(SD_KERNEL_IMAGE_NAME): $(KERNEL_IMAGE) | $(SD_DIR)
	cp $< $@

$(SD_DIR)/$(SD_DTB_NAME): $(DTB_FILE) | $(SD_DIR)
	cp $< $@

$(SD_DIR)/$(SD_RAMDISK_NAME): $(URAMDISK_FILE) | $(SD_DIR)
	cp $< $@

ifneq ($(strip $(SD_BITSTREAM_NAME)),)
$(SD_BITSTREAM_FILE): $(BITSTREAM_FILE) | $(SD_DIR)
	cp $< $@
endif

$(SD_DIR)/uEnv.txt: $(RENDERED_UENV_FILE) | $(SD_DIR)
	cp $< $@

sd: check-source-board $(SD_DIR)/$(SD_BOOT_IMAGE_NAME) $(SD_DIR)/$(SD_KERNEL_IMAGE_NAME) $(SD_DIR)/uEnv.txt $(SD_DIR)/$(SD_DTB_NAME) $(SD_DIR)/$(SD_RAMDISK_NAME) $(SD_BITSTREAM_FILE)

$(EMMC_BOOT_BIN_FILE): FORCE | $(EMMC_DIR)
	if [ "$$(cat "$(BOOT_PROFILE_STAMP)" 2>/dev/null)" != "sd|n" ]; then \
		rm -rf "$(BUILD_DIR)/sdk" "$(BOOT_BIN)" "$(BOOT_BIF)" \
			"$(FSBL_ELF)" "$(PMUFW_ELF)" "$(BSP_STAMP)"; \
	fi
	$(MAKE) BOARD="$(BOARD)" FSBL_BOOT_PROFILE=sd BOOT_BIN_INCLUDE_BITSTREAM=n "$(BOOT_BIN)"
	cp "$(BOOT_BIN)" $@

$(EMMC_DIR)/$(SD_KERNEL_IMAGE_NAME): $(KERNEL_IMAGE) | $(EMMC_DIR)
	cp $< $@

$(EMMC_DIR)/$(SD_DTB_NAME): $(DTB_FILE) | $(EMMC_DIR)
	cp $< $@

ifneq ($(strip $(SD_BITSTREAM_NAME)),)
$(EMMC_DIR)/$(SD_BITSTREAM_NAME): $(BITSTREAM_FILE) | $(EMMC_DIR)
	cp $< $@
endif

$(EMMC_DIR)/uEnv-emmc.txt: $(RENDERED_EMMC_UENV_FILE) | $(EMMC_DIR)
	cp $< $@

$(EMMC_DIR)/rootfs.ext4: $(ROOTFS_EXT4) | $(EMMC_DIR)
	cp $< $@

$(EMMC_DIR)/prepare-emmc-persistent-rootfs: $(BOARD_DIR)/buildroot/rootfs-overlay/usr/sbin/prepare-emmc-persistent-rootfs | $(EMMC_DIR)
	cp $< $@
	chmod +x $@

emmc-package: check-source-board $(EMMC_BOOT_BIN_FILE) $(EMMC_DIR)/$(SD_KERNEL_IMAGE_NAME) $(EMMC_DIR)/uEnv-emmc.txt $(EMMC_DIR)/$(SD_DTB_NAME) $(EMMC_DIR)/rootfs.ext4 $(EMMC_DIR)/prepare-emmc-persistent-rootfs $(if $(strip $(SD_BITSTREAM_NAME)),$(EMMC_DIR)/$(SD_BITSTREAM_NAME))
	rm -f $(EMMC_DIR)/uEnv.txt

$(QSPI_LAYOUT): | $(QSPI_DIR)
	printf '%s\n' \
		'Raw QSPI layout:' \
		'  $(QSPI_BOOT_OFFSET)  BOOT.BIN' \
		'  $(QSPI_IMAGE_OFFSET)  image.ub' \
		'' \
		'Adjust offsets in board/$(BOARD)/board.mk if your flash map differs.' > $@

$(QSPI_IMAGE): scripts/mkqspi_image.sh $(QSPI_BOOT_BIN_FILE) $(IMAGE_UB) | $(QSPI_DIR)
	scripts/mkqspi_image.sh "$@" "$(QSPI_TOTAL_SIZE)" "$(QSPI_BOOT_BIN_FILE)" "$(IMAGE_UB)" "$(QSPI_BOOT_OFFSET)" "$(QSPI_IMAGE_OFFSET)" "$(QSPI_IMAGE_MAX_SIZE)"

$(QSPI_BOOT_BIN_FILE): FORCE | $(QSPI_DIR)
	if [ "$$(cat "$(BOOT_PROFILE_STAMP)" 2>/dev/null)" != "qspi|y" ]; then \
		rm -rf "$(BUILD_DIR)/sdk" "$(BOOT_BIN)" "$(BOOT_BIF)" \
			"$(FSBL_ELF)" "$(PMUFW_ELF)" "$(BSP_STAMP)"; \
	fi
	$(MAKE) BOARD="$(BOARD)" FSBL_BOOT_PROFILE=qspi BOOT_BIN_INCLUDE_BITSTREAM=y "$(BOOT_BIN)"
	cp "$(BOOT_BIN)" $@

$(QSPI_IMAGE_UB_FILE): $(IMAGE_UB) | $(QSPI_DIR)
	cp $< $@

qspi: check-source-board $(QSPI_IMAGE) $(QSPI_BOOT_BIN_FILE) $(QSPI_IMAGE_UB_FILE) $(QSPI_LAYOUT)

kernel: check-source-board $(KERNEL_IMAGE)
u-boot: check-source-board $(UBOOT_ELF)
fsbl: check-source-board $(FSBL_ELF)
pmufw: check-source-board $(PMUFW_ELF)
atf: check-source-board $(BL31_ELF)
dt: check-source-board $(DTB_FILE)
imageub: check-source-board $(IMAGE_UB)
bootbin: check-source-board $(BOOT_BIN)
rootfs: check-source-board $(ROOTFS_CPIO)
rootfs-ext4: check-source-board $(ROOTFS_EXT4)
ramdisk: check-source-board $(URAMDISK_FILE)

$(BUILD_DIR):
	mkdir -p $@

$(DT_DIR):
	mkdir -p $@

$(SD_DIR):
	mkdir -p $@

$(EMMC_DIR):
	mkdir -p $@

$(QSPI_DIR):
	mkdir -p $@

$(STAMP_DIR):
	mkdir -p $@

$(SOURCE_STAMP_DIR):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR) $(BUILDROOT_O)
	if [ -d linux-xlnx ]; then $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C linux-xlnx mrproper || true; fi
	if [ -d u-boot-xlnx ]; then $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C u-boot-xlnx distclean || true; fi
	if [ -d arm-trusted-firmware ]; then $(SUBMAKE_ENV) $(MAKE) MAKEOVERRIDES= -C arm-trusted-firmware clean || true; fi

distclean: clean
	rm -rf buildroot-xilinx linux-xlnx u-boot-xlnx arm-trusted-firmware embeddedsw device-tree-xlnx $(SOURCE_STAMP_DIR)
