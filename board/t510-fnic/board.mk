BOARD_NAME := t510-fnic
BOARD_DESC := T510 FNIC Zynq UltraScale+ RFSoC firmware builder

HW_PROJECT_DIR := $(CURDIR)/hdl/t510_fnic
HW_FILE := $(HW_PROJECT_DIR)/artifacts/t510_fnic_aurora/t510_fnic_aurora_bringup_top.xsa
HW_BIT := $(HW_PROJECT_DIR)/artifacts/t510_fnic_aurora/t510_fnic_aurora_bringup_top.bit
BOOT_BIN_INCLUDE_BITSTREAM := n
SD_BOOT_IMAGE_NAME := BOOT.BIN
SD_BITSTREAM_NAME := t510_fnic_aurora_bringup_top.bit
FSBL_BOOT_PROFILE := sd

LINUX_DEFCONFIG := xilinx_zynqmp_defconfig
UBOOT_DEFCONFIG := xilinx_zynqmp_virt_defconfig
UBOOT_DTS_NAME := zynqmp-t510-fnic

BOOTGEN_ARCH := zynqmp
CONSOLE_UART := 1
CROSS_COMPILE := /opt/Xilinx/Vitis/2022.2/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-
ATF_CROSS_COMPILE := /opt/Xilinx/Vitis/2022.2/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-

# Keep enough room for a QSPI BOOT.BIN that includes the PL bitstream when
# building QSPI images with BOOT_BIN_INCLUDE_BITSTREAM=y.
QSPI_IMAGE_OFFSET := 0x01000000
