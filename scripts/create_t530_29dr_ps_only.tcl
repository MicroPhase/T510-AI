# Vivado batch script to create a minimal ANTSDR T530 PS-only hardware project.
#
# Default target:
#   - Device: XCZU29DR-FFVF1760-2-I
#   - PS peripherals: UART1 on MIO40..41, SD1 on MIO45..51
#   - PS DDR: DDR4, 64-bit, 4 x MT40A512M16LY-class x16 components
#   - DDR bring-up profile: 800 MT/s device-side rate by default
#
# Usage:
#   /opt/Xilinx/Vivado/2022.2/bin/vivado -mode batch \
#     -source scripts/create_t530_29dr_ps_only.tcl
#
# Useful overrides:
#   T530_PROJECT_DIR=/path/to/project
#   T530_PROJECT_NAME=t530_29dr_ps_only
#   T530_PART=xczu29dr-ffvf1760-2-i
#   T530_DDR_FREQ_MHZ=800
#   T530_DDR_CL=11
#   T530_DDR_CWL=9

proc env_or_default {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default_value
}

proc ddr_profile {freq_mhz} {
    switch -exact -- $freq_mhz {
        600 {
            return [dict create \
                cl 9 cwl 9 trcd 15.00 trp 15.00 tras 35.00 trc 50.00 tfaw 30.00 \
                speed_bin DDR4_2400P]
        }
        800 {
            return [dict create \
                cl 12 cwl 9 trcd 15.00 trp 15.00 tras 35.00 trc 50.00 tfaw 30.00 \
                speed_bin DDR4_2400P]
        }
        1200 {
            return [dict create \
                cl 15 cwl 12 trcd 15.00 trp 15.00 tras 32.00 trc 44.50 tfaw 30.00 \
                speed_bin DDR4_2400P]
        }
        default {
            puts "WARNING: no built-in DDR timing profile for T530_DDR_FREQ_MHZ=$freq_mhz; using 800 MT/s conservative timings."
            return [dict create \
                cl 12 cwl 9 trcd 15.00 trp 15.00 tras 35.00 trc 50.00 tfaw 30.00 \
                speed_bin DDR4_2400P]
        }
    }
}

set repo_root [file normalize [file join [file dirname [info script]] ..]]
set project_name [env_or_default T530_PROJECT_NAME t530_29dr_ps_only]
set project_dir [file normalize [env_or_default T530_PROJECT_DIR [file join $repo_root hdl $project_name]]]
set part_name [env_or_default T530_PART xczu29dr-ffvf1760-2-i]
set bd_name [env_or_default T530_BD_NAME design_1]
set ddr_freq_mhz [env_or_default T530_DDR_FREQ_MHZ 800]
set ddr_iface_mhz [format "%.3f" [expr {double($ddr_freq_mhz) / 2.0}]]
set profile [ddr_profile $ddr_freq_mhz]

set ddr_cl [env_or_default T530_DDR_CL [dict get $profile cl]]
set ddr_cwl [env_or_default T530_DDR_CWL [dict get $profile cwl]]
set ddr_trcd [env_or_default T530_DDR_T_RCD [dict get $profile trcd]]
set ddr_trp [env_or_default T530_DDR_T_RP [dict get $profile trp]]
set ddr_tras [env_or_default T530_DDR_T_RAS_MIN [dict get $profile tras]]
set ddr_trc [env_or_default T530_DDR_T_RC [dict get $profile trc]]
set ddr_tfaw [env_or_default T530_DDR_T_FAW [dict get $profile tfaw]]
set ddr_speed_bin [env_or_default T530_DDR_SPEED_BIN [dict get $profile speed_bin]]

puts "Creating T530 PS-only project"
puts "  Project:          $project_dir/$project_name.xpr"
puts "  Part:             $part_name"
puts "  DDR device freq:  $ddr_freq_mhz MHz"
puts "  DDR iface freq:   $ddr_iface_mhz MHz"
puts "  DDR timing:       CL=$ddr_cl CWL=$ddr_cwl tRCD=$ddr_trcd tRP=$ddr_trp tRAS=$ddr_tras tRC=$ddr_trc"

file mkdir $project_dir
create_project $project_name $project_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

create_bd_design $bd_name
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ultra_ps_e_0]

set_property -dict [list \
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.3333333333} \
    CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU__UART0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 40 .. 41} \
    CONFIG.PSU__UART1__BAUD_RATE {115200} \
    CONFIG.PSU__UART1__MODEM__ENABLE {0} \
    CONFIG.PSU__UART0_LOOP_UART1__ENABLE {0} \
    CONFIG.PSU__SD0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__SD1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SD1__PERIPHERAL__IO {MIO 46 .. 51} \
    CONFIG.PSU__SD1__GRP_CD__ENABLE {1} \
    CONFIG.PSU__SD1__GRP_CD__IO {MIO 45} \
    CONFIG.PSU__SD1__GRP_POW__ENABLE {0} \
    CONFIG.PSU__SD1__GRP_WP__ENABLE {0} \
    CONFIG.PSU__SD1__SLOT_TYPE {SD 2.0} \
    CONFIG.PSU__SD1__DATA_TRANSFER_MODE {4Bit} \
    CONFIG.PSU__SD1__CLK_50_SDR_ITAP_DLY {0x15} \
    CONFIG.PSU__SD1__CLK_50_SDR_OTAP_DLY {0x5} \
    CONFIG.PSU__SD1_ROUTE_THROUGH_FPD {0} \
    CONFIG.PSU__SD1_COHERENCY {0} \
] $ps

set_property -dict [list \
    CONFIG.PSU__DDRC__ENABLE {1} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ $ddr_freq_mhz \
    CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ $ddr_iface_mhz \
    CONFIG.PSU__ACT_DDR_FREQ_MHZ $ddr_freq_mhz \
    CONFIG.PSU__DDR__INTERFACE__FREQMHZ $ddr_iface_mhz \
    CONFIG.PSU__DDRC__MEMORY_TYPE {DDR 4} \
    CONFIG.PSU__DDRC__COMPONENTS {Components} \
    CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} \
    CONFIG.PSU__DDRC__DRAM_WIDTH {16 Bits} \
    CONFIG.PSU__DDRC__DEVICE_CAPACITY {8192 MBits} \
    CONFIG.PSU__DDRC__RANK_ADDR_COUNT {0} \
    CONFIG.PSU__DDRC__BG_ADDR_COUNT {1} \
    CONFIG.PSU__DDRC__ROW_ADDR_COUNT {16} \
    CONFIG.PSU__DDRC__BRC_MAPPING {ROW_BANK_COL} \
    CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {1} \
    CONFIG.PSU__DDRC__DM_DBI {DM_NO_DBI} \
    CONFIG.PSU__DDRC__ECC {Disabled} \
    CONFIG.PSU__DDRC__ECC_SCRUB {0} \
    CONFIG.PSU__DDRC__SPEED_BIN $ddr_speed_bin \
    CONFIG.PSU__DDRC__CL $ddr_cl \
    CONFIG.PSU__DDRC__CWL $ddr_cwl \
    CONFIG.PSU__DDRC__T_RCD $ddr_trcd \
    CONFIG.PSU__DDRC__T_RP $ddr_trp \
    CONFIG.PSU__DDRC__T_RAS_MIN $ddr_tras \
    CONFIG.PSU__DDRC__T_RC $ddr_trc \
    CONFIG.PSU__DDRC__T_FAW $ddr_tfaw \
    CONFIG.PSU__DDRC__VREF {1} \
    CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
    CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
    CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
    CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_MODE {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_RANGE {Normal (0-85)} \
    CONFIG.PSU__DDRC__PHY_DBI_MODE {0} \
    CONFIG.PSU__DDRC__PARITY_ENABLE {0} \
    CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE {0} \
    CONFIG.PSU__DDRC__DDR4_CRC_CONTROL {0} \
    CONFIG.PSU__DDRC__PER_BANK_REFRESH {0} \
    CONFIG.PSU__DDRC__FGRM {1X} \
    CONFIG.PSU__DDRC__LP_ASR {manual normal} \
    CONFIG.PSU__DDRC__STATIC_RD_MODE {0} \
    CONFIG.PSU__DDRC__SELF_REF_ABORT {0} \
    CONFIG.PSU__DDRC__PWR_DOWN_EN {0} \
    CONFIG.PSU__DDRC__PLL_BYPASS {0} \
    CONFIG.PSU__DDRC__EN_2ND_CLK {0} \
    CONFIG.PSU__DDRC__ENABLE_2T_TIMING {0} \
    CONFIG.PSU__DDRC__RD_DQS_CENTER {0} \
] $ps

set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP0 {0} \
    CONFIG.PSU__USE__S_AXI_GP1 {0} \
    CONFIG.PSU__USE__S_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP3 {0} \
    CONFIG.PSU__USE__S_AXI_GP4 {0} \
    CONFIG.PSU__USE__S_AXI_GP5 {0} \
    CONFIG.PSU__USE__S_AXI_GP6 {0} \
    CONFIG.PSU__USE__CLK0 {0} \
    CONFIG.PSU__USE__CLK1 {0} \
    CONFIG.PSU__USE__CLK2 {0} \
    CONFIG.PSU__USE__CLK3 {0} \
] $ps

validate_bd_design
save_bd_design

set bd_file [get_files [file join $project_dir ${project_name}.srcs sources_1 bd $bd_name ${bd_name}.bd]]
generate_target all $bd_file
export_ip_user_files -of_objects $bd_file -no_script -sync -force -quiet

set wrapper_files [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_files
update_compile_order -fileset sources_1

set xsa_file [file join $project_dir ${bd_name}_wrapper.xsa]
if {[catch {write_hw_platform -fixed -force -file $xsa_file} hw_err]} {
    puts "WARNING: write_hw_platform failed: $hw_err"
    puts "         The Vivado project and psu_init.tcl were still generated."
} else {
    puts "Generated XSA: $xsa_file"
}

set psu_init_tcl [file join $project_dir ${project_name}.gen sources_1 bd $bd_name ip ${bd_name}_zynq_ultra_ps_e_0_0 psu_init.tcl]
puts "Generated psu_init.tcl: $psu_init_tcl"
puts "Diagnostic example:"
puts "  T530_PSU_INIT_TCL=$psu_init_tcl /opt/Xilinx/Vitis/2022.2/bin/xsct scripts/t530_ps_ddr_diag.tcl"

close_project
