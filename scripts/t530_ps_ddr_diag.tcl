# XSCT diagnostic runner for ANTSDR T530 PS DDR bring-up.
#
# Usage:
#   xsct scripts/t530_ps_ddr_diag.tcl
#
# Optional environment variables:
#   T530_PSU_INIT_TCL    path to psu_init.tcl exported by Vivado
#   T530_TARGET_FILTER   XSCT target filter, default: name =~ "PSU"
#   T530_RESET_SYSTEM    set to 1 to run "rst -system" before psu_init
#   T530_POLL_LIMIT      max reads for each poll, default: 20000

set script_root [file normalize [file join [file dirname [info script]] ..]]
set new_psu_init [file join $script_root hdl t530_29dr_ps_only t530_29dr_ps_only.gen sources_1 bd design_1 ip design_1_zynq_ultra_ps_e_0_0 psu_init.tcl]
set legacy_psu_init [file join $script_root hdl t530_29_dr t530_29_dr t530_29_dr.ip_user_files mem_init_files psu_init.tcl]
if {[file exists $new_psu_init]} {
    set default_psu_init [file normalize $new_psu_init]
} else {
    set default_psu_init [file normalize $legacy_psu_init]
}
if {[info exists ::env(T530_PSU_INIT_TCL)]} {
    set psu_init_tcl [file normalize $::env(T530_PSU_INIT_TCL)]
} else {
    set psu_init_tcl $default_psu_init
}

proc fmt32 {value} {
    return [format "0x%08X" [expr {$value & 0xffffffff}]]
}

proc rd32 {addr} {
    set raw [mrd -force $addr]
    if {![regexp {([0-9A-Fa-f]{8})\s*$} $raw -> value]} {
        error "Could not parse mrd output for $addr: $raw"
    }
    return "0x$value"
}

proc dump_reg {name addr} {
    puts [format "  %-18s %s = %s" $name $addr [fmt32 [rd32 $addr]]]
}

proc decode_pgsr0 {value} {
    set fields {
        31 APLOCK
        30 SRDERR
        29 CAWRN
        28 CAERR
        27 WEERR
        26 REERR
        25 WDERR
        24 RDERR
        23 WLAERR
        22 QSGERR
        21 WLERR
        20 ZCERR
        19 VERR
        18 DQS2DQERR
        15 DQS2DQDONE
        14 VDONE
        13 SRDDONE
        12 CADONE
        11 WEDONE
        10 REDONE
        9  WDDONE
        8  RDDONE
        7  WLADONE
        6  QSGDONE
        5  WLDONE
        4  DIDONE
        3  ZCDONE
        2  DCDONE
        1  PLDONE
        0  IDONE
    }
    set names {}
    foreach {bit name} $fields {
        if {[expr {$value & (1 << $bit)}] != 0} {
            lappend names $name
        }
    }
    return [join $names ", "]
}

proc decode_dxgsr0 {value} {
    set fields {
        30 WLDQ
        16 DPLOCK
        6 WLERR
        5 WLDONE
        4 WLCAL
        3 GDQSCAL
        2 RDQSNCAL
        1 RDQSCAL
        0 WDQCAL
    }
    set names {}
    foreach {bit name} $fields {
        if {[expr {$value & (1 << $bit)}] != 0} {
            lappend names $name
        }
    }
    set gdqsprd [expr {($value >> 17) & 0x1ff}]
    set wlprd [expr {($value >> 7) & 0x1ff}]
    return [format "%s GDQSPRD=%d WLPRD=%d" [join $names ","] $gdqsprd $wlprd]
}

proc dump_dx_lane {lane base} {
    set rsr1 [expr {$base + 0xD4}]
    set rsr2 [expr {$base + 0xD8}]
    set rsr3 [expr {$base + 0xDC}]
    set gsr0 [expr {$base + 0xE0}]
    set rsr1_value [rd32 $rsr1]
    set rsr2_value [rd32 $rsr2]
    set rsr3_value [rd32 $rsr3]
    set gsr0_value [rd32 $gsr0]
    puts [format "  DX%dRSR1           %s = %s  RDLVLERR=%d" \
        $lane [fmt32 $rsr1] [fmt32 $rsr1_value] [expr {$rsr1_value & 0x3}]]
    puts [format "  DX%dRSR2           %s = %s  WLAWN=%d" \
        $lane [fmt32 $rsr2] [fmt32 $rsr2_value] [expr {$rsr2_value & 0x3}]]
    puts [format "  DX%dRSR3           %s = %s  WLAERR=%d" \
        $lane [fmt32 $rsr3] [fmt32 $rsr3_value] [expr {$rsr3_value & 0x3}]]
    puts [format "  DX%dGSR0           %s = %s  %s" \
        $lane [fmt32 $gsr0] [fmt32 $gsr0_value] [decode_dxgsr0 $gsr0_value]]
}

proc dump_ddr_regs {} {
    set pgsr0 [rd32 0xFD080030]
    puts "DDR status registers:"
    dump_reg "DDRC_STAT"     0xFD070004
    dump_reg "DDRC_MRSTAT"   0xFD070018
    dump_reg "DDRC_SWSTAT"   0xFD070324
    dump_reg "PHY_PIR"       0xFD080004
    dump_reg "PHY_PGSR0"     0xFD080030
    puts "  PHY_PGSR0_BITS     [decode_pgsr0 $pgsr0]"
    dump_reg "PHY_PGSR1"     0xFD080034
    puts "DDR byte-lane status:"
    dump_dx_lane 0 0xFD080700
    dump_dx_lane 1 0xFD080800
    dump_dx_lane 2 0xFD080900
    dump_dx_lane 3 0xFD080A00
    dump_dx_lane 4 0xFD080B00
    dump_dx_lane 5 0xFD080C00
    dump_dx_lane 6 0xFD080D00
    dump_dx_lane 7 0xFD080E00
}

proc poll_label {addr mask expected default_label} {
    set key [format "0x%08X:0x%08X:0x%08X" [expr {$addr & 0xffffffff}] [expr {$mask & 0xffffffff}] [expr {$expected & 0xffffffff}]]
    array set labels {
        "0xFD080030:0x0000000F:0x0000000F" "DDR PHY internal init done"
        "0xFD080030:0x000000FF:0x0000001F" "DDR PHY init complete"
        "0xFD070018:0x00000001:0x00000000" "DDRC MR command idle"
        "0xFD070004:0x0000000F:0x00000001" "DDRC normal operating mode"
        "0xFD080030:0x00000FFF:0x00000FFF" "DDR PHY main training complete"
        "0xFD080030:0x00004001:0x00004001" "DDR PHY static Vref training complete"
        "0xFD080030:0x00000C01:0x00000C01" "DDR PHY dynamic Vref training complete"
    }
    if {[info exists labels($key)]} {
        return $labels($key)
    }
    return $default_label
}

proc poll_limit {} {
    if {[info exists ::env(T530_POLL_LIMIT)]} {
        return $::env(T530_POLL_LIMIT)
    }
    return 20000
}

proc diag_poll {addr mask expected label {limit ""}} {
    if {$limit eq ""} {
        set limit [poll_limit]
    }
    set label [poll_label $addr $mask $expected $label]
    set count 0
    set curval [rd32 $addr]
    set maskedval [expr {$curval & $mask}]
    while {$maskedval != $expected} {
        incr count
        if {($count % 2000) == 0} {
            puts [format "WAIT    %-34s addr=%s value=%s mask=%s expected=%s got=%s count=%d" \
                $label $addr [fmt32 $curval] [fmt32 $mask] [fmt32 $expected] [fmt32 $maskedval] $count]
        }
        if {$count >= $limit} {
            puts [format "TIMEOUT %-34s addr=%s value=%s mask=%s expected=%s got=%s" \
                $label $addr [fmt32 $curval] [fmt32 $mask] [fmt32 $expected] [fmt32 $maskedval]]
            dump_ddr_regs
            error "DDR diagnostic poll failed: $label"
        }
        set curval [rd32 $addr]
        set maskedval [expr {$curval & $mask}]
    }
    puts [format "OK      %-34s addr=%s value=%s" $label $addr [fmt32 $curval]]
}

proc poll {addr mask data} {
    diag_poll $addr $mask $data "generated poll"
}

proc mask_poll {addr mask} {
    diag_poll $addr $mask $mask "generated mask_poll"
}

proc mem_write_read_check {addr value} {
    mwr -force $addr $value
    set got [rd32 $addr]
    if {[expr {$got & 0xffffffff}] != [expr {$value & 0xffffffff}]} {
        error [format "DDR memory check failed at %s: wrote %s read %s" $addr [fmt32 $value] [fmt32 $got]]
    }
}

proc ddr_smoke_test {} {
    puts "DDR smoke test on low DDR window:"
    foreach {addr value} {
        0x00000000 0x00000000
        0x00000004 0xFFFFFFFF
        0x00000008 0xA5A5A5A5
        0x0000000C 0x5A5A5A5A
        0x00001000 0x12345678
        0x00001004 0x87654321
        0x00100000 0xCAFEBABE
        0x00100004 0x0BADF00D
    } {
        mem_write_read_check $addr $value
        puts [format "  OK %s <= %s" $addr [fmt32 $value]]
    }
}

proc run_t530_ps_ddr_diag {psu_init_tcl} {
    puts "Using psu_init.tcl: $psu_init_tcl"
    if {![file exists $psu_init_tcl]} {
        error "psu_init.tcl not found: $psu_init_tcl"
    }

    if {[catch {connect} err]} {
        puts "connect: $err"
    }

    if {[info exists ::env(T530_TARGET_FILTER)]} {
        set target_filter $::env(T530_TARGET_FILTER)
    } else {
        set target_filter {name =~ "PSU"}
    }
    if {[catch {targets -set -filter $target_filter} err]} {
        puts "Could not select target with filter '$target_filter'. Run 'targets' in xsct and set T530_TARGET_FILTER."
        error $err
    }

    if {[info exists ::env(T530_RESET_SYSTEM)] && $::env(T530_RESET_SYSTEM) eq "1"} {
        puts "Running XSCT system reset before PS DDR init"
        rst -system
        after 1000
        targets -set -filter $target_filter
    }

    uplevel #0 [list source $psu_init_tcl]
    proc poll {addr mask data} {
        diag_poll $addr $mask $data "generated poll"
    }
    proc mask_poll {addr mask} {
        diag_poll $addr $mask $mask "generated mask_poll"
    }

    puts "\nStep 1: PS MIO/peripheral/PLL/clock/DDRC register setup"
    set saved_mode [configparams force-mem-accesses]
    configparams force-mem-accesses 1
    init_ps [subst {$::psu_mio_init_data $::psu_peripherals_pre_init_data $::psu_pll_init_data $::psu_clock_init_data $::psu_ddr_init_data}]
    dump_ddr_regs

    puts "\nStep 2: DDR PHY bring-up and training"
    psu_ddr_phybringup_data
    dump_ddr_regs

    puts "\nStep 3: basic DDR read/write check"
    ddr_smoke_test
    configparams force-mem-accesses $saved_mode
    puts "\nT530 PS DDR diagnostic completed successfully."
}

run_t530_ps_ddr_diag $psu_init_tcl
