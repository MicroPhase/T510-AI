# t510-fnic-rfdc

`t510-fnic-rfdc` 是 T510_FNIC 板端 PS 用户态 RFDC/LMK 控制程序。

这个程序参考了 T510_AI 的 `app_rfdc`，但当前 T510_FNIC 控制面已经切换到 FNIC/XDMA/Aurora/PL mailbox/PS mailbox 链路。旧的 100G UDP remote server 和依赖 PL `sdr_ctrl` register block 的处理路径已经从当前板端程序中移除。

## 当前功能

- 通过 `/dev/spidev1.0` 初始化 LMK04828。
- 通过 XSA 生成的 Linux device-tree RFDC 节点初始化 RFDC。
- 打印 ADC/DAC tile 和 block 状态。
- 命令行设置 ADC/DAC IF/NCO 频率。
- 轮询 PL mailbox，处理 FNIC/Aurora 侧发来的控制命令，并写回响应。

## 构建

在仓库根目录执行：

```bash
make -C board/t510-fnic/app_rfdc
```

如果当前主机没有 Buildroot sysroot 和 `libmetal`，直接用 host gcc 构建会失败。正常镜像构建时，Buildroot 会在启用 `BR2_PACKAGE_T510_FNIC_RFDC=y` 后自动交叉编译并安装该程序。

也可以显式使用 CMake：

```bash
cmake -S board/t510-fnic/app_rfdc -B board/t510-fnic/app_rfdc/build
cmake --build board/t510-fnic/app_rfdc/build -j$(nproc)
```

## 常用运行方式

打印 RFDC 状态：

```bash
t510-fnic-rfdc
```

跳过 LMK 初始化：

```bash
t510-fnic-rfdc --skip-lmk-init
```

设置 ADC/DAC IF/NCO 频率：

```bash
t510-fnic-rfdc --type adc --tile 0 --block 0 --freq 1850
t510-fnic-rfdc --type dac --tile 0 --block 0 --freq 1850
```

启动 FNIC mailbox 轮询服务：

```bash
t510-fnic-rfdc --skip-lmk-init --no-dump --mailbox-server
```

如果 BD 中 AXI-Lite 基地址发生变化，可以覆盖默认地址：

```bash
t510-fnic-rfdc --skip-lmk-init --no-dump --mailbox-server --mailbox-base 0xA0000000
```

也可以用环境变量覆盖：

```bash
APP_RFDC_MAILBOX_BASE_ADDR=0xA0000000 t510-fnic-rfdc --skip-lmk-init --no-dump --mailbox-server
```

## Mailbox 命令

当前 mailbox 基地址默认为 `0xA0000000`。PS 程序启动后会先读取 `MAILBOX_ID`，期望值为 `0x544d424f`。

第一阶段支持的命令如下：

| 命令 | 值 | 说明 |
| --- | --- | --- |
| `NOP` | `0x0000` | 空操作 |
| `GET_VERSION` | `0x0001` | 返回协议版本和 build ID |
| `WRITE_REG` | `0x0002` | `arg0=reg`，`arg1/arg2=value64` |
| `READ_REG` | `0x0003` | `arg0=reg`，返回 64-bit 值 |
| `PING` | `0x00010001` | 回显 `arg0`，并返回 `"PONG"` |
| `SET_RX_FREQ` | `0x00010100` | `arg1/arg2=rx_lo_hz` |
| `GET_RX_FREQ` | `0x00010101` | 返回当前 `rx_lo_hz` |
| `SET_TX_FREQ` | `0x00010102` | `arg1/arg2=tx_lo_hz` |
| `GET_TX_FREQ` | `0x00010103` | 返回当前 `tx_lo_hz` |

`WRITE_REG` 当前保留旧 T510_AI 的少量状态/频率寄存器兼容，包括拆分 LO 寄存器 `0x0008/0x0009`、`0x000a/0x000b`，也支持新的 64-bit 单次写寄存器：

| 寄存器 | 说明 |
| --- | --- |
| `0x0031` | RX LO Hz，64-bit |
| `0x0032` | TX LO Hz，64-bit |

以前通过 UDP server 下发、并最终访问 PL `sdr_ctrl` register block 的命令已经不再执行；例如 VITA time、RX stream start/stop、capture start、rx max packet bytes 等动作会返回 `DENIED`。后续如需这些功能，应在 FNIC mailbox 协议中重新定义明确的 PS/RFDC 或 PL 控制命令。
