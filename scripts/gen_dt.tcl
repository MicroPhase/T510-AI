set hw [lindex $argv 0]
set repo_dir [lindex $argv 1]
set out_dir [lindex $argv 2]
set proc_name [lindex $argv 3]
set user_dtsi [lindex $argv 4]

if {$hw eq "" || $repo_dir eq "" || $out_dir eq "" || $proc_name eq ""} {
	puts "usage: xsct gen_dt.tcl <hw.hdf|hw.xsa> <device-tree-xlnx> <out_dir> <proc> [user_dtsi]"
	exit 1
}

if {[file exists $out_dir]} {
	file delete -force $out_dir
}
file mkdir $out_dir

hsi::open_hw_design $hw
hsi::set_repo_path $repo_dir
set design [hsi::create_sw_design device-tree -os device_tree -proc $proc_name]
::hsi::generate_bsp -dir $out_dir

set dts_file [file join $out_dir system-top.dts]

if {$user_dtsi ne "" && [file exists $user_dtsi]} {
	file copy -force $user_dtsi [file join $out_dir system-user.dtsi]
	set fd [open $dts_file a]
	puts $fd ""
	puts $fd "#include \"system-user.dtsi\""
	close $fd
}

exit
