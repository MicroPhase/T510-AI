set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set proj_name  "t510_fnic_aurora"
set proj_dir   [file normalize [file join $root_dir "vivado" "project" $proj_name]]
set proj_tag   ""
set build_stamp ""
set git_sha    ""
set git_status ""
set part_name  "xczu47dr-ffve1156-2-i"

if {$argc >= 1 && [lindex $argv 0] ne ""} {
  set proj_name [lindex $argv 0]
}
if {$argc >= 2 && [lindex $argv 1] ne ""} {
  set proj_dir [file normalize [lindex $argv 1]]
}
if {$argc >= 3} {
  set proj_tag [lindex $argv 2]
}
if {$argc >= 4} {
  set build_stamp [lindex $argv 3]
}
if {$argc >= 5} {
  set git_sha [lindex $argv 4]
}
if {$argc >= 6} {
  set git_status [lindex $argv 5]
}

proc add_source_once {file_path} {
  set norm_path [file normalize $file_path]
  if {[llength [get_files -quiet $norm_path]] == 0} {
    add_files -norecurse $norm_path
  }
}

source [file join $script_dir t510_fnic_ps_preset.tcl]

proc create_t510_fnic_aurora_bd {} {
  set bd_name t510_fnic_aurora_bd

  if {[llength [get_files -quiet */${bd_name}.bd]] != 0} {
    return
  }

  create_bd_design $bd_name
  current_bd_design $bd_name

  set core_status [create_bd_intf_port -mode Master -vlnv xilinx.com:display_aurora:core_status_out_rtl:1.0 core_status]
  set gty_rx      [create_bd_intf_port -mode Slave  -vlnv xilinx.com:display_aurora:GT_Serial_Transceiver_Pins_RX_rtl:1.0 gty_rx]
  set gty_tx      [create_bd_intf_port -mode Master -vlnv xilinx.com:display_aurora:GT_Serial_Transceiver_Pins_TX_rtl:1.0 gty_tx]
  set ref_gty_clk [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:diff_clock_rtl:1.0 ref_gty_clk]
  set rx          [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 rx]
  set tx          [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0 tx]
  set adc_clk     [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:diff_clock_rtl:1.0 adc_clk]
  set dac_clk     [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac_clk]
  set sysref_in   [create_bd_intf_port -mode Slave  -vlnv xilinx.com:display_usp_rf_data_converter:diff_pins_rtl:1.0 sysref_in]
  set rx_ch0      [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 rx_ch0]
  set rx_ch1      [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 rx_ch1]
  set tx_ch0      [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 tx_ch0]
  set tx_ch1      [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 tx_ch1]
  set m_adc_i0    [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_adc_i0]
  set m_adc_q0    [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_adc_q0]
  set m_adc_i1    [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_adc_i1]
  set m_adc_q1    [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_adc_q1]
  set s_dac_ch0   [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0 s_dac_ch0]
  set s_dac_ch1   [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0 s_dac_ch1]

  set_property -dict [list CONFIG.FREQ_HZ {156250000}] $ref_gty_clk
  set_property -dict [list CONFIG.FREQ_HZ {250000000.0}] $adc_clk
  set_property -dict [list CONFIG.FREQ_HZ {250000000.0}] $dac_clk
  set_property -dict [list \
    CONFIG.FREQ_HZ {156250000} \
  ] $rx
  foreach adc_axis [list $m_adc_i0 $m_adc_q0 $m_adc_i1 $m_adc_q1] {
    set_property -dict [list CONFIG.FREQ_HZ {245760000}] $adc_axis
  }
  foreach dac_axis [list $s_dac_ch0 $s_dac_ch1] {
    set_property -dict [list \
      CONFIG.FREQ_HZ {245760000} \
      CONFIG.HAS_TKEEP {0} \
      CONFIG.HAS_TLAST {0} \
      CONFIG.HAS_TREADY {1} \
      CONFIG.HAS_TSTRB {0} \
      CONFIG.LAYERED_METADATA {undef} \
      CONFIG.TDATA_NUM_BYTES {4} \
      CONFIG.TDEST_WIDTH {0} \
      CONFIG.TID_WIDTH {0} \
      CONFIG.TUSER_WIDTH {0} \
    ] $dac_axis
  }
  set_property -dict [list \
    CONFIG.FREQ_HZ {156250000} \
    CONFIG.HAS_TKEEP {0} \
    CONFIG.HAS_TLAST {0} \
    CONFIG.HAS_TREADY {1} \
    CONFIG.HAS_TSTRB {0} \
    CONFIG.TDATA_NUM_BYTES {32} \
    CONFIG.TDEST_WIDTH {0} \
    CONFIG.TID_WIDTH {0} \
    CONFIG.TUSER_WIDTH {0} \
  ] $tx

  set init_clk [create_bd_port -dir I -type clk -freq_hz 100000000 init_clk]
  set pma_init [create_bd_port -dir I -type rst pma_init]
  set_property -dict [list CONFIG.POLARITY {ACTIVE_HIGH}] $pma_init
  set reset_pb [create_bd_port -dir I -type rst reset_pb]
  set_property -dict [list CONFIG.POLARITY {ACTIVE_HIGH}] $reset_pb

  set sys_rst  [create_bd_port -dir O -type rst sys_rst]
  set user_clk [create_bd_port -dir O -type clk user_clk]
  set pl_clk100 [create_bd_port -dir O -type clk pl_clk100]
  set pl_clk40  [create_bd_port -dir O -type clk pl_clk40]
  set pl_clk200 [create_bd_port -dir O -type clk pl_clk200]
  set pl_resetn0 [create_bd_port -dir O -type rst pl_resetn0]
  set_property -dict [list CONFIG.POLARITY {ACTIVE_LOW}] $pl_resetn0

  set gpio_i [create_bd_port -dir I -from 94 -to 0 gpio_i]
  set gpio_o [create_bd_port -dir O -from 94 -to 0 gpio_o]
  set gpio_t [create_bd_port -dir O -from 94 -to 0 gpio_t]
  set radio_rx_clk [create_bd_port -dir I -type clk -freq_hz 245760000 radio_rx_clk]
  set radio_tx_clk [create_bd_port -dir I -type clk -freq_hz 245760000 radio_tx_clk]
  set user_sysref_adc [create_bd_port -dir I user_sysref_adc]
  set user_sysref_dac [create_bd_port -dir I user_sysref_dac]

  set aurora [create_bd_cell -type ip -vlnv xilinx.com:ip:aurora_64b66b:12.0 aurora_64b66b_0]
  set_property -dict [list \
    CONFIG.CHANNEL_ENABLE {X0Y4 X0Y5 X0Y6 X0Y7} \
    CONFIG.C_AURORA_LANES {4} \
    CONFIG.C_GT_LOC_2 {2} \
    CONFIG.C_GT_LOC_3 {3} \
    CONFIG.C_GT_LOC_4 {4} \
    CONFIG.C_INIT_CLK {100} \
    CONFIG.C_LINE_RATE {10} \
    CONFIG.C_REFCLK_FREQUENCY {156.25} \
    CONFIG.C_REFCLK_SOURCE {MGTREFCLK0_of_Quad_X0Y1} \
    CONFIG.C_START_LANE {X0Y4} \
    CONFIG.C_START_QUAD {Quad_X0Y1} \
    CONFIG.SupportLevel {1} \
    CONFIG.drp_mode {Disabled} \
    CONFIG.interface_mode {Streaming} \
  ] $aurora

  set zero [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero_const]
  set_property -dict [list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {3}] $zero

  set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 ps]
  apply_t510_ai_ps_preset $ps

  set ps_axi_periph [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps_axi_periph]
  set_property CONFIG.NUM_MI {1} $ps_axi_periph

  set rst_ps_40m [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps_40m]

  set rfdc [create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 usp_rf_data_converter_0]
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
  ] $rfdc

  connect_bd_intf_net [get_bd_intf_ports ref_gty_clk] [get_bd_intf_pins $aurora/GT_DIFF_REFCLK1]
  connect_bd_intf_net [get_bd_intf_ports gty_rx]      [get_bd_intf_pins $aurora/GT_SERIAL_RX]
  connect_bd_intf_net [get_bd_intf_ports gty_tx]      [get_bd_intf_pins $aurora/GT_SERIAL_TX]
  connect_bd_intf_net [get_bd_intf_ports tx]          [get_bd_intf_pins $aurora/USER_DATA_S_AXIS_TX]
  connect_bd_intf_net [get_bd_intf_ports rx]          [get_bd_intf_pins $aurora/USER_DATA_M_AXIS_RX]
  connect_bd_intf_net [get_bd_intf_ports core_status] [get_bd_intf_pins $aurora/CORE_STATUS]
  connect_bd_intf_net [get_bd_intf_ports adc_clk]     [get_bd_intf_pins $rfdc/adc0_clk]
  connect_bd_intf_net [get_bd_intf_ports dac_clk]     [get_bd_intf_pins $rfdc/dac0_clk]
  connect_bd_intf_net [get_bd_intf_ports sysref_in]   [get_bd_intf_pins $rfdc/sysref_in]
  connect_bd_intf_net [get_bd_intf_ports rx_ch0]      [get_bd_intf_pins $rfdc/vin0_01]
  connect_bd_intf_net [get_bd_intf_ports rx_ch1]      [get_bd_intf_pins $rfdc/vin0_23]
  connect_bd_intf_net [get_bd_intf_ports tx_ch0]      [get_bd_intf_pins $rfdc/vout00]
  connect_bd_intf_net [get_bd_intf_ports tx_ch1]      [get_bd_intf_pins $rfdc/vout02]
  connect_bd_intf_net [get_bd_intf_ports m_adc_i0]    [get_bd_intf_pins $rfdc/m00_axis]
  connect_bd_intf_net [get_bd_intf_ports m_adc_q0]    [get_bd_intf_pins $rfdc/m01_axis]
  connect_bd_intf_net [get_bd_intf_ports m_adc_i1]    [get_bd_intf_pins $rfdc/m02_axis]
  connect_bd_intf_net [get_bd_intf_ports m_adc_q1]    [get_bd_intf_pins $rfdc/m03_axis]
  connect_bd_intf_net [get_bd_intf_ports s_dac_ch0]   [get_bd_intf_pins $rfdc/s00_axis]
  connect_bd_intf_net [get_bd_intf_ports s_dac_ch1]   [get_bd_intf_pins $rfdc/s02_axis]
  connect_bd_intf_net [get_bd_intf_pins $ps/M_AXI_HPM0_FPD] [get_bd_intf_pins $ps_axi_periph/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins $ps_axi_periph/M00_AXI] [get_bd_intf_pins $rfdc/s_axi]

  connect_bd_net [get_bd_ports init_clk]  [get_bd_pins $aurora/init_clk]
  connect_bd_net [get_bd_ports pma_init]  [get_bd_pins $aurora/pma_init]
  connect_bd_net [get_bd_ports reset_pb]  [get_bd_pins $aurora/reset_pb]
  connect_bd_net [get_bd_ports sys_rst]   [get_bd_pins $aurora/sys_reset_out]
  connect_bd_net [get_bd_ports user_clk]  [get_bd_pins $aurora/user_clk_out]
  connect_bd_net [get_bd_pins zero_const/dout] \
    [get_bd_pins $aurora/gt_rxcdrovrden_in] \
    [get_bd_pins $aurora/loopback] \
    [get_bd_pins $aurora/power_down]
  connect_bd_net [get_bd_ports pl_clk100]  [get_bd_pins $ps/pl_clk0]
  connect_bd_net [get_bd_ports pl_clk40]   [get_bd_pins $ps/pl_clk1]
  connect_bd_net [get_bd_ports pl_clk200]  [get_bd_pins $ps/pl_clk3]
  connect_bd_net [get_bd_ports pl_resetn0] [get_bd_pins $ps/pl_resetn0]
  connect_bd_net [get_bd_ports gpio_i]     [get_bd_pins $ps/emio_gpio_i]
  connect_bd_net [get_bd_ports gpio_o]     [get_bd_pins $ps/emio_gpio_o]
  connect_bd_net [get_bd_ports gpio_t]     [get_bd_pins $ps/emio_gpio_t]
  connect_bd_net [get_bd_ports pl_clk40]   \
    [get_bd_pins $ps/maxihpm0_fpd_aclk] \
    [get_bd_pins $ps_axi_periph/ACLK] \
    [get_bd_pins $ps_axi_periph/S00_ACLK] \
    [get_bd_pins $ps_axi_periph/M00_ACLK] \
    [get_bd_pins $rst_ps_40m/slowest_sync_clk] \
    [get_bd_pins $rfdc/s_axi_aclk]
  connect_bd_net [get_bd_pins $rst_ps_40m/peripheral_aresetn] \
    [get_bd_pins $ps_axi_periph/ARESETN] \
    [get_bd_pins $ps_axi_periph/S00_ARESETN] \
    [get_bd_pins $ps_axi_periph/M00_ARESETN] \
    [get_bd_pins $rfdc/s_axi_aresetn]
  connect_bd_net [get_bd_ports pl_resetn0] [get_bd_pins $rst_ps_40m/ext_reset_in]
  connect_bd_net [get_bd_ports radio_rx_clk] [get_bd_pins $rfdc/m0_axis_aclk]
  connect_bd_net [get_bd_ports radio_tx_clk] [get_bd_pins $rfdc/s0_axis_aclk]
  connect_bd_net [get_bd_ports user_sysref_adc] [get_bd_pins $rfdc/user_sysref_adc]
  connect_bd_net [get_bd_ports user_sysref_dac] [get_bd_pins $rfdc/user_sysref_dac]

  assign_bd_address -offset 0xA0040000 -range 0x00040000 \
    -target_address_space [get_bd_addr_spaces $ps/Data] \
    [get_bd_addr_segs $rfdc/s_axi/Reg] -force

  validate_bd_design
  save_bd_design
}

create_project $proj_name $proj_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set bd_tcl [file join $script_dir create_t510_fnic_aurora_bd.tcl]
if {[file exists $bd_tcl]} {
  source $bd_tcl
} else {
  create_t510_fnic_aurora_bd
}

set bd_file [file join $proj_dir "${proj_name}.srcs" "sources_1" "bd" "t510_fnic_aurora_bd" "t510_fnic_aurora_bd.bd"]
set bd_obj [get_files -all [file normalize $bd_file]]
set_property synth_checkpoint_mode None $bd_obj
generate_target all $bd_obj
make_wrapper -files $bd_obj -top
add_source_once [file join $proj_dir "${proj_name}.gen" "sources_1" "bd" "t510_fnic_aurora_bd" "hdl" "t510_fnic_aurora_bd_wrapper.v"]

set sources_tcl [file join $script_dir create_t510_fnic_aurora_sources.tcl]
if {[file exists $sources_tcl]} {
  source $sources_tcl
} else {
  foreach rel_path {
    top/t510_fnic/rtl/t510_fnic_aurora_reset_ctrl.v
    top/t510_fnic/rtl/axi_peek_poke_v1_0_S00_AXI.v
    top/t510_fnic/rtl/t510_fnic_aurora_ctrl_parser_256.v
    top/t510_fnic/rtl/t510_fnic_aurora_resp_builder_256.v
    top/t510_fnic/rtl/t510_fnic_aurora_flow_ctrl_rx_256.v
    top/t510_fnic/rtl/t510_fnic_aurora_flow_ctrl_tx_256.v
    top/t510_fnic/rtl/t510_fnic_aurora_tx_sink_checker_256.v
    top/t510_fnic/rtl/t510_fnic_aurora_tx_mux_256.v
    top/t510_fnic/rtl/t510_fnic_aurora_tx_iq_player_256.v
    top/t510_fnic/rtl/t510_fnic_axis_async_fifo_256.v
    top/t510_fnic/rtl/t510_fnic_axis_fifo_256.v
    top/t510_fnic/rtl/t510_fnic_rfdc_iq_packetizer_256.v
    top/t510_fnic/rtl/t510_fnic_aurora_bringup_top.v
  } {
    add_source_once [file join $root_dir $rel_path]
  }

  add_files -fileset constrs_1 -norecurse [file join $root_dir xdc/t510_fnic_qsfp0.xdc]
  add_files -fileset constrs_1 -norecurse [file join $root_dir xdc/t510_fnic_timing.xdc]

  create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
  set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {1} \
    CONFIG.C_PROBE0_WIDTH {512} \
    CONFIG.C_DATA_DEPTH {1024} \
  ] [get_ips ila_0]
  generate_target all [get_ips ila_0]
}

set_property top t510_fnic_aurora_bringup_top [get_filesets sources_1]
update_compile_order -fileset sources_1

set manifest_file [file join $proj_dir "project_manifest.txt"]
set manifest_fp [open $manifest_file w]
puts $manifest_fp "project_name=$proj_name"
puts $manifest_fp "project_dir=$proj_dir"
puts $manifest_fp "part=$part_name"
puts $manifest_fp "vivado_version=2022.2"
puts $manifest_fp "project_tag=$proj_tag"
puts $manifest_fp "build_stamp=$build_stamp"
puts $manifest_fp "git_sha=$git_sha"
puts $manifest_fp "git_status=$git_status"
close $manifest_fp

puts ""
puts "T510-FNIC Aurora 工程已创建:"
puts "  $proj_dir/$proj_name.xpr"
if {$proj_tag ne ""} {
  puts "  tag: $proj_tag"
}
puts ""
puts "顶层模块:"
puts "  t510_fnic_aurora_bringup_top"
puts ""
puts "说明:"
puts "  1. 当前工程包含 QSFP0 Aurora 64B/66B x4 bring-up，并在同一 BD 内加入 T510_AI PS preset 和 RFDC。"
puts "  2. Aurora 默认配置为 10 Gbps/lane、156.25 MHz refclk、Streaming、256-bit 用户接口。"
puts "  3. RFDC s_axi 已通过 PS M_AXI_HPM0_FPD 接入 0xA0040000；未加入 100G Ethernet MAC、RFNoC 或 DMA 逻辑。"
