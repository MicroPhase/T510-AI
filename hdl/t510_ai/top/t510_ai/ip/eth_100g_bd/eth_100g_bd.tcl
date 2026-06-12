
################################################################
# This is a generated script based on design: eth_100g_bd
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
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

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2022.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source eth_100g_bd_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu47dr-ffve1156-2-i
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name eth_100g_bd

# This script was generated for a remote BD. To create a non-remote design,
# change the variable <run_remote_bd_flow> to <0>.

set run_remote_bd_flow 1
if { $run_remote_bd_flow == 1 } {
  # Set the reference directory for source file relative paths (by default 
  # the value is script directory path)
  set origin_dir ./top/t510_ai/build-ip/xczu47drffve1156-2-i/eth_100g_bd

  # Use origin directory path location variable, if specified in the tcl shell
  if { [info exists ::origin_dir_loc] } {
     set origin_dir $::origin_dir_loc
  }

  set str_bd_folder [file normalize ${origin_dir}]
  set str_bd_filepath ${str_bd_folder}/${design_name}/${design_name}.bd

  # Check if remote design exists on disk
  if { [file exists $str_bd_filepath ] == 1 } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2030 -severity "ERROR" "The remote BD file path <$str_bd_filepath> already exists!"}
     common::send_gid_msg -ssname BD::TCL -id 2031 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0>."
     common::send_gid_msg -ssname BD::TCL -id 2032 -severity "INFO" "Also make sure there is no design <$design_name> existing in your current project."

     return 1
  }

  # Check if design exists in memory
  set list_existing_designs [get_bd_designs -quiet $design_name]
  if { $list_existing_designs ne "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2033 -severity "ERROR" "The design <$design_name> already exists in this project! Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."}

     common::send_gid_msg -ssname BD::TCL -id 2034 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0> or please set a different value to variable <design_name>."

     return 1
  }

  # Check if design exists on disk within project
  set list_existing_designs [get_files -quiet */${design_name}.bd]
  if { $list_existing_designs ne "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2035 -severity "ERROR" "The design <$design_name> already exists in this project at location:
    $list_existing_designs"}
     catch {common::send_gid_msg -ssname BD::TCL -id 2036 -severity "ERROR" "Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."}

     common::send_gid_msg -ssname BD::TCL -id 2037 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0> or please set a different value to variable <design_name>."

     return 1
  }

  # Now can create the remote BD
  # NOTE - usage of <-dir> will create <$str_bd_folder/$design_name/$design_name.bd>
  create_bd_design -dir $str_bd_folder $design_name
} else {

  # Create regular design
  if { [catch {create_bd_design $design_name} errmsg] } {
     common::send_gid_msg -ssname BD::TCL -id 2038 -severity "INFO" "Please set a different value to variable <design_name>."

     return 1
  }
}

current_bd_design $design_name

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:cmac_usplus:3.1\
xilinx.com:ip:xlconstant:1.1\
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

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set core_drp [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:drp_rtl:1.0 core_drp ]

  set eth100g_rx [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_cmac_usplus:lbus_ports:2.0 eth100g_rx ]

  set eth100g_tx [ create_bd_intf_port -mode Slave -vlnv xilinx.com:display_cmac_usplus:lbus_ports:2.0 eth100g_tx ]

  set refclk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 refclk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {156250000} \
   ] $refclk

  set s_axi [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {32} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {32} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {0} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_PROT {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {0} \
   CONFIG.MAX_BURST_LENGTH {1} \
   CONFIG.NUM_READ_OUTSTANDING {1} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {1} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI4LITE} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {0} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $s_axi


  # Create ports
  set core_rx_reset [ create_bd_port -dir I -type rst core_rx_reset ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $core_rx_reset
  set core_tx_reset [ create_bd_port -dir I -type rst core_tx_reset ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $core_tx_reset
  set ctl_tx_pause_req [ create_bd_port -dir I -from 8 -to 0 ctl_tx_pause_req ]
  set ctl_tx_resend_pause [ create_bd_port -dir I ctl_tx_resend_pause ]
  set drp_clk [ create_bd_port -dir I -type clk drp_clk ]
  set gt_powergoodout [ create_bd_port -dir O -from 3 -to 0 gt_powergoodout ]
  set gt_txusrclk2 [ create_bd_port -dir O -type clk gt_txusrclk2 ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {eth100g_rx:eth100g_tx} \
   CONFIG.FREQ_HZ {322265625} \
 ] $gt_txusrclk2
  set gtwiz_reset_rx_datapath [ create_bd_port -dir I -type rst gtwiz_reset_rx_datapath ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $gtwiz_reset_rx_datapath
  set gtwiz_reset_tx_datapath [ create_bd_port -dir I -type rst gtwiz_reset_tx_datapath ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $gtwiz_reset_tx_datapath
  set init_clk [ create_bd_port -dir I -type clk init_clk ]
  set pm_tick [ create_bd_port -dir I pm_tick ]
  set rx_clk [ create_bd_port -dir I -type clk -freq_hz 322265625 rx_clk ]
  set rx_n [ create_bd_port -dir I -from 3 -to 0 rx_n ]
  set rx_p [ create_bd_port -dir I -from 3 -to 0 rx_p ]
  set s_axi_aclk [ create_bd_port -dir I -type clk s_axi_aclk ]
  set s_axi_sreset [ create_bd_port -dir I -type rst s_axi_sreset ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $s_axi_sreset
  set stat_rx_aligned [ create_bd_port -dir O stat_rx_aligned ]
  set stat_rx_aligned_err [ create_bd_port -dir O stat_rx_aligned_err ]
  set stat_rx_bip_err_0_0 [ create_bd_port -dir O stat_rx_bip_err_0_0 ]
  set stat_rx_bip_err_10_0 [ create_bd_port -dir O stat_rx_bip_err_10_0 ]
  set stat_rx_bip_err_11_0 [ create_bd_port -dir O stat_rx_bip_err_11_0 ]
  set stat_rx_bip_err_12_0 [ create_bd_port -dir O stat_rx_bip_err_12_0 ]
  set stat_rx_bip_err_13_0 [ create_bd_port -dir O stat_rx_bip_err_13_0 ]
  set stat_rx_bip_err_14_0 [ create_bd_port -dir O stat_rx_bip_err_14_0 ]
  set stat_rx_bip_err_15_0 [ create_bd_port -dir O stat_rx_bip_err_15_0 ]
  set stat_rx_bip_err_16_0 [ create_bd_port -dir O stat_rx_bip_err_16_0 ]
  set stat_rx_bip_err_17_0 [ create_bd_port -dir O stat_rx_bip_err_17_0 ]
  set stat_rx_bip_err_18_0 [ create_bd_port -dir O stat_rx_bip_err_18_0 ]
  set stat_rx_bip_err_19_0 [ create_bd_port -dir O stat_rx_bip_err_19_0 ]
  set stat_rx_bip_err_1_0 [ create_bd_port -dir O stat_rx_bip_err_1_0 ]
  set stat_rx_bip_err_2_0 [ create_bd_port -dir O stat_rx_bip_err_2_0 ]
  set stat_rx_bip_err_3_0 [ create_bd_port -dir O stat_rx_bip_err_3_0 ]
  set stat_rx_bip_err_4_0 [ create_bd_port -dir O stat_rx_bip_err_4_0 ]
  set stat_rx_bip_err_5_0 [ create_bd_port -dir O stat_rx_bip_err_5_0 ]
  set stat_rx_bip_err_6_0 [ create_bd_port -dir O stat_rx_bip_err_6_0 ]
  set stat_rx_bip_err_7_0 [ create_bd_port -dir O stat_rx_bip_err_7_0 ]
  set stat_rx_bip_err_8_0 [ create_bd_port -dir O stat_rx_bip_err_8_0 ]
  set stat_rx_bip_err_9_0 [ create_bd_port -dir O stat_rx_bip_err_9_0 ]
  set stat_rx_block_lock [ create_bd_port -dir O -from 19 -to 0 stat_rx_block_lock ]
  set stat_rx_hi_ber [ create_bd_port -dir O stat_rx_hi_ber ]
  set stat_rx_misaligned [ create_bd_port -dir O stat_rx_misaligned ]
  set stat_rx_pause_req [ create_bd_port -dir O -from 8 -to 0 stat_rx_pause_req ]
  set stat_rx_pcsl_number_0_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_0_0 ]
  set stat_rx_pcsl_number_10_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_10_0 ]
  set stat_rx_pcsl_number_11_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_11_0 ]
  set stat_rx_pcsl_number_12_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_12_0 ]
  set stat_rx_pcsl_number_13_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_13_0 ]
  set stat_rx_pcsl_number_14_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_14_0 ]
  set stat_rx_pcsl_number_15_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_15_0 ]
  set stat_rx_pcsl_number_16_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_16_0 ]
  set stat_rx_pcsl_number_17_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_17_0 ]
  set stat_rx_pcsl_number_18_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_18_0 ]
  set stat_rx_pcsl_number_19_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_19_0 ]
  set stat_rx_pcsl_number_1_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_1_0 ]
  set stat_rx_pcsl_number_2_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_2_0 ]
  set stat_rx_pcsl_number_3_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_3_0 ]
  set stat_rx_pcsl_number_4_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_4_0 ]
  set stat_rx_pcsl_number_5_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_5_0 ]
  set stat_rx_pcsl_number_6_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_6_0 ]
  set stat_rx_pcsl_number_7_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_7_0 ]
  set stat_rx_pcsl_number_8_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_8_0 ]
  set stat_rx_pcsl_number_9_0 [ create_bd_port -dir O -from 4 -to 0 stat_rx_pcsl_number_9_0 ]
  set stat_rx_synced [ create_bd_port -dir O -from 19 -to 0 stat_rx_synced ]
  set stat_rx_synced_err [ create_bd_port -dir O -from 19 -to 0 stat_rx_synced_err ]
  set sys_reset [ create_bd_port -dir I -type rst sys_reset ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $sys_reset
  set tx_n [ create_bd_port -dir O -from 3 -to 0 tx_n ]
  set tx_ovfout [ create_bd_port -dir O tx_ovfout ]
  set tx_p [ create_bd_port -dir O -from 3 -to 0 tx_p ]
  set tx_unfout [ create_bd_port -dir O tx_unfout ]
  set usr_rx_reset [ create_bd_port -dir O -type rst usr_rx_reset ]
  set usr_tx_reset [ create_bd_port -dir O -type rst usr_tx_reset ]

  # Create instance: cmac_usplus_0, and set properties
  set cmac_usplus_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:cmac_usplus:3.1 cmac_usplus_0 ]
  set_property -dict [list \
    CONFIG.CMAC_CAUI4_MODE {1} \
    CONFIG.CMAC_CORE_SELECT {CMACE4_X0Y0} \
    CONFIG.ENABLE_AXI_INTERFACE {1} \
    CONFIG.GT_DRP_CLK {100} \
    CONFIG.GT_GROUP_SELECT {X0Y4~X0Y7} \
    CONFIG.GT_REF_CLK_FREQ {156.25} \
    CONFIG.INCLUDE_AUTO_NEG_LT_LOGIC {0} \
    CONFIG.INCLUDE_RS_FEC {1} \
    CONFIG.INCLUDE_SHARED_LOGIC {2} \
    CONFIG.INCLUDE_STATISTICS_COUNTERS {1} \
    CONFIG.NUM_LANES {4x25} \
    CONFIG.RX_CHECK_ACK {0} \
    CONFIG.RX_EQ_MODE {DFE} \
    CONFIG.RX_FLOW_CONTROL {1} \
    CONFIG.TX_FLOW_CONTROL {1} \
    CONFIG.USER_INTERFACE {LBUS} \
  ] $cmac_usplus_0


  # Create instance: tie_loopback, and set properties
  set tie_loopback [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 tie_loopback ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {12} \
  ] $tie_loopback


  # Create interface connections
  connect_bd_intf_net -intf_net RefClk_1 [get_bd_intf_ports refclk] [get_bd_intf_pins cmac_usplus_0/gt_ref_clk]
  connect_bd_intf_net -intf_net cmac_usplus_0_lbus_rx [get_bd_intf_ports eth100g_rx] [get_bd_intf_pins cmac_usplus_0/lbus_rx]
  connect_bd_intf_net -intf_net eth_100g_tx_1 [get_bd_intf_ports eth100g_tx] [get_bd_intf_pins cmac_usplus_0/lbus_tx]
  connect_bd_intf_net -intf_net sDrp_1 [get_bd_intf_ports core_drp] [get_bd_intf_pins cmac_usplus_0/core_drp]
  connect_bd_intf_net -intf_net s_axi_1 [get_bd_intf_ports s_axi] [get_bd_intf_pins cmac_usplus_0/s_axi]

  # Create port connections
  connect_bd_net -net SysClk_1 [get_bd_ports init_clk] [get_bd_pins cmac_usplus_0/init_clk]
  connect_bd_net -net aResetIn_1 [get_bd_ports sys_reset] [get_bd_pins cmac_usplus_0/core_drp_reset] [get_bd_pins cmac_usplus_0/sys_reset]
  connect_bd_net -net cmac_usplus_0_gt_powergoodout [get_bd_ports gt_powergoodout] [get_bd_pins cmac_usplus_0/gt_powergoodout]
  connect_bd_net -net cmac_usplus_0_gt_txn_out [get_bd_ports tx_n] [get_bd_pins cmac_usplus_0/gt_txn_out]
  connect_bd_net -net cmac_usplus_0_gt_txp_out [get_bd_ports tx_p] [get_bd_pins cmac_usplus_0/gt_txp_out]
  connect_bd_net -net cmac_usplus_0_gt_txusrclk2 [get_bd_ports gt_txusrclk2] [get_bd_pins cmac_usplus_0/gt_txusrclk2]
  connect_bd_net -net cmac_usplus_0_stat_rx_aligned [get_bd_ports stat_rx_aligned] [get_bd_pins cmac_usplus_0/stat_rx_aligned]
  connect_bd_net -net cmac_usplus_0_stat_rx_aligned_err [get_bd_ports stat_rx_aligned_err] [get_bd_pins cmac_usplus_0/stat_rx_aligned_err]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_0 [get_bd_ports stat_rx_bip_err_0_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_0]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_1 [get_bd_ports stat_rx_bip_err_1_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_1]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_2 [get_bd_ports stat_rx_bip_err_2_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_2]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_3 [get_bd_ports stat_rx_bip_err_3_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_3]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_4 [get_bd_ports stat_rx_bip_err_4_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_4]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_5 [get_bd_ports stat_rx_bip_err_5_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_5]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_6 [get_bd_ports stat_rx_bip_err_6_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_6]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_7 [get_bd_ports stat_rx_bip_err_7_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_7]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_8 [get_bd_ports stat_rx_bip_err_8_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_8]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_9 [get_bd_ports stat_rx_bip_err_9_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_9]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_10 [get_bd_ports stat_rx_bip_err_10_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_10]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_11 [get_bd_ports stat_rx_bip_err_11_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_11]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_12 [get_bd_ports stat_rx_bip_err_12_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_12]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_13 [get_bd_ports stat_rx_bip_err_13_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_13]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_14 [get_bd_ports stat_rx_bip_err_14_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_14]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_15 [get_bd_ports stat_rx_bip_err_15_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_15]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_16 [get_bd_ports stat_rx_bip_err_16_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_16]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_17 [get_bd_ports stat_rx_bip_err_17_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_17]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_18 [get_bd_ports stat_rx_bip_err_18_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_18]
  connect_bd_net -net cmac_usplus_0_stat_rx_bip_err_19 [get_bd_ports stat_rx_bip_err_19_0] [get_bd_pins cmac_usplus_0/stat_rx_bip_err_19]
  connect_bd_net -net cmac_usplus_0_stat_rx_block_lock [get_bd_ports stat_rx_block_lock] [get_bd_pins cmac_usplus_0/stat_rx_block_lock]
  connect_bd_net -net cmac_usplus_0_stat_rx_hi_ber [get_bd_ports stat_rx_hi_ber] [get_bd_pins cmac_usplus_0/stat_rx_hi_ber]
  connect_bd_net -net cmac_usplus_0_stat_rx_misaligned [get_bd_ports stat_rx_misaligned] [get_bd_pins cmac_usplus_0/stat_rx_misaligned]
  connect_bd_net -net cmac_usplus_0_stat_rx_pause_req [get_bd_ports stat_rx_pause_req] [get_bd_pins cmac_usplus_0/stat_rx_pause_req]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_0 [get_bd_ports stat_rx_pcsl_number_0_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_0]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_1 [get_bd_ports stat_rx_pcsl_number_1_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_1]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_2 [get_bd_ports stat_rx_pcsl_number_2_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_2]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_3 [get_bd_ports stat_rx_pcsl_number_3_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_3]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_4 [get_bd_ports stat_rx_pcsl_number_4_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_4]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_5 [get_bd_ports stat_rx_pcsl_number_5_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_5]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_6 [get_bd_ports stat_rx_pcsl_number_6_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_6]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_7 [get_bd_ports stat_rx_pcsl_number_7_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_7]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_8 [get_bd_ports stat_rx_pcsl_number_8_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_8]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_9 [get_bd_ports stat_rx_pcsl_number_9_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_9]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_10 [get_bd_ports stat_rx_pcsl_number_10_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_10]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_11 [get_bd_ports stat_rx_pcsl_number_11_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_11]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_12 [get_bd_ports stat_rx_pcsl_number_12_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_12]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_13 [get_bd_ports stat_rx_pcsl_number_13_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_13]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_14 [get_bd_ports stat_rx_pcsl_number_14_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_14]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_15 [get_bd_ports stat_rx_pcsl_number_15_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_15]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_16 [get_bd_ports stat_rx_pcsl_number_16_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_16]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_17 [get_bd_ports stat_rx_pcsl_number_17_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_17]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_18 [get_bd_ports stat_rx_pcsl_number_18_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_18]
  connect_bd_net -net cmac_usplus_0_stat_rx_pcsl_number_19 [get_bd_ports stat_rx_pcsl_number_19_0] [get_bd_pins cmac_usplus_0/stat_rx_pcsl_number_19]
  connect_bd_net -net cmac_usplus_0_stat_rx_synced [get_bd_ports stat_rx_synced] [get_bd_pins cmac_usplus_0/stat_rx_synced]
  connect_bd_net -net cmac_usplus_0_stat_rx_synced_err [get_bd_ports stat_rx_synced_err] [get_bd_pins cmac_usplus_0/stat_rx_synced_err]
  connect_bd_net -net cmac_usplus_0_tx_ovfout [get_bd_ports tx_ovfout] [get_bd_pins cmac_usplus_0/tx_ovfout]
  connect_bd_net -net cmac_usplus_0_tx_unfout [get_bd_ports tx_unfout] [get_bd_pins cmac_usplus_0/tx_unfout]
  connect_bd_net -net cmac_usplus_0_usr_rx_reset [get_bd_ports usr_rx_reset] [get_bd_pins cmac_usplus_0/usr_rx_reset]
  connect_bd_net -net cmac_usplus_0_usr_tx_reset [get_bd_ports usr_tx_reset] [get_bd_pins cmac_usplus_0/usr_tx_reset]
  connect_bd_net -net core_rx_reset_1 [get_bd_ports core_rx_reset] [get_bd_pins cmac_usplus_0/core_rx_reset]
  connect_bd_net -net core_tx_reset_0_1 [get_bd_ports core_tx_reset] [get_bd_pins cmac_usplus_0/core_tx_reset]
  connect_bd_net -net ctl_tx_pause_req_1 [get_bd_ports ctl_tx_pause_req] [get_bd_pins cmac_usplus_0/ctl_tx_pause_req]
  connect_bd_net -net ctl_tx_resend_pause_1 [get_bd_ports ctl_tx_resend_pause] [get_bd_pins cmac_usplus_0/ctl_tx_resend_pause]
  connect_bd_net -net drp_clk_1 [get_bd_ports drp_clk] [get_bd_pins cmac_usplus_0/drp_clk]
  connect_bd_net -net gt_rxn_in_0_1 [get_bd_ports rx_n] [get_bd_pins cmac_usplus_0/gt_rxn_in]
  connect_bd_net -net gt_rxp_in_0_1 [get_bd_ports rx_p] [get_bd_pins cmac_usplus_0/gt_rxp_in]
  connect_bd_net -net gtwiz_reset_rx_datapath_1 [get_bd_ports gtwiz_reset_rx_datapath] [get_bd_pins cmac_usplus_0/gtwiz_reset_rx_datapath]
  connect_bd_net -net gtwiz_reset_tx_datapath_0_1 [get_bd_ports gtwiz_reset_tx_datapath] [get_bd_pins cmac_usplus_0/gtwiz_reset_tx_datapath]
  connect_bd_net -net pm_tick_1 [get_bd_ports pm_tick] [get_bd_pins cmac_usplus_0/pm_tick]
  connect_bd_net -net rx_clk_1 [get_bd_ports rx_clk] [get_bd_pins cmac_usplus_0/rx_clk]
  connect_bd_net -net s_axi_aclk_1 [get_bd_ports s_axi_aclk] [get_bd_pins cmac_usplus_0/s_axi_aclk]
  connect_bd_net -net s_axi_sreset_1 [get_bd_ports s_axi_sreset] [get_bd_pins cmac_usplus_0/s_axi_sreset]
  connect_bd_net -net tie_loopback_dout [get_bd_pins cmac_usplus_0/gt_loopback_in] [get_bd_pins tie_loopback/dout]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x00002000 -target_address_space [get_bd_addr_spaces s_axi] [get_bd_addr_segs cmac_usplus_0/s_axi/Reg] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


