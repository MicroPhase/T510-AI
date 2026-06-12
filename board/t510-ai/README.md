# T510-AI

这是 `T510-AI` 的板级上手说明。第一次接手这块板子，先看这份文档即可。

## 这块板子当前提供什么

当前镜像包含这些关键能力：

- Linux、U-Boot、FSBL、PMUFW、ATF、Buildroot 可独立源码构建
- `eth0` 默认静态 IP 为 `192.168.1.10/24`
- `eth0` 的 MAC 地址由 QSPI flash 唯一 ID 派生
- `eth1` 默认静态 IP 为 `192.168.10.3/24`
- `eth1` 的 UOE 配置会自动同步到 FPGA，默认 UDP 端口 `49200`
- `eth0` / `eth1` 的网络配置可掉电保存
- 提供 Linux 用户态的 RFDC 示例程序 [app_rfdc](app_rfdc/README.md)

## 构建前准备

### 1. 准备 Xilinx 工具

当前工程按 `Vivado/Vitis 2022.2` 组织。至少要能使用：

- `xsct`
- `bootgen`

通常这样设置：

```bash
export VIVADO_SETTINGS=/opt/Xilinx/Vivado/2022.2/settings64.sh
```

### 2. 准备硬件导出物

默认文件名和路径由 [board.mk](board.mk) 固定：

- [t510_ai_100g_full_system_top.xsa](../../hdl/t510_ai/artifacts/t510_ai_100g_full_system/t510_ai_100g_full_system_top.xsa)
- [t510_ai_100g_full_system_top.bit](../../hdl/t510_ai/artifacts/t510_ai_100g_full_system/t510_ai_100g_full_system_top.bit)

如果你手上的文件名或目录不同，改 [board.mk](board.mk) 即可。

### 3. 可选：覆盖交叉编译器路径

这块板子的默认交叉编译器路径写在 [board.mk](board.mk) 里。如果你机器上的安装路径不同，可以在构建时覆盖：

```bash
make BOARD=t510-ai \
  CROSS_COMPILE=/path/to/aarch64-linux-gnu- \
  ATF_CROSS_COMPILE=/path/to/aarch64-none-elf-
```

## 最小构建流程

直接构建完整镜像：

```bash
make BOARD=t510-ai
```

分两步：

```bash
make fetch BOARD=t510-ai
make BOARD=t510-ai
```

常用输出目录：

- `build/t510-ai/BOOT.BIN`
- `build/t510-ai/image.ub`
- `build/t510-ai/sd/`
- `build/t510-ai/qspi/`

## SD 卡启动文件

最常用的是 `build/t510-ai/sd/` 目录，里面通常包括：

- `BOOT.bin`
- `t510_ai_100g_full_system_top.bit`
- `Image`
- `devicetree.dtb`
- `uramdisk.image.gz`
- `uEnv.txt`

当前这块板子的 `BOOT.bin` 不再内嵌 PL bitstream，U-Boot 会在 SD 启动阶段单独加载 `t510_ai_100g_full_system_top.bit`。

如果你只是更新 Linux 或 rootfs，通常替换这几个文件即可；如果你更新了 FPGA，也要同步替换这份 `.bit`。

## 板上默认行为

### 串口

- 默认控制台选择 `PS UART1`
- Linux 登录终端对应 `ttyPS0`

### 网络

`eth0`：

- 默认 `192.168.1.10/24`
- MAC 来自 QSPI flash 唯一 ID
- 配置文件保存在 `/boot/network/eth0.conf`

`eth1`：

- 默认 `192.168.10.3/24`
- UOE 默认 UDP 端口 `49200`
- 配置文件保存在 `/boot/network/eth1.conf`
- 接口 IP 变化时会自动同步 FPGA 侧 UOE 寄存器

PL 控制地址：

- 100G 以太网控制 AXI-Lite 基地址：`0xA0000000`
- RFDC 寄存器 AXI-Lite 基地址：`0xA0040000`
- DMA Lite 基地址：`0xA0080000`
- `axi_center_control` 基地址：`0xA00C0000`

板上常用命令：

```bash
show-network-config
persist-current-net
reset-network-config
nixge-uoe-sync status
```

## 与板子直接相关的源码入口

最常改的几个文件：

- [board.mk](board.mk): 板级构建入口
- [system-user.dtsi](linux/system-user.dtsi): 设备树补充
- [defconfig](buildroot/defconfig): Buildroot 配置
- [post-build.sh](buildroot/post-build.sh): rootfs 安装、启动脚本、网络逻辑
- `board/t510-ai/patches/linux/`: Linux patch
- `board/t510-ai/patches/buildroot/`: Buildroot patch

## 板级工具和示例

### `set_eth_params_direct`

镜像里只交付预编译二进制，用于在授权校验通过后，把 `eth1` 的 IP / UDP 端口同步到 FPGA UOE。授权文件默认放在 `/etc/t510-ai/eth-auth.txt`，由内部出厂工具根据 QSPI UID 和 ZynqMP DNA 生成。

内部说明见：
[apps/README.md](apps/README.md)

### `app_rfdc`

这是 Linux 用户态的 RFDC 示例，已经带了本地 `xrfdc` 源码和 `LMK04828` 初始化代码。

说明见：
[app_rfdc/README.md](app_rfdc/README.md)

## 初次上板建议检查

重烧镜像后，先确认这些点：

```bash
ifconfig
show-network-config
ls -l /dev/spidev*
./app_rfdc --skip-lmk-init
```

如果要检查 QSPI unique ID：

```bash
cat /sys/bus/spi/devices/spi0.0/spi-nor/unique_id
```

如果要检查 `eth1` 到 FPGA 的 UOE 同步：

```bash
nixge-uoe-sync status
tail -f /var/log/nixge-uoe-sync.log
```
