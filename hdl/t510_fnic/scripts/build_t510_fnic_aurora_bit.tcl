set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize [file join $script_dir ".." ".."]]
set proj_name  "t510_fnic_aurora"
set proj_dir   [file normalize [file join $root_dir "vivado" "project" $proj_name]]

if {$argc >= 1 && [lindex $argv 0] ne ""} {
  set proj_name [lindex $argv 0]
}
if {$argc >= 2 && [lindex $argv 1] ne ""} {
  set proj_dir [file normalize [lindex $argv 1]]
}

set proj_path [file join $proj_dir "${proj_name}.xpr"]
open_project $proj_path
update_compile_order -fileset sources_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
  launch_runs synth_1 -jobs 4
  wait_on_run synth_1
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
  error "impl_1 did not finish"
}

puts "T510 Vivado bitstream generated:"
puts [file normalize [file join $proj_dir "${proj_name}.runs/impl_1/t510_fnic_aurora.bit"]]
