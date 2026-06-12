BOARD_NAME := t510-ai
BOARD_DESC := T510 AI Zynq UltraScale+ RFSoC firmware builder

HW_PROJECT_DIR := $(CURDIR)/hdl/t510_ai
HW_FILE := $(HW_PROJECT_DIR)/artifacts/t510_ai_100g_full_system/t510_ai_100g_full_system_top.xsa
HW_BIT := $(HW_PROJECT_DIR)/artifacts/t510_ai_100g_full_system/t510_ai_100g_full_system_top.bit
BOOT_BIN_INCLUDE_BITSTREAM := n
SD_BITSTREAM_NAME := t510_ai_100g_full_system_top.bit
FSBL_BOOT_PROFILE := sd
PMUFW_ENABLE_EFUSE_ACCESS := 1

LINUX_DEFCONFIG := xilinx_zynqmp_defconfig
UBOOT_DEFCONFIG := xilinx_zynqmp_virt_defconfig
UBOOT_DTS_NAME := zynqmp-t510-ai

BOOTGEN_ARCH := zynqmp
CONSOLE_UART := 1
CROSS_COMPILE := /opt/Xilinx/Vitis/2022.2/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-
ATF_CROSS_COMPILE := /opt/Xilinx/Vitis/2022.2/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-
