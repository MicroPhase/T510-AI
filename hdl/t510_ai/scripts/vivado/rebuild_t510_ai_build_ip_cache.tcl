set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ".." ".."]]
set part_name "xczu47dr-ffve1156-2-i"
set build_ip_part_dir "xczu47drffve1156-2-i"
set proj_name "t510_ai_build_ip_cache"
set proj_dir [file join $root_dir top t510_ai build-ip .vivado-cache-project]
set force_refresh 1

if {[llength $argv] > 0} {
  set force_refresh [expr {[lindex $argv 0] ? 1 : 0}]
}

source [file join $script_dir t510_ai_build_ip_cache.tcl]

create_project $proj_name $proj_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

t510_ai::rebuild_build_ip_cache $root_dir $part_name $build_ip_part_dir $force_refresh

close_project
if {[file exists $proj_dir]} {
  file delete -force $proj_dir
}

puts ""
puts "T510-AI build-ip cache is ready:"
puts "  [file join $root_dir top t510_ai build-ip $build_ip_part_dir]"
