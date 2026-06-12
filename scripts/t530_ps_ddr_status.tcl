# Read current PS DDR controller/PHY status through XSCT.
#
# Usage:
#   /opt/Xilinx/Vitis/2022.2/bin/xsct scripts/t530_ps_ddr_status.tcl

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
    puts [format "%-18s %s = %s" $name $addr [fmt32 [rd32 $addr]]]
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
        10 REDONE
        9  WEDONE
        8  RDDONE
        7  WLDONE
        6  QSGDONE
        5  WLADONE
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

if {[catch {connect} err]} {
    puts "connect: $err"
}

if {[info exists ::env(T530_TARGET_FILTER)]} {
    set target_filter $::env(T530_TARGET_FILTER)
} else {
    set target_filter {name =~ "PSU"}
}
targets -set -filter $target_filter
configparams force-mem-accesses 1

set pgsr0 [rd32 0xFD080030]
dump_reg "DDRC_STAT"     0xFD070004
dump_reg "DDRC_MRSTAT"   0xFD070018
dump_reg "DDRC_SWSTAT"   0xFD070324
dump_reg "PHY_PIR"       0xFD080004
dump_reg "PHY_PGSR0"     0xFD080030
puts "PHY_PGSR0_BITS     [decode_pgsr0 $pgsr0]"
dump_reg "PHY_PGSR1"     0xFD080034
dump_reg "PHY_DX0GSR0"   0xFD0807E0
dump_reg "PHY_DX1GSR0"   0xFD0808E0
dump_reg "PHY_DX2GSR0"   0xFD0809E0
dump_reg "PHY_DX3GSR0"   0xFD080AE0
dump_reg "PHY_DX4GSR0"   0xFD080BE0
dump_reg "PHY_DX5GSR0"   0xFD080CE0
dump_reg "PHY_DX6GSR0"   0xFD080DE0
dump_reg "PHY_DX7GSR0"   0xFD080EE0
