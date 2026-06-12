# T510_FNIC Image Builder

This board object builds the PS-side image for the T510_FNIC FPGA design.

The current image keeps the T510_AI PS/RFDC bring-up pieces that are needed for
RFDC configuration, but does not include the T510_AI 100G Ethernet/NIXGE user
datapath tools.

## Build

```bash
make BOARD=t510-fnic sd
```

The SD boot files are generated under:

```text
build/t510-fnic/sd/
```

The SD flow loads the bitstream from the FAT boot partition:

```text
t510_fnic_aurora_bringup_top.bit
```

## RFDC Control

The rootfs installs:

```bash
t510-fnic-rfdc
```

Show RFDC state:

```bash
t510-fnic-rfdc
```

Set ADC/DAC IF/NCO frequency:

```bash
t510-fnic-rfdc --type adc --tile 0 --block 0 --freq 1850
t510-fnic-rfdc --type dac --tile 0 --block 0 --freq 1850
```

Skip LMK initialization if the clock chip has already been configured:

```bash
t510-fnic-rfdc --skip-lmk-init
```
