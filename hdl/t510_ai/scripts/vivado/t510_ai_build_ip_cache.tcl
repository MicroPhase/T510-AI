namespace eval t510_ai {
proc add_file_once {file_path} {
  set norm_path [file normalize $file_path]
  if {[llength [get_files -quiet $norm_path]] == 0} {
    add_files -norecurse $norm_path
  }
}

proc ensure_dir {dir_path} {
  file mkdir $dir_path
}

proc reset_dir {dir_path} {
  if {[file exists $dir_path]} {
    file delete -force $dir_path
  }
  file mkdir $dir_path
}

proc cache_complete {root_dir part_dir} {
  set required_paths [list \
    [file join $root_dir top t510_ai build-ip $part_dir fifo_short_2clk fifo_short_2clk.xci] \
    [file join $root_dir top t510_ai build-ip $part_dir fifo_short_2clk sim fifo_short_2clk.v] \
    [file join $root_dir top t510_ai build-ip $part_dir fifo_4k_2clk fifo_4k_2clk.xci] \
    [file join $root_dir top t510_ai build-ip $part_dir fifo_4k_2clk sim fifo_4k_2clk.v] \
    [file join $root_dir top t510_ai build-ip $part_dir eth_100g_bd eth_100g_bd eth_100g_bd.bd] \
    [file join $root_dir top t510_ai build-ip $part_dir axi_eth_dma_bd axi_eth_dma_bd axi_eth_dma_bd.bd] \
    [file join $root_dir top t510_ai build-ip $part_dir axi_interconnect_eth_bd axi_interconnect_eth_bd axi_interconnect_eth_bd.bd] \
    [file join $root_dir top t510_ai build-ip $part_dir axi_interconnect_dma_bd axi_interconnect_dma_bd axi_interconnect_dma_bd.bd] \
  ]

  foreach required_path $required_paths {
    if {![file exists $required_path]} {
      return 0
    }
  }

  return 1
}

proc rebuild_fifo_ip {root_dir part_dir ip_name force_refresh} {
  set source_xci [file join $root_dir top t510_ai ip $ip_name ${ip_name}.xci]
  set target_dir [file join $root_dir top t510_ai build-ip $part_dir $ip_name]
  set target_xci [file join $target_dir ${ip_name}.xci]

  if {![file exists $source_xci]} {
    error "Missing FIFO source XCI: $source_xci"
  }

  if {$force_refresh} {
    reset_dir $target_dir
  } else {
    ensure_dir $target_dir
  }

  file copy -force $source_xci $target_xci
  add_file_once $target_xci

  set ip_file_obj [get_files -all $target_xci]
  if {[llength $ip_file_obj] == 0} {
    error "Vivado failed to import IP: $target_xci"
  }

  set ip_core_obj [get_ips -quiet $ip_name]
  if {[llength $ip_core_obj] > 0} {
    catch {upgrade_ip $ip_core_obj}
  }

  catch {reset_target all $ip_file_obj}
  generate_target all $ip_file_obj
  catch {export_ip_user_files -of_objects $ip_file_obj -sync -force -quiet}
}

proc rebuild_remote_bd {root_dir part_dir bd_name force_refresh} {
  set source_tcl [file join $root_dir top t510_ai ip $bd_name ${bd_name}.tcl]
  set target_root [file join $root_dir top t510_ai build-ip $part_dir $bd_name]
  set target_bd [file join $target_root $bd_name ${bd_name}.bd]

  if {![file exists $source_tcl]} {
    error "Missing BD source Tcl: $source_tcl"
  }

  if {$force_refresh} {
    if {[file exists $target_root]} {
      file delete -force $target_root
    }
  } elseif {[file exists $target_bd]} {
    return
  }

  ensure_dir $target_root
  set ::origin_dir_loc $target_root
  source $source_tcl
  catch {unset ::origin_dir_loc}

  if {![file exists $target_bd]} {
    error "Vivado failed to generate BD cache: $target_bd"
  }

  add_file_once $target_bd
  set bd_obj [get_files -all $target_bd]
  if {[llength $bd_obj] == 0} {
    error "Vivado failed to import BD: $target_bd"
  }

  set_property synth_checkpoint_mode None $bd_obj
  generate_target all $bd_obj
  catch {make_wrapper -files $bd_obj -top}
}

proc rebuild_build_ip_cache {root_dir part_name part_dir {force_refresh 1}} {
  if {[llength [get_projects -quiet]] == 0} {
    error "rebuild_build_ip_cache requires an open Vivado project"
  }

  puts "Preparing build-ip cache under [file join $root_dir top t510_ai build-ip $part_dir]"
  set_property part $part_name [current_project]

  foreach ip_name {fifo_short_2clk fifo_4k_2clk} {
    rebuild_fifo_ip $root_dir $part_dir $ip_name $force_refresh
  }

  foreach bd_name {eth_100g_bd axi_eth_dma_bd axi_interconnect_eth_bd axi_interconnect_dma_bd} {
    rebuild_remote_bd $root_dir $part_dir $bd_name $force_refresh
  }
}
}
