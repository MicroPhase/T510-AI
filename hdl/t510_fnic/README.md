# T510-FNIC Aurora Project

This directory contains the initial T510-side FPGA project for FNIC fronthaul
bring-up.  The project now keeps Aurora and the migrated T510_AI PS preset in
the same block design, while still intentionally excluding the larger datapath:

- No 100G Ethernet MAC
- No UDP/IP or RFNoC transport
- No DMA integration yet

The first goal is to bring up a 4-lane Aurora 64B/66B link between FNIC and the
external T510 SDR FPGA.

## Layout

```text
t510_fnic/
  scripts/
    recreate_vivado_project.sh
    vivado/create_t510_fnic_aurora_project.tcl
    vivado/t510_fnic_ps_preset.tcl
  top/t510_fnic/rtl/
    t510_fnic_aurora_bringup_top.v
    t510_fnic_aurora_reset_ctrl.v
  xdc/
    t510_fnic_qsfp0.xdc
    t510_fnic_timing.xdc
  artifacts/t510_fnic_aurora/
    t510_fnic_aurora_bringup_top.bit
    t510_fnic_aurora_bringup_top.xsa
  vivado/project/
```

## Current Hardware Target

| Item | Value |
| --- | --- |
| FPGA part | `xczu47dr-ffve1156-2-i` |
| Port | QSFP0 |
| GT lanes | `X0Y4 X0Y5 X0Y6 X0Y7` |
| Refclk | 156.25 MHz |
| Aurora mode | 64B/66B Streaming |
| Lane count | 4 |
| Initial line rate | 10 Gbps/lane |
| User data width | 256 bit |

The lane and pin mapping is inherited from the existing `t510_ai` QSFP0 100G
project.  The line rate is initially kept at 10 Gbps/lane to match the current
FNIC Aurora bring-up settings.  Move both sides together if changing to
25 Gbps/lane.

## Create Project

```bash
cd hdl/t510_fnic
./scripts/recreate_vivado_project.sh
```

The script creates:

```text
vivado/project/t510_fnic_aurora/t510_fnic_aurora.xpr
```

The generated `t510_fnic_aurora_bd` contains:

- Aurora 64B/66B x4 for QSFP0 bring-up.
- Zynq UltraScale+ PS using the T510_AI MIO/DDR/peripheral preset.
- RFDC using the T510_AI two-channel ADC/DAC configuration.
- PS `M_AXI_HPM0_FPD` to RFDC `s_axi` at `0xA0040000`.
- RFDC AXIS/user clock input `rfdc_user_clk_p/n` on AG17/AH17.
- PS exported PL clocks `pl_clk100`, `pl_clk40`, `pl_clk200`.
- PS exported active-low reset `pl_resetn0`.
- PS EMIO GPIO `gpio_i/gpio_o/gpio_t`.

For this migration step, the RFDC reference clocks, SYSREF, analog pins, and
AXIS sample ports are exposed at the top level.  The RFDC AXIS/user clock is
named separately from the Aurora init clock so the constraints stay explicit.
The bring-up top ties ADC stream ready high and drives DAC streams idle until
the real IQ datapath is connected.

## Bring-Up Behavior

The current top-level does only link bring-up:

- Drives QSFP0 reset and low-power pins.
- Creates an Aurora reset pulse using `init_clk`.
- Sends a simple 32-bit incrementing test pattern over Aurora TX.
- Counts RX valid beats.
- Exposes `channel_up` and RX activity on status outputs.
- Instantiates a 512-bit ILA for Aurora status and data observation.

## Next Steps

1. Confirm `lane_up=4'hf` and `channel_up=1` against the FNIC board.
2. Replace the local TX counter with the SDR-to-FNIC RX IQ packetizer.
3. Add the FNIC `0x5601/0x5602` Aurora CTRL/RESP parser.
4. Connect RFDC ADC/DAC AXIS paths to the FNIC Aurora packetizer.
5. Add DMA or PS-side capture only if the FNIC use case needs it.
