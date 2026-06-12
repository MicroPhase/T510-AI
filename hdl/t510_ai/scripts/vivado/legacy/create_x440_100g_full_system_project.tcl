set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set proj_name  "x440_100g_full_system"
set proj_dir   [file normalize [file join $root_dir "vivado" "project" $proj_name]]
set part_name  "xczu47dr-ffve1156-2-i"

proc add_source_once {file_path} {
  set norm_path [file normalize $file_path]
  if {[llength [get_files -quiet $norm_path]] == 0} {
    add_files -norecurse $norm_path
  }
}

proc add_globbed_sources {dir patterns} {
  foreach pattern $patterns {
    foreach f [lsort [glob -nocomplain -directory $dir $pattern]] {
      if {[file isdirectory $f]} {
        continue
      }
      if {[string match "*_tb*" $f]} {
        continue
      }
      if {[string match "*model_100gbe.sv" $f]} {
        continue
      }
      add_source_once $f
    }
  }
}

create_project $proj_name $proj_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

foreach rel_path {
  lib/axi4_sv/PkgAxi.sv
  lib/axi4_sv/AxiIf.sv
  lib/axi4_sv/axi.vh
  lib/axi4lite_sv/PkgAxiLite.sv
  lib/axi4lite_sv/AxiLiteIf.sv
  lib/axi4lite_sv/axi_lite.vh
  lib/axi4s_sv/AxiStreamIf.sv
  lib/axi4s_sv/axi4s.vh
  lib/control/synchronizer_impl.v
  lib/control/synchronizer.v
  lib/control/reset_sync.v
  lib/control/pulse_synchronizer.v
  lib/control/axil_regport_master.v
  lib/control/regport_resp_mux.v
  top/x400/ip/axi_eth_dma_bd/axi_eth_dma_bd_wrapper.v
  top/x400/ip/axi_interconnect_dma_bd/axi_interconnect_dma_bd_wrapper.v
  top/x400/ip/axi_interconnect_eth_bd/axi_interconnect_eth_bd_wrapper.v
  top/x400/ip/eth_100g_bd/PkgEth100gLbus.sv
  top/x400/ip/eth_100g_bd/eth_100g_bd_wrapper.v
} {
  add_source_once [file join $root_dir $rel_path]
}

foreach rel_dir {
  lib/control
  lib/control/map
  lib/fifo
  lib/axi
  lib/packet_proc
  lib/axi4s_sv
  lib/rfnoc/crossbar
  lib/rfnoc/core
  lib/rfnoc/utils
  lib/rfnoc/xport
  lib/rfnoc/xport_sv
  lib/rfnoc/transport_adapters/rfnoc_ta_x4xx_eth
  top/x400/ip/eth_100g_bd
  top/x400/ip/axi_eth_dma_bd
  top/x400/ip/axi_interconnect_eth_bd
  top/x400/ip/axi_interconnect_dma_bd
  top/x400/ip/fifo_short_2clk
  top/x400/ip/fifo_4k_2clk
} {
  add_globbed_sources [file join $root_dir $rel_dir] {*.sv *.v *.vh}
}

set ip_files [list \
  [file join $root_dir top/x400/build-ip/xczu28drffvg1517-2e/fifo_short_2clk/fifo_short_2clk.xci] \
  [file join $root_dir top/x400/build-ip/xczu28drffvg1517-2e/fifo_4k_2clk/fifo_4k_2clk.xci] \
]

foreach ip_file $ip_files {
  add_source_once $ip_file
}

foreach ip_file $ip_files {
  set ip_obj [get_files -all [file normalize $ip_file]]
  generate_target all $ip_obj
}

set bd_files [list \
  [file join $root_dir top/x400/build-ip/xczu28drffvg1517-2e/eth_100g_bd/eth_100g_bd/eth_100g_bd.bd] \
  [file join $root_dir top/x400/build-ip/xczu28drffvg1517-2e/axi_eth_dma_bd/axi_eth_dma_bd/axi_eth_dma_bd.bd] \
  [file join $root_dir top/x400/build-ip/xczu28drffvg1517-2e/axi_interconnect_eth_bd/axi_interconnect_eth_bd/axi_interconnect_eth_bd.bd] \
  [file join $root_dir top/x400/build-ip/xczu28drffvg1517-2e/axi_interconnect_dma_bd/axi_interconnect_dma_bd/axi_interconnect_dma_bd.bd] \
]

foreach bd_file $bd_files {
  add_source_once $bd_file
}

set imported_ips [get_ips -quiet]
if {[llength $imported_ips] > 0} {
  catch {upgrade_ip $imported_ips} upgrade_status
  puts "IP upgrade status:"
  puts "  $upgrade_status"
}

foreach bd_file $bd_files {
  set bd_obj [get_files -all [file normalize $bd_file]]
  set_property synth_checkpoint_mode None $bd_obj
  generate_target all $bd_obj
}

source [file join $script_dir create_x440_100g_ps_bd_exported_from_current.tcl]
set ps_bd_file [file join $proj_dir "${proj_name}.srcs" "sources_1" "bd" "x440_100g_ps_bd" "x440_100g_ps_bd.bd"]
set ps_bd_obj [get_files -all [file normalize $ps_bd_file]]
generate_target all $ps_bd_obj
make_wrapper -files $ps_bd_obj -top
add_source_once [file join $proj_dir "${proj_name}.gen" "sources_1" "bd" "x440_100g_ps_bd" "hdl" "x440_100g_ps_bd_wrapper.v"]

set include_dirs [list \
  [file join $root_dir lib/axi4_sv] \
  [file join $root_dir lib/axi4lite_sv] \
  [file join $root_dir lib/axi4s_sv] \
  [file join $root_dir lib/control] \
  [file join $root_dir lib/control/map] \
  [file join $root_dir lib/fifo] \
  [file join $root_dir lib/axi] \
  [file join $root_dir lib/packet_proc] \
  [file join $root_dir lib/rfnoc/crossbar] \
  [file join $root_dir lib/rfnoc/core] \
  [file join $root_dir lib/rfnoc/utils] \
  [file join $root_dir lib/rfnoc/xport] \
  [file join $root_dir lib/rfnoc/xport_sv] \
  [file join $root_dir lib/rfnoc/transport_adapters/rfnoc_ta_x4xx_eth] \
  [file join $root_dir top/x400/ip/eth_100g_bd] \
  [file join $root_dir top/x400/ip/axi_eth_dma_bd] \
  [file join $root_dir top/x400/ip/axi_interconnect_eth_bd] \
  [file join $root_dir top/x400/ip/axi_interconnect_dma_bd] \
]
set_property include_dirs $include_dirs [get_filesets sources_1]

add_files -fileset constrs_1 -norecurse [file join $script_dir x440_100g_full_system_timing.xdc]

set_property top x440_100g_full_system_top [get_filesets sources_1]
update_compile_order -fileset sources_1

puts ""
puts "完整工程已创建:"
puts "  $proj_dir/$proj_name.xpr"
puts ""
puts "顶层模块:"
puts "  x440_100g_full_system_top"
puts ""
puts "说明:"
puts "  1. 工程已包含最小 PS Block Design、100G QSFP wrapper 和 DMA 路径。"
puts "  2. PS 侧 AXI-Lite 参考原始 X440 配置，将 GP0 配成 32bit 后再通过 AXI4->AXI4-Lite 转换接入 100G 寄存器口。"
puts "  3. PS 侧 HPC1 参考原始 X440 配置，承接 100G DMA 主口。"
puts "  4. 当前 PL->PS 导出 8bit IRQ，与原始 X440 的 pl_ps_irq0 宽度一致。"
