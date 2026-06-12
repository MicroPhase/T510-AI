
################################################################
# This is a generated script based on design: x440_100g_ps_bd
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

set scripts_vivado_version 2022.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was prepared for Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version>."}
   return 1
}

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu47dr-ffve1156-2-i
}

variable design_name
set design_name x440_100g_ps_bd

set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1
} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."
} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2
} else {
   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."
   create_bd_design $design_name
   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name
}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:usp_rf_data_converter:2.6\
xilinx.com:ip:zynq_ultra_ps_e:3.4\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:xlconcat:2.1\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

source [file normalize [file join $script_folder create_x440_100g_ps_bd_exported_from_current.tcl]]

set ps [get_bd_cells -quiet ps]
if { $ps eq "" } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2101 -severity "ERROR" "Unable to find BD cell <ps> after sourcing base PS BD script."}
   return 4
}

# Apply the ANTSDR T510 PS preset to DDR/MIO/peripheral configuration,
# then re-apply the X440 100G-specific PL interface settings used by this design.
set_property -dict [list \
  CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} \
  CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
  CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
  CONFIG.PSU_DDR_RAM_HIGHADDR {0xFFFFFFFF} \
  CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} \
  CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
  CONFIG.PSU_MIO_1_DRIVE_STRENGTH {12} \
  CONFIG.PSU_MIO_1_SLEW {fast} \
  CONFIG.PSU_MIO_24_POLARITY {Default} \
  CONFIG.PSU_MIO_25_POLARITY {Default} \
  CONFIG.PSU_MIO_26_POLARITY {Default} \
  CONFIG.PSU_MIO_27_POLARITY {Default} \
  CONFIG.PSU_MIO_28_POLARITY {Default} \
  CONFIG.PSU_MIO_29_POLARITY {Default} \
  CONFIG.PSU_MIO_30_POLARITY {Default} \
  CONFIG.PSU_MIO_31_POLARITY {Default} \
  CONFIG.PSU_MIO_33_POLARITY {Default} \
  CONFIG.PSU_MIO_34_POLARITY {Default} \
  CONFIG.PSU_MIO_38_DRIVE_STRENGTH {12} \
  CONFIG.PSU_MIO_38_POLARITY {Default} \
  CONFIG.PSU_MIO_38_SLEW {fast} \
  CONFIG.PSU_MIO_39_INPUT_TYPE {cmos} \
  CONFIG.PSU_MIO_39_POLARITY {Default} \
  CONFIG.PSU_MIO_42_POLARITY {Default} \
  CONFIG.PSU_MIO_44_POLARITY {Default} \
  CONFIG.PSU_MIO_4_INPUT_TYPE {cmos} \
  CONFIG.PSU_MIO_6_POLARITY {Default} \
  CONFIG.PSU_MIO_TREE_PERIPHERALS {Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#GPIO0 MIO#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#GPIO0 MIO#GPIO0 MIO#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#SPI 1#GPIO1 MIO#GPIO1 MIO#SPI 1#SPI 1#SPI 1#GPIO1 MIO#GPIO1 MIO#UART 1#UART 1#GPIO1 MIO#USB0 Reset#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#MDIO 3#MDIO 3} \
  CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#miso_mo1#mo2#mo3#mosi_mi0#n_ss_out#gpio0[6]#n_ss_out_upper#mo_upper[0]#mo_upper[1]#mo_upper[2]#mo_upper[3]#sclk_out_upper#sdio0_data_out[0]#sdio0_data_out[1]#sdio0_data_out[2]#sdio0_data_out[3]#sdio0_data_out[4]#sdio0_data_out[5]#sdio0_data_out[6]#sdio0_data_out[7]#sdio0_cmd_out#sdio0_clk_out#sdio0_bus_pow#gpio0[24]#gpio0[25]#gpio1[26]#gpio1[27]#gpio1[28]#gpio1[29]#gpio1[30]#gpio1[31]#sclk_out#gpio1[33]#gpio1[34]#n_ss_out[0]#miso#mosi#gpio1[38]#gpio1[39]#txd#rxd#gpio1[42]#reset#gpio1[44]#sdio1_cd_n#sdio1_data_out[0]#sdio1_data_out[1]#sdio1_data_out[2]#sdio1_data_out[3]#sdio1_cmd_out#sdio1_clk_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem3_mdc#gem3_mdio_out} \
  CONFIG.PSU_SD0_INTERNAL_BUS_WIDTH {8} \
  CONFIG.PSU_SD1_INTERNAL_BUS_WIDTH {4} \
  CONFIG.PSU_USB3__DUAL_CLOCK_ENABLE {1} \
  CONFIG.PSU__ACT_DDR_FREQ_MHZ {1199.988037} \
  CONFIG.PSU__AFI0_COHERENCY {0} \
  CONFIG.PSU__AFI1_COHERENCY {0} \
  CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1333.320068} \
  CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {249.997498} \
  CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ {249.997498} \
  CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {599.994019} \
  CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1200} \
  CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
  CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {599.994019} \
  CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {599.994019} \
  CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {99.999001} \
  CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {533.328003} \
  CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {499.994995} \
  CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {49.999500} \
  CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {499.994995} \
  CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {249.997498} \
  CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ {1499.984985} \
  CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__ACT_FREQMHZ {124.998749} \
  CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {124.998749} \
  CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {249.997498} \
  CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} \
  CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ {99.999001} \
  CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {249.997498} \
  CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {99.999001} \
  CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {499.994995} \
  CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {187.498123} \
  CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {299.997009} \
  CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ {199.998001} \
  CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {199.998001} \
  CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ {199.998001} \
  CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {33.333000} \
  CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ {99.999001} \
  CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {99.999001} \
  CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {249.997498} \
  CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {19.999800} \
  CONFIG.PSU__DDRC__BG_ADDR_COUNT {1} \
  CONFIG.PSU__DDRC__BRC_MAPPING {ROW_BANK_COL} \
  CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} \
  CONFIG.PSU__DDRC__CL {15} \
  CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
  CONFIG.PSU__DDRC__COMPONENTS {Components} \
  CONFIG.PSU__DDRC__CWL {12} \
  CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0} \
  CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE {0} \
  CONFIG.PSU__DDRC__DDR4_CRC_CONTROL {0} \
  CONFIG.PSU__DDRC__DDR4_T_REF_MODE {0} \
  CONFIG.PSU__DDRC__DDR4_T_REF_RANGE {Normal (0-85)} \
  CONFIG.PSU__DDRC__DEVICE_CAPACITY {8192 MBits} \
  CONFIG.PSU__DDRC__DM_DBI {DM_NO_DBI} \
  CONFIG.PSU__DDRC__DRAM_WIDTH {16 Bits} \
  CONFIG.PSU__DDRC__ECC {Disabled} \
  CONFIG.PSU__DDRC__ENABLE {1} \
  CONFIG.PSU__DDRC__FGRM {1X} \
  CONFIG.PSU__DDRC__LP_ASR {manual normal} \
  CONFIG.PSU__DDRC__MEMORY_TYPE {DDR 4} \
  CONFIG.PSU__DDRC__PARITY_ENABLE {0} \
  CONFIG.PSU__DDRC__PER_BANK_REFRESH {0} \
  CONFIG.PSU__DDRC__PHY_DBI_MODE {0} \
  CONFIG.PSU__DDRC__RANK_ADDR_COUNT {0} \
  CONFIG.PSU__DDRC__ROW_ADDR_COUNT {16} \
  CONFIG.PSU__DDRC__SELF_REF_ABORT {0} \
  CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2400P} \
  CONFIG.PSU__DDRC__STATIC_RD_MODE {0} \
  CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
  CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
  CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
  CONFIG.PSU__DDRC__T_FAW {30.0} \
  CONFIG.PSU__DDRC__T_RAS_MIN {32.0} \
  CONFIG.PSU__DDRC__T_RC {44.5} \
  CONFIG.PSU__DDRC__T_RCD {15} \
  CONFIG.PSU__DDRC__T_RP {15} \
  CONFIG.PSU__DDRC__VREF {1} \
  CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {1} \
  CONFIG.PSU__DDR__INTERFACE__FREQMHZ {600.000} \
  CONFIG.PSU__DLL__ISUSED {1} \
  CONFIG.PSU__ENET0__PERIPHERAL__ENABLE {0} \
  CONFIG.PSU__ENET3__FIFO__ENABLE {0} \
  CONFIG.PSU__ENET3__GRP_MDIO__ENABLE {1} \
  CONFIG.PSU__ENET3__GRP_MDIO__IO {MIO 76 .. 77} \
  CONFIG.PSU__ENET3__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__ENET3__PERIPHERAL__IO {MIO 64 .. 75} \
  CONFIG.PSU__ENET3__PTP__ENABLE {0} \
  CONFIG.PSU__ENET3__TSU__ENABLE {0} \
  CONFIG.PSU__GEM3_COHERENCY {0} \
  CONFIG.PSU__GEM3_ROUTE_THROUGH_FPD {0} \
  CONFIG.PSU__GEM__TSU__ENABLE {0} \
  CONFIG.PSU__GPIO0_MIO__IO {MIO 0 .. 25} \
  CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__GPIO1_MIO__IO {MIO 26 .. 51} \
  CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__GPIO2_MIO__IO {MIO 52 .. 77} \
  CONFIG.PSU__GPIO2_MIO__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__GPIO_EMIO_WIDTH {95} \
  CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {95} \
  CONFIG.PSU__I2C0__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__I2C0__PERIPHERAL__IO {EMIO} \
  CONFIG.PSU__I2C1__PERIPHERAL__ENABLE {0} \
  CONFIG.PSU__PL_CLK1_BUF {TRUE} \
  CONFIG.PSU__QSPI_COHERENCY {0} \
  CONFIG.PSU__QSPI_ROUTE_THROUGH_FPD {0} \
  CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE {0} \
  CONFIG.PSU__QSPI__PERIPHERAL__DATA_MODE {x4} \
  CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__QSPI__PERIPHERAL__IO {MIO 0 .. 12} \
  CONFIG.PSU__QSPI__PERIPHERAL__MODE {Dual Parallel} \
  CONFIG.PSU__SAXIGP0__DATA_WIDTH {128} \
  CONFIG.PSU__SAXIGP1__DATA_WIDTH {128} \
  CONFIG.PSU__SD0_COHERENCY {0} \
  CONFIG.PSU__SD0_ROUTE_THROUGH_FPD {0} \
  CONFIG.PSU__SD0__CLK_200_SDR_OTAP_DLY {0x3} \
  CONFIG.PSU__SD0__CLK_50_DDR_ITAP_DLY {0x12} \
  CONFIG.PSU__SD0__CLK_50_DDR_OTAP_DLY {0x6} \
  CONFIG.PSU__SD0__CLK_50_SDR_ITAP_DLY {0x15} \
  CONFIG.PSU__SD0__CLK_50_SDR_OTAP_DLY {0x6} \
  CONFIG.PSU__SD0__DATA_TRANSFER_MODE {8Bit} \
  CONFIG.PSU__SD0__GRP_POW__ENABLE {1} \
  CONFIG.PSU__SD0__GRP_POW__IO {MIO 23} \
  CONFIG.PSU__SD0__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__SD0__PERIPHERAL__IO {MIO 13 .. 22} \
  CONFIG.PSU__SD0__RESET__ENABLE {1} \
  CONFIG.PSU__SD0__SLOT_TYPE {eMMC} \
  CONFIG.PSU__SD1_COHERENCY {0} \
  CONFIG.PSU__SD1_ROUTE_THROUGH_FPD {0} \
  CONFIG.PSU__SD1__CLK_50_SDR_ITAP_DLY {0x15} \
  CONFIG.PSU__SD1__CLK_50_SDR_OTAP_DLY {0x5} \
  CONFIG.PSU__SD1__DATA_TRANSFER_MODE {4Bit} \
  CONFIG.PSU__SD1__GRP_CD__ENABLE {1} \
  CONFIG.PSU__SD1__GRP_CD__IO {MIO 45} \
  CONFIG.PSU__SD1__GRP_POW__ENABLE {0} \
  CONFIG.PSU__SD1__GRP_WP__ENABLE {0} \
  CONFIG.PSU__SD1__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__SD1__PERIPHERAL__IO {MIO 46 .. 51} \
  CONFIG.PSU__SD1__SLOT_TYPE {SD 2.0} \
  CONFIG.PSU__SPI1__GRP_SS0__IO {MIO 35} \
  CONFIG.PSU__SPI1__GRP_SS1__ENABLE {0} \
  CONFIG.PSU__SPI1__GRP_SS2__ENABLE {0} \
  CONFIG.PSU__SPI1__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__SPI1__PERIPHERAL__IO {MIO 32 .. 37} \
  CONFIG.PSU__TSU__BUFG_PORT_PAIR {0} \
  CONFIG.PSU__UART0__BAUD_RATE {115200} \
  CONFIG.PSU__UART0__MODEM__ENABLE {0} \
  CONFIG.PSU__UART0__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__UART0__PERIPHERAL__IO {EMIO} \
  CONFIG.PSU__UART1__BAUD_RATE {115200} \
  CONFIG.PSU__UART1__MODEM__ENABLE {0} \
  CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 40 .. 41} \
  CONFIG.PSU__USB0_COHERENCY {0} \
  CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} \
  CONFIG.PSU__USB0__RESET__ENABLE {1} \
  CONFIG.PSU__USB0__RESET__IO {MIO 43} \
  CONFIG.PSU__USB1__RESET__ENABLE {0} \
  CONFIG.PSU__USB2_0__EMIO__ENABLE {0} \
  CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {0} \
  CONFIG.PSU__USB__RESET__MODE {Separate MIO Pin} \
  CONFIG.PSU__USB__RESET__POLARITY {Active Low} \
  CONFIG.PSU__USE__S_AXI_GP0 {1} \
  CONFIG.PSU__USE__S_AXI_GP1 {1} \
  CONFIG.PSU__USE__S_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP3 {0} \
  CONFIG.SUBPRESET1 {Custom} \
] $ps

set_property -dict [list \
  CONFIG.PSU__FPGA_PL0_ENABLE {1} \
  CONFIG.PSU__FPGA_PL1_ENABLE {1} \
  CONFIG.PSU__FPGA_PL3_ENABLE {1} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
  CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {40} \
  CONFIG.PSU__CRL_APB__PL3_REF_CTRL__FREQMHZ {200} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {100.000000} \
  CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ {40.000000} \
  CONFIG.PSU__CRL_APB__PL3_REF_CTRL__ACT_FREQMHZ {200.000000} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR0 {10} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR1 {1} \
  CONFIG.PSU__CRL_APB__PL1_REF_CTRL__DIVISOR0 {25} \
  CONFIG.PSU__CRL_APB__PL1_REF_CTRL__DIVISOR1 {1} \
  CONFIG.PSU__CRL_APB__PL3_REF_CTRL__DIVISOR0 {5} \
  CONFIG.PSU__CRL_APB__PL3_REF_CTRL__DIVISOR1 {1} \
  CONFIG.PSU__USE__FABRIC__RST {1} \
  CONFIG.PSU__NUM_FABRIC_RESETS {1} \
  CONFIG.PSU__USE__IRQ0 {1} \
  CONFIG.PSU__USE__M_AXI_GP0 {1} \
  CONFIG.PSU__USE__M_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP0 {0} \
  CONFIG.PSU__USE__S_AXI_GP1 {1} \
  CONFIG.PSU__MAXIGP0__DATA_WIDTH {32} \
  CONFIG.PSU__SAXIGP1__DATA_WIDTH {128} \
  CONFIG.PSU__PL_CLK0_BUF {TRUE} \
  CONFIG.PSU__PL_CLK1_BUF {TRUE} \
  CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;1|S_AXI_HPC0_FPD:NA;1|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;0|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} \
] $ps

set ps_axi_periph [get_bd_cells -quiet ps_axi_periph]
set rst_ps_96M    [get_bd_cells -quiet rst_ps_96M]
if { $ps_axi_periph eq "" || $rst_ps_96M eq "" } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2102 -severity "ERROR" "Unable to find ps_axi_periph or rst_ps_96M in the imported PS BD."}
   return 5
}

set_property -dict [list CONFIG.NUM_MI {3}] $ps_axi_periph

set adc_clk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 adc_clk]
set_property -dict [list CONFIG.FREQ_HZ {250000000.0}] $adc_clk

set dac_clk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac_clk]
set_property -dict [list CONFIG.FREQ_HZ {250000000.0}] $dac_clk

set sysref_in [create_bd_intf_port -mode Slave -vlnv xilinx.com:display_usp_rf_data_converter:diff_pins_rtl:1.0 sysref_in]

set m_adc_i0 [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_adc_i0]
set m_adc_q0 [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_adc_q0]
set m_adc_i1 [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_adc_i1]
set m_adc_q1 [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_adc_q1]

set s_dac_ch0 [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_dac_ch0]
set_property -dict [list \
  CONFIG.HAS_TKEEP {0} \
  CONFIG.HAS_TLAST {0} \
  CONFIG.HAS_TREADY {1} \
  CONFIG.HAS_TSTRB {0} \
  CONFIG.LAYERED_METADATA {undef} \
  CONFIG.TDATA_NUM_BYTES {4} \
  CONFIG.TDEST_WIDTH {0} \
  CONFIG.TID_WIDTH {0} \
  CONFIG.TUSER_WIDTH {0} \
] $s_dac_ch0

set s_dac_ch1 [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_dac_ch1]
set_property -dict [list \
  CONFIG.HAS_TKEEP {0} \
  CONFIG.HAS_TLAST {0} \
  CONFIG.HAS_TREADY {1} \
  CONFIG.HAS_TSTRB {0} \
  CONFIG.LAYERED_METADATA {undef} \
  CONFIG.TDATA_NUM_BYTES {4} \
  CONFIG.TDEST_WIDTH {0} \
  CONFIG.TID_WIDTH {0} \
  CONFIG.TUSER_WIDTH {0} \
] $s_dac_ch1

set rx_ch0 [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 rx_ch0]
set rx_ch1 [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 rx_ch1]
set tx_ch0 [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 tx_ch0]
set tx_ch1 [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 tx_ch1]

set radio_rx_clk [create_bd_port -dir I -type clk -freq_hz 245760000 radio_rx_clk]
set radio_tx_clk [create_bd_port -dir I -type clk -freq_hz 245760000 radio_tx_clk]
set user_sysref_adc [create_bd_port -dir I user_sysref_adc]
set user_sysref_dac [create_bd_port -dir I user_sysref_dac]
# Export PS EMIO GPIO explicitly so the top-level can keep using gpio_i/o/t.
set gpio_i [create_bd_port -dir I -from 94 -to 0 gpio_i]
set gpio_o [create_bd_port -dir O -from 94 -to 0 gpio_o]
set gpio_t [create_bd_port -dir O -from 94 -to 0 gpio_t]

set usp_rf_data_converter_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 usp_rf_data_converter_0]
set_property -dict [list \
  CONFIG.ADC0_Clock_Dist {2} \
  CONFIG.ADC0_Multi_Tile_Sync {true} \
  CONFIG.ADC0_Outclk_Freq {38.400} \
  CONFIG.ADC0_PLL_Enable {true} \
  CONFIG.ADC0_Refclk_Div {1} \
  CONFIG.ADC0_Refclk_Freq {245.760} \
  CONFIG.ADC0_Sampling_Rate {4.9152} \
  CONFIG.ADC_CalOpt_Mode00 {2} \
  CONFIG.ADC_CalOpt_Mode02 {2} \
  CONFIG.ADC_Data_Type00 {1} \
  CONFIG.ADC_Data_Type02 {1} \
  CONFIG.ADC_Data_Width00 {1} \
  CONFIG.ADC_Data_Width02 {1} \
  CONFIG.ADC_Decimation_Mode00 {20} \
  CONFIG.ADC_Decimation_Mode02 {20} \
  CONFIG.ADC_Mixer_Mode00 {0} \
  CONFIG.ADC_Mixer_Type00 {2} \
  CONFIG.ADC_Mixer_Type02 {2} \
  CONFIG.ADC_NCO_Freq00 {1.0} \
  CONFIG.ADC_NCO_Freq02 {1.0} \
  CONFIG.ADC_Slice02_Enable {true} \
  CONFIG.DAC0_Band {0} \
  CONFIG.DAC0_Multi_Tile_Sync {true} \
  CONFIG.DAC0_PLL_Enable {true} \
  CONFIG.DAC0_Refclk_Freq {245.760} \
  CONFIG.DAC0_Sampling_Rate {4.9152} \
  CONFIG.DAC_Data_Type00 {0} \
  CONFIG.DAC_Data_Width00 {2} \
  CONFIG.DAC_Data_Width02 {2} \
  CONFIG.DAC_Interpolation_Mode00 {20} \
  CONFIG.DAC_Interpolation_Mode02 {20} \
  CONFIG.DAC_Mixer_Mode00 {0} \
  CONFIG.DAC_Mixer_Mode02 {0} \
  CONFIG.DAC_Mixer_Type00 {2} \
  CONFIG.DAC_Mixer_Type02 {2} \
  CONFIG.DAC_NCO_Freq00 {1.0} \
  CONFIG.DAC_NCO_Freq02 {1.0} \
  CONFIG.DAC_Slice00_Enable {true} \
  CONFIG.DAC_Slice02_Enable {true} \
] $usp_rf_data_converter_0

connect_bd_intf_net [get_bd_intf_ports adc_clk] [get_bd_intf_pins usp_rf_data_converter_0/adc0_clk]
connect_bd_intf_net [get_bd_intf_ports dac_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac0_clk]
connect_bd_intf_net [get_bd_intf_ports sysref_in] [get_bd_intf_pins usp_rf_data_converter_0/sysref_in]
connect_bd_intf_net [get_bd_intf_pins ps_axi_periph/M02_AXI] [get_bd_intf_pins usp_rf_data_converter_0/s_axi]
connect_bd_intf_net [get_bd_intf_ports s_dac_ch0] [get_bd_intf_pins usp_rf_data_converter_0/s00_axis]
connect_bd_intf_net [get_bd_intf_ports s_dac_ch1] [get_bd_intf_pins usp_rf_data_converter_0/s02_axis]
connect_bd_intf_net [get_bd_intf_ports m_adc_i0] [get_bd_intf_pins usp_rf_data_converter_0/m00_axis]
connect_bd_intf_net [get_bd_intf_ports m_adc_q0] [get_bd_intf_pins usp_rf_data_converter_0/m01_axis]
connect_bd_intf_net [get_bd_intf_ports m_adc_i1] [get_bd_intf_pins usp_rf_data_converter_0/m02_axis]
connect_bd_intf_net [get_bd_intf_ports m_adc_q1] [get_bd_intf_pins usp_rf_data_converter_0/m03_axis]
connect_bd_intf_net [get_bd_intf_ports tx_ch0] [get_bd_intf_pins usp_rf_data_converter_0/vout00]
connect_bd_intf_net [get_bd_intf_ports tx_ch1] [get_bd_intf_pins usp_rf_data_converter_0/vout02]
connect_bd_intf_net [get_bd_intf_ports rx_ch0] [get_bd_intf_pins usp_rf_data_converter_0/vin0_01]
connect_bd_intf_net [get_bd_intf_ports rx_ch1] [get_bd_intf_pins usp_rf_data_converter_0/vin0_23]

connect_bd_net [get_bd_ports radio_rx_clk] [get_bd_pins usp_rf_data_converter_0/m0_axis_aclk]
connect_bd_net [get_bd_ports radio_tx_clk] [get_bd_pins usp_rf_data_converter_0/s0_axis_aclk]
connect_bd_net [get_bd_pins rst_ps_96M/peripheral_aresetn] \
  [get_bd_pins ps_axi_periph/M02_ARESETN] \
  [get_bd_pins usp_rf_data_converter_0/m0_axis_aresetn] \
  [get_bd_pins usp_rf_data_converter_0/s0_axis_aresetn] \
  [get_bd_pins usp_rf_data_converter_0/s_axi_aresetn]
connect_bd_net [get_bd_ports pl_clk40] [get_bd_pins ps_axi_periph/M02_ACLK] [get_bd_pins usp_rf_data_converter_0/s_axi_aclk]
connect_bd_net [get_bd_ports user_sysref_adc] [get_bd_pins usp_rf_data_converter_0/user_sysref_adc]
connect_bd_net [get_bd_ports user_sysref_dac] [get_bd_pins usp_rf_data_converter_0/user_sysref_dac]
connect_bd_net [get_bd_ports gpio_i] [get_bd_pins ps/emio_gpio_i]
connect_bd_net [get_bd_ports gpio_o] [get_bd_pins ps/emio_gpio_o]
connect_bd_net [get_bd_ports gpio_t] [get_bd_pins ps/emio_gpio_t]

# Override the base exported map to match the RFNoC AXI-Lite window and Linux DT.
assign_bd_address -offset 0xA0000000 -range 0x00040000 \
  -target_address_space [get_bd_addr_spaces ps/Data] \
  [get_bd_addr_segs axil/Reg] -force

assign_bd_address -offset 0xA0080000 -range 0x00010000 \
  -target_address_space [get_bd_addr_spaces ps/Data] \
  [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] -force

assign_bd_address -offset 0xA0040000 -range 0x00040000 \
  -target_address_space [get_bd_addr_spaces ps/Data] \
  [get_bd_addr_segs usp_rf_data_converter_0/s_axi/Reg] -force

validate_bd_design
save_bd_design
