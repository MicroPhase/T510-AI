set hw [lindex $argv 0]
set out_dir [lindex $argv 1]
set repo_dir [lindex $argv 2]
set fsbl_proc [lindex $argv 3]
set pmufw_proc [lindex $argv 4]
set fsbl_stdio [lindex $argv 5]
set pmufw_stdio [lindex $argv 6]
set fsbl_boot_profile [lindex $argv 7]
set fsbl_debug_level [lindex $argv 8]
set pmufw_enable_efuse_access [lindex $argv 9]

if {$fsbl_stdio eq ""} {
	set fsbl_stdio "psu_uart_0"
}

if {$pmufw_stdio eq ""} {
	set pmufw_stdio $fsbl_stdio
}

if {$fsbl_boot_profile eq ""} {
	set fsbl_boot_profile "full"
}

if {$fsbl_debug_level eq ""} {
	set fsbl_debug_level "off"
}

if {$pmufw_enable_efuse_access eq ""} {
	set pmufw_enable_efuse_access "0"
}

proc configure_fsbl_debug {cfg_path level} {
	if {![file exists $cfg_path]} {
		return
	}

	switch -- $level {
		off {
			return
		}
		basic {
			set replacements [list \
				"#define FSBL_DEBUG_VAL              (0U)" "#define FSBL_DEBUG_VAL              (1U)" \
			]
		}
		info {
			set replacements [list \
				"#define FSBL_DEBUG_VAL              (0U)" "#define FSBL_DEBUG_VAL              (1U)" \
				"#define FSBL_DEBUG_INFO_VAL         (0U)" "#define FSBL_DEBUG_INFO_VAL         (1U)" \
			]
		}
		detailed {
			set replacements [list \
				"#define FSBL_DEBUG_VAL              (0U)" "#define FSBL_DEBUG_VAL              (1U)" \
				"#define FSBL_DEBUG_INFO_VAL         (0U)" "#define FSBL_DEBUG_INFO_VAL         (1U)" \
				"#define FSBL_DEBUG_DETAILED_VAL     (0U)" "#define FSBL_DEBUG_DETAILED_VAL     (1U)" \
			]
		}
		default {
			error "unsupported FSBL debug level: $level"
		}
	}

	set fd [open $cfg_path r]
	set data [read $fd]
	close $fd

	set data [string map $replacements $data]

	set fd [open $cfg_path w]
	puts -nonewline $fd $data
	close $fd
}

proc rewrite_file {path map_list} {
	if {![file exists $path]} {
		return
	}

	set fd [open $path r]
	set data [read $fd]
	close $fd

	set data [string map $map_list $data]

	set fd [open $path w]
	puts -nonewline $fd $data
	close $fd
}

proc relocate_fsbl_handoff {src_path} {
	if {![file exists $src_path]} {
		return
	}

	# ATF reads the handoff structure address from PMU_GLOBAL.GLOBAL_GEN_STORAGE6,
	# so it does not need to live in the SDK's dedicated .handoff_params window.
	# Put it in .bss instead, which keeps it below BL31's OCM load range.
	rewrite_file $src_path [list \
		{section (".handoff_params")} {section (".bss.handoff_params")} \
	]
}

proc configure_fsbl_boot_profile {cfg_path profile} {
	if {![file exists $cfg_path]} {
		return
	}

	switch -- $profile {
		full {
			return
		}
		sd {
			# SD boot loads BOOT.BIN partitions from SD and programs PL later from
			# U-Boot, so FSBL can omit unused boot and security paths to fit OCM.
			rewrite_file $cfg_path [list \
				"#define FSBL_NAND_EXCLUDE_VAL\t\t\t(0U)" "#define FSBL_NAND_EXCLUDE_VAL\t\t\t(1U)" \
				"#define FSBL_QSPI_EXCLUDE_VAL\t\t\t(0U)" "#define FSBL_QSPI_EXCLUDE_VAL\t\t\t(1U)" \
				"#define FSBL_SECURE_EXCLUDE_VAL\t\t\t(0U)" "#define FSBL_SECURE_EXCLUDE_VAL\t\t\t(1U)" \
				"#define FSBL_BS_EXCLUDE_VAL\t\t\t\t(0U)" "#define FSBL_BS_EXCLUDE_VAL\t\t\t\t(1U)" \
				"#define FSBL_WDT_EXCLUDE_VAL\t\t\t(0U)" "#define FSBL_WDT_EXCLUDE_VAL\t\t\t(1U)" \
				"#define FSBL_FORCE_ENC_EXCLUDE_VAL\t\t(0U)" "#define FSBL_FORCE_ENC_EXCLUDE_VAL\t\t(1U)" \
			]
		}
		qspi {
			# QSPI boot must keep QSPI and bitstream loading enabled, but can omit
			# unrelated boot and security paths to keep FSBL within OCM.
			rewrite_file $cfg_path [list \
				"#define FSBL_NAND_EXCLUDE_VAL\t\t\t(0U)" "#define FSBL_NAND_EXCLUDE_VAL\t\t\t(1U)" \
				"#define FSBL_SD_EXCLUDE_VAL\t\t\t\t(0U)" "#define FSBL_SD_EXCLUDE_VAL\t\t\t\t(1U)" \
				"#define FSBL_SECURE_EXCLUDE_VAL\t\t\t(0U)" "#define FSBL_SECURE_EXCLUDE_VAL\t\t\t(1U)" \
				"#define FSBL_WDT_EXCLUDE_VAL\t\t\t(0U)" "#define FSBL_WDT_EXCLUDE_VAL\t\t\t(1U)" \
				"#define FSBL_FORCE_ENC_EXCLUDE_VAL\t\t(0U)" "#define FSBL_FORCE_ENC_EXCLUDE_VAL\t\t(1U)" \
			]
		}
		default {
			error "unsupported FSBL boot profile: $profile"
		}
	}
}

proc configure_pmufw_efuse_access {cfg_path enable} {
	if {![file exists $cfg_path]} {
		return
	}

	switch -- $enable {
		0 -
		false -
		no -
		off {
			return
		}
		1 -
		true -
		yes -
		on {
			rewrite_file $cfg_path [list \
				"#define ENABLE_EFUSE_ACCESS\t\t\t\t\t(0U)" "#define ENABLE_EFUSE_ACCESS\t\t\t\t\t(1U)" \
				"#define ENABLE_EFUSE_ACCESS					(0U)" "#define ENABLE_EFUSE_ACCESS					(1U)" \
			]
		}
		default {
			error "unsupported PMUFW efuse access setting: $enable"
		}
	}
}

proc uart_baseaddr {inst} {
	switch -- $inst {
		psu_uart_0 { return 0xFF000000 }
		psu_uart_1 { return 0xFF010000 }
		default { error "unsupported stdio peripheral: $inst" }
	}
}

proc configure_stdio {mss_path xparams_path stdin_inst stdout_inst} {
	set stdin_base [format "0x%08X" [uart_baseaddr $stdin_inst]]
	set stdout_base [format "0x%08X" [uart_baseaddr $stdout_inst]]

	rewrite_file $mss_path [list \
		"PARAMETER stdin = psu_uart_0" "PARAMETER stdin = $stdin_inst" \
		"PARAMETER stdin = psu_uart_1" "PARAMETER stdin = $stdin_inst" \
		"PARAMETER stdout = psu_uart_0" "PARAMETER stdout = $stdout_inst" \
		"PARAMETER stdout = psu_uart_1" "PARAMETER stdout = $stdout_inst" \
	]

	rewrite_file $xparams_path [list \
		"#define STDIN_BASEADDRESS 0xFF000000" "#define STDIN_BASEADDRESS $stdin_base" \
		"#define STDIN_BASEADDRESS 0xFF010000" "#define STDIN_BASEADDRESS $stdin_base" \
		"#define STDOUT_BASEADDRESS 0xFF000000" "#define STDOUT_BASEADDRESS $stdout_base" \
		"#define STDOUT_BASEADDRESS 0xFF010000" "#define STDOUT_BASEADDRESS $stdout_base" \
	]
}

proc first_existing {paths} {
	foreach p $paths {
		if {[file exists $p]} {
			return $p
		}
	}
	return ""
}

proc export_elf {src_candidates dst} {
	set src [first_existing $src_candidates]
	if {$src eq ""} {
		error "missing ELF output for $dst"
	}

	file mkdir [file dirname $dst]
	file copy -force $src $dst
}

if {$hw eq "" || $out_dir eq "" || $fsbl_proc eq "" || $pmufw_proc eq ""} {
	puts "usage: xsct build_zynqmp_bsp.tcl <hw.hdf|hw.xsa> <out_dir> <embeddedsw_repo> <fsbl_proc> <pmufw_proc> ?<fsbl_stdio>? ?<pmufw_stdio>? ?<fsbl_boot_profile>? ?<fsbl_debug_level>? ?<pmufw_enable_efuse_access>?"
	exit 1
}

if {[file exists $out_dir]} {
	file delete -force $out_dir
}
if {$repo_dir ne ""} {
	hsi::set_repo_path $repo_dir
}

file mkdir $out_dir
set hw_dir [file join $out_dir hw_0]
set fsbl_dir [file join $hw_dir zynqmp_fsbl]
set pmufw_dir [file join $hw_dir zynqmp_pmufw]

hsi::open_hw_design $hw

hsi::create_sw_design fsbl_sw -proc $fsbl_proc -os standalone
hsi::add_library xilffs
hsi::add_library xilsecure
hsi::add_library xilpm
hsi::generate_app -dir $fsbl_dir -app zynqmp_fsbl
hsi::close_sw_design [hsi::current_sw_design]

hsi::create_sw_design pmufw_sw -proc $pmufw_proc -os standalone
hsi::add_library xilfpga
hsi::add_library xilsecure
hsi::add_library xilskey
hsi::generate_app -dir $pmufw_dir -app zynqmp_pmufw
hsi::close_sw_design [hsi::current_sw_design]

hsi::close_hw_design [hsi::current_hw_design]

configure_fsbl_boot_profile [file join $fsbl_dir xfsbl_config.h] $fsbl_boot_profile
configure_fsbl_debug [file join $fsbl_dir xfsbl_config.h] $fsbl_debug_level
configure_pmufw_efuse_access [file join $pmufw_dir xpfw_config.h] $pmufw_enable_efuse_access
relocate_fsbl_handoff [file join $fsbl_dir xfsbl_image_header.c]
configure_stdio \
	[file join $fsbl_dir zynqmp_fsbl_bsp fsbl_sw.mss] \
	[file join $fsbl_dir zynqmp_fsbl_bsp $fsbl_proc include xparameters.h] \
	$fsbl_stdio $fsbl_stdio
configure_stdio \
	[file join $pmufw_dir zynqmp_pmufw_bsp pmufw_sw.mss] \
	[file join $pmufw_dir zynqmp_pmufw_bsp $pmufw_proc include xparameters.h] \
	$pmufw_stdio $pmufw_stdio

exit
