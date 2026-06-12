set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set proj_name  "t510_ai_100g_full_system"
set proj_path  [file join $root_dir "vivado" "project" $proj_name "${proj_name}.xpr"]

proc ensure_parent_dir {path} {
  file mkdir [file dirname $path]
}

proc is_top_level_bd {bd_path} {
  set bd_norm [file normalize $bd_path]
  if {![string match "*.bd" $bd_norm]} {
    return 0
  }
  if {[string first "/ip/" $bd_norm] != -1} {
    return 0
  }
  return 1
}

proc get_export_targets {root_dir script_dir proj_name bd_path} {
  set bd_norm [file normalize $bd_path]
  set bd_name [file rootname [file tail $bd_norm]]
  set outputs [dict create type "" tcl_outputs {} wrapper_outputs {}]
  set build_ip_prefix [file join $root_dir "top" "t510_ai" "build-ip"]
  set project_bd_prefix [file join $root_dir "vivado" "project" $proj_name "${proj_name}.srcs" "sources_1" "bd"]

  if {[string first "${build_ip_prefix}/" $bd_norm] == 0 && [file tail [file dirname $bd_norm]] eq $bd_name} {
    set build_ip_dir [file dirname [file dirname $bd_norm]]
    set build_ip_tcl [file join $build_ip_dir "${bd_name}.tcl"]
    set ip_dir [file join $root_dir "top" "t510_ai" "ip" $bd_name]
    set tcl_outputs [list $build_ip_tcl]
    set wrapper_outputs {}

    if {[file isdirectory $ip_dir]} {
      lappend tcl_outputs [file join $ip_dir "${bd_name}.tcl"]
      lappend wrapper_outputs [file join $ip_dir "${bd_name}_wrapper.v"]
    }

    dict set outputs type build_ip
    dict set outputs tcl_outputs $tcl_outputs
    dict set outputs wrapper_outputs $wrapper_outputs
    return $outputs
  }

  if {[string first "${project_bd_prefix}/" $bd_norm] == 0 && [file tail [file dirname $bd_norm]] eq $bd_name} {
    if {$bd_name eq "t510_ai_100g_ps_bd"} {
      dict set outputs type project_bd
      dict set outputs tcl_outputs [list [file join $script_dir "create_t510_ai_100g_ps_bd_exported_from_current.tcl"]]
      dict set outputs wrapper_outputs {}
      return $outputs
    }

    dict set outputs type project_bd
    dict set outputs tcl_outputs [list [file join $script_dir "${bd_name}_exported_from_current.tcl"]]
    dict set outputs wrapper_outputs {}
    return $outputs
  }

  return $outputs
}

proc export_one_bd {bd_path tcl_outputs wrapper_outputs} {
  set bd_norm [file normalize $bd_path]
  if {![file exists $bd_norm]} {
    error "BD file not found: $bd_norm"
  }

  puts ""
  puts "Exporting BD: $bd_norm"

  open_bd_design $bd_norm
  validate_bd_design
  save_bd_design

  set primary_tcl [file normalize [lindex $tcl_outputs 0]]
  ensure_parent_dir $primary_tcl
  write_bd_tcl -force $primary_tcl
  puts "  wrote Tcl: $primary_tcl"

  foreach extra_tcl [lrange $tcl_outputs 1 end] {
    set extra_norm [file normalize $extra_tcl]
    ensure_parent_dir $extra_norm
    file copy -force $primary_tcl $extra_norm
    puts "  copied Tcl: $extra_norm"
  }

  if {[llength $wrapper_outputs] > 0} {
    set bd_obj [get_files -all $bd_norm]
    generate_target all $bd_obj
    make_wrapper -files $bd_obj -top

    set bd_name [file rootname [file tail $bd_norm]]
    set wrapper_src [file join [file dirname $bd_norm] "hdl" "${bd_name}_wrapper.v"]
    if {![file exists $wrapper_src]} {
      error "Wrapper file not found: $wrapper_src"
    }

    foreach wrapper_out $wrapper_outputs {
      set wrapper_norm [file normalize $wrapper_out]
      ensure_parent_dir $wrapper_norm
      file copy -force $wrapper_src $wrapper_norm
      puts "  copied wrapper: $wrapper_norm"
    }
  }
}

if {![file exists $proj_path]} {
  puts stderr "ERROR: project not found: $proj_path"
  exit 1
}

open_project $proj_path

set all_bds [lsort [get_files -all *.bd]]
set top_level_bds {}
foreach bd_path $all_bds {
  if {[is_top_level_bd $bd_path]} {
    lappend top_level_bds [file normalize $bd_path]
  }
}

puts "Detected top-level BDs:"
foreach bd_path $top_level_bds {
  puts "  $bd_path"
}

set exported_count 0
foreach bd_path $top_level_bds {
  set targets [get_export_targets $root_dir $script_dir $proj_name $bd_path]
  set tcl_outputs [dict get $targets tcl_outputs]
  if {[llength $tcl_outputs] == 0} {
    puts ""
    puts "Skipping unsupported BD path: $bd_path"
    continue
  }

  export_one_bd \
    $bd_path \
    $tcl_outputs \
    [dict get $targets wrapper_outputs]
  incr exported_count
}

close_project

puts ""
puts "Current T510-AI BD Tcl export complete. Exported $exported_count top-level BD(s)."
