# app_rfdc

这是当前 `T510-AI IQ 采集系统` 的下位机控制程序。

## 作用

`app_rfdc` 只负责控制面，不负责 IQ 数据转发。

它做两件事：

- RFDC 控制
  - 频点
  - 采样率
  - 增益
- FPGA 控制
  - 时间戳
  - RX 模式
  - 单次采集触发
  - 连续采集开始/停止
  - 采集总字节数
  - 每包最大字节数

IQ 数据本身由 FPGA 直接通过 100G 发到上位机。

当前 FPGA 数据主路径是：

```text
ADC -> t510_ai_iq_capture -> iq_framework_wrapper.user_bus_rx_* -> 100G
```

当前启动时会先做一轮默认 RFDC bring-up，配置思路参考裸机工程
[antsdr_t510_rf_loop_app](../vitis/antsdr_t510_rf_loop_app/src/main.c)：

- reset 已使能的 ADC/DAC tile
- DAC `VOP=40500uA`
- ADC `DSA=0dB` 并打开 dither
- 默认 ADC/DAC NCO `1500 MHz`
- 按 `245.76 MHz` 基带速率设置抽取/插值
- ADC QMC 默认使能增益校正

这版 Linux 用户层没有做裸机程序里的多 tile `MTS sync`，因为当前 FPGA 默认只使能了两个通道，也不要求多通道同步。

当前动态改频路径已经按 `PG269 RF Data Converter Product Guide` 的 `NCO Frequency Conversion`
规则实现：

- 会先根据当前 block 采样率判断目标频率落在奇数还是偶数奈奎斯特区
- 会同时更新 `NyquistZone`、`MixerMode`、`MixerSettings.Freq`
- 对 `ADC` 下变频：
  - 偶数区使用正 NCO
  - 奇数区使用负 NCO
- 对 `DAC` 上变频则相反

所以用户层和上位机传入的频率都保持为“正常正频率语义”，不需要手工根据奈奎斯特区给
`--freq` 传正负号。实际写入 RFDC 的有效 signed NCO 由
[app_rfdc_set_if_frequency()](rfdc_platform.c#L147)
自动决定。

LMK 部分现在也接进了应用层 GPIO 控制：

- `LMK_RESET` 默认 GPIO `29`
- `LMK_SYNC` 默认 GPIO `78`

这两个默认值直接沿用裸机工程里的定义。

## 当前结构

- [main.c](main.c)
  - 程序入口和控制协议分发
- [rfdc_platform.c](rfdc_platform.c)
  - RFDC 初始化和寄存器访问
- [sdr_ctrl.c](sdr_ctrl.c)
  - `axi_center_control` 的 `/dev/mem` 映射和控制
- [remote_ctrl.c](remote_ctrl.c)
  - control port 的 32 字节固定 UDP 协议
- [remote_regs.h](remote_regs.h)
  - 上下位机共用的控制地址定义
- [app_gpio.c](app_gpio.c)
  - Linux 用户层 GPIO 抽象，方便控制 MIO/EMIO

## 构建

```bash
make -C board/t510-ai/app_rfdc
```

产物：

[app_rfdc](build/app_rfdc)

## 运行前提

板上建议用 `root` 运行，因为程序会访问：

- `/dev/spidev1.0`
- `/dev/mem`
- `/dev/gpiochip*`

## 常用命令

查看当前 RFDC 状态：

```bash
./app_rfdc
```

修改 ADC/DAC NCO：

```bash
./app_rfdc --type adc --tile 0 --block 0 --freq 122.88
./app_rfdc --type dac --tile 0 --block 0 --freq 122.88
```

跳过 LMK 初始化：

```bash
./app_rfdc --skip-lmk-init
```

显式指定 LMK GPIO：

```bash
./app_rfdc --lmk-reset-gpio 29 --lmk-sync-gpio 78
```

如果要显式指定 GPIO 控制器：

```bash
export APP_RFDC_GPIOCHIP=/dev/gpiochip1
./app_rfdc --server
```

启动控制服务：

```bash
./app_rfdc --server --no-dump
```

显式指定控制端口：

```bash
./app_rfdc --server --ctrl-port 49208 --no-dump
```

## 控制协议

当前只使用一个 control port：

```text
49208
```

协议格式和上位机 `local_ctrl` 对齐：

- `PACKET_TYPE_CTRL = 0x5501`
- `PACKET_TYPE_RESP = 0x5502`
- 包长固定 `32` 字节

32 字节控制包字段：

```text
offset  size  field
0       8     header: magic_type[63:48], seq[47:32], sid[31:24], length[23:0]
8       8     timestamp
16      2     cmd_id
18      1     flags
19      1     target
20      4     arg0
24      4     arg1
28      4     arg2
```

当前命令：

- `0x0000` NOP
- `0x0001` GET_VERSION
- `0x0002` WRITE_REG: `arg0=addr`, `arg1=data`
- `0x0003` READ_REG: `arg0=readback selector`

32 字节响应包字段：

```text
offset  size  field
0       8     header: magic_type=0x5502, seq, sid, length=32
8       8     timestamp
16      2     cmd_id
18      2     status
20      4     value0
24      4     value1
28      4     value2
```

`value0/value1` 组成 64 位 readback 返回值，`status=0` 表示成功。

## 当前已经接通的控制项

RFDC 相关：

- RX/TX 频点
- 采样率
- 增益

频率语义说明：

- `app_rfdc` 对外使用的是正常的 `IF/NCO frequency` 语义
- 当前直采链路里，上位机的 `center_freq` 最终会直接映射到这里
- 但板端不会把这个值原样塞给 `MixerSettings.Freq`
- 板端会根据 `PG269` 和奈奎斯特区自动换算 signed NCO，避免频谱方向错误

FPGA 相关：

- 时间戳
- channel enable
- `rx_mode`
- 单次采集
- 连续采集开始/停止
- `rx_sample_bytes`
- `max_sample_bytes_per_packet`
- `start-rx` / `stop-rx`

当前已经删除的内容：

- 原始 RFDC 寄存器窗口转发
- 原始 CTRL 寄存器窗口转发
- TX noise / DDS / XFFT 这类当前采集闭环没用到的高级语义

## 包长度约束

`max_sample_bytes_per_packet` 现在由上下位机统一处理：

- 最小 `8`
- 最大 `8192`
- 默认 `8160`
- 自动按 `8` 字节对齐

这样可以保证当前 `9000` MTU 下，经过 `CHDR + IQ 内部头` 封装后仍然落在安全范围内。
当前版本已经实测 `8160` 可以保证单次 `4MB` 采集连续，`8192` 不再作为默认值使用。

## 相关板级地址

`axi_center_control` 默认基地址：

```text
0xA00C0000
```

也可以通过环境变量覆盖：

```bash
export APP_RFDC_CTRL_BASE_ADDR=0xA00C0000
```

## 当前边界

- `app_rfdc` 只做控制面
- IQ 数据面完全交给 FPGA + 100G + 主机 DPDK
- 当前优先支持 RX 采集闭环

## 当前状态

截至当前版本，频率链已经按 `PG269` 对齐并做过实测：

- `1850 MHz` 中心频率工作正常
- `2600 MHz` 中心频率工作正常

当前已经确认：

- 之前出现的频谱镜像问题，根因在 RFDC 频率设置没有按 `Nyquist + signed NCO` 规则处理
- 根因不在主机 `.cs16` 落盘
- 根因不在 FPGA 的 CHDR 或 IQ 组包
