# T510_FNIC PS Mailbox 设计说明

本文档描述 T510_FNIC 第一版 PL/PS mailbox，用于把 FNIC/Aurora 侧的控制请求送到 PS，再把 PS 生成的响应返回给 FNIC/Aurora。

当前实现文件：

```text
hdl/t510_fnic/top/t510_fnic/rtl/axi_peek_poke_v1_0_S00_AXI.v
```

这个文件保留了原来的 AXI-Lite slave 模块名，但功能已经不再是通用 peek/poke register bank，而是一个 single-outstanding mailbox。用户明确要求当前只使用这个文件，不依赖原 Vivado IP 外围模块；后续外围模块可以自己添加。

## 地址

当前 BD 中该 AXI-Lite slave 的基地址为：

```text
0x00_A000_0000
```

PS Linux 上的最小 smoke test：

```sh
devmem 0xA000007c 32
```

期望读到：

```text
0x544d424f
```

该值是 `MAILBOX_ID`，ASCII 可理解为 `"TMBO"`。

## 时钟和 CDC

AXI-Lite 接口和 `pl_cmd_*` / `pl_resp_*` 端口都同步于 `S_AXI_ACLK`。

如果 Aurora 控制解析逻辑运行在 `aurora_user_clk`，需要在接入 mailbox 前后做 CDC：

- Aurora/control PL 到 mailbox：建议使用一个小 async FIFO，打包 `seq/op/arg0..arg3`。
- mailbox 到 Aurora/control PL：建议再使用一个小 async FIFO，打包 `seq/status/data0..data3`。

## PL 侧接口

请求方向，从 Aurora/control PL 进入 mailbox：

```verilog
input  wire        pl_cmd_valid;
output wire        pl_cmd_ready;
input  wire [31:0] pl_cmd_seq;
input  wire [31:0] pl_cmd_op;
input  wire [31:0] pl_cmd_arg0;
input  wire [31:0] pl_cmd_arg1;
input  wire [31:0] pl_cmd_arg2;
input  wire [31:0] pl_cmd_arg3;
```

`pl_cmd_valid && pl_cmd_ready` 时，mailbox 捕获一条命令。

响应方向，从 mailbox 返回 Aurora/control PL：

```verilog
output wire        pl_resp_valid;
input  wire        pl_resp_ready;
output wire [31:0] pl_resp_seq;
output wire [31:0] pl_resp_status;
output wire [31:0] pl_resp_data0;
output wire [31:0] pl_resp_data1;
output wire [31:0] pl_resp_data2;
output wire [31:0] pl_resp_data3;
```

`pl_resp_valid && pl_resp_ready` 时，mailbox 清除一条响应。

`pl_cmd_ready` 只有在没有待处理命令、PS 不忙、没有待取走响应时才为 1。因此该模块一次只允许一条未完成命令，避免 PS 覆盖上一条响应。

## 寄存器表

以下 offset 均相对于 `0xA0000000`。

| Offset | 名称 | 访问 | 说明 |
| --- | --- | --- | --- |
| `0x00` | `STATUS` | RO | Mailbox 状态位 |
| `0x04` | `CONTROL` | WO | PS 写 one-shot 控制位 |
| `0x08` | `CMD_SEQ` | RO | PL 命令序号 |
| `0x0c` | `CMD_OP` | RO | PL 命令 opcode |
| `0x10` | `CMD_ARG0` | RO | 命令参数 0 |
| `0x14` | `CMD_ARG1` | RO | 命令参数 1 |
| `0x18` | `CMD_ARG2` | RO | 命令参数 2 |
| `0x1c` | `CMD_ARG3` | RO | 命令参数 3 |
| `0x20` | `RESP_SEQ` | RW | 响应序号，通常复制 `CMD_SEQ` |
| `0x24` | `RESP_STATUS` | RW | 响应状态码 |
| `0x28` | `RESP_DATA0` | RW | 响应数据 0 |
| `0x2c` | `RESP_DATA1` | RW | 响应数据 1 |
| `0x30` | `RESP_DATA2` | RW | 响应数据 2 |
| `0x34` | `RESP_DATA3` | RW | 响应数据 3 |
| `0x40` | `ACCEPT_COUNT` | RO | 已接收 PL 命令计数 |
| `0x44` | `OVERFLOW_COUNT` | RO | PL 在 mailbox 不可用时尝试发命令的计数 |
| `0x48` | `RESP_COMMIT_COUNT` | RO | PS 提交响应计数 |
| `0x4c` | `RESP_CONSUME_COUNT` | RO | PL 取走响应计数 |
| `0x7c` | `MAILBOX_ID` | RO | 固定 ID，`0x544d424f` |

### STATUS 位

| Bit | 名称 | 说明 |
| --- | --- | --- |
| 0 | `cmd_valid` | PL 已投递一条命令，等待 PS 读取 |
| 1 | `resp_valid` | PS 已提交一条响应，等待 PL 取走 |
| 3 | `cmd_overflow` | PL 在 mailbox 不可用时尝试发送命令，sticky |
| 4 | `busy` | PS 已 ack 命令，但还没有提交响应 |
| 5 | `cmd_valid_dbg` | bit 0 的调试副本 |
| 6 | `resp_valid_dbg` | bit 1 的调试副本 |

### CONTROL 位

| Bit | 名称 | PS 动作 |
| --- | --- | --- |
| 0 | `cmd_ack` | PS 读完 `CMD_*` 后写 1，清 `cmd_valid` 并置 `busy` |
| 1 | `resp_commit` | PS 写完 `RESP_*` 后写 1，置 `resp_valid` 并清 `busy` |
| 2 | `resp_ack_sw` | 软件强制清 `resp_valid`，主要用于恢复和调试 |
| 3 | `clear_overflow` | 清 sticky `cmd_overflow` |
| 4 | `clear_counters` | 清调试计数器 |

## PS 轮询流程

当前 PS 侧程序已加入：

```text
board/t510-fnic/app_rfdc/app_mailbox.c
board/t510-fnic/app_rfdc/app_mailbox.h
board/t510-fnic/app_rfdc/main.c
```

启动方式：

```sh
t510-fnic-rfdc --skip-lmk-init --no-dump --mailbox-server
```

如果 BD 地址变化，可以使用：

```sh
t510-fnic-rfdc --skip-lmk-init --no-dump --mailbox-server --mailbox-base 0xA0000000
```

也可以通过 `APP_RFDC_MAILBOX_BASE_ADDR` 环境变量覆盖。

轮询逻辑如下：

1. 读取 `STATUS`。
2. 如果 `cmd_valid=0`，短暂 `usleep` 后继续轮询。
3. 如果 `cmd_valid=1`，读取 `CMD_SEQ/CMD_OP/CMD_ARG0..3`。
4. 写 `CONTROL.cmd_ack=1`，告诉 PL 命令已被 PS 接收。
5. PS 执行命令，例如设置 RFDC NCO/LO。
6. 写 `RESP_SEQ/RESP_STATUS/RESP_DATA0..3`。
7. 写 `CONTROL.resp_commit=1`，让 PL 侧看到 `pl_resp_valid=1`。

## 命令协议

状态码采用 FNIC XDMA control 风格：

| 状态 | 值 | 说明 |
| --- | --- | --- |
| `OK` | `0x0000` | 成功 |
| `BAD_CMD` | `0x0003` | 不支持的命令 |
| `DENIED` | `0x0006` | 当前 PS 程序不能执行该命令 |

第一阶段 PS daemon 支持以下命令：

| Opcode | 名称 | 参数 | 响应 |
| --- | --- | --- | --- |
| `0x00000000` | `NOP` | 无 | `OK` |
| `0x00000001` | `GET_VERSION` | 无 | `data0=protocol_version`，`data1=build_id` |
| `0x00000002` | `WRITE_REG` | `arg0=reg`，`arg1/arg2=value64` | `data0/data1=result64` |
| `0x00000003` | `READ_REG` | `arg0=reg` | `data0/data1=value64` |
| `0x00010001` | `PING` | `arg0=echo` | `data0=arg0`，`data1=0x504f4e47` |
| `0x00010100` | `SET_RX_FREQ` | `arg1/arg2=rx_lo_hz` | `data0/data1=rx_lo_hz` |
| `0x00010101` | `GET_RX_FREQ` | 无 | `data0/data1=rx_lo_hz` |

`WRITE_REG` 支持旧 T510_AI 拆分 LO 寄存器，也支持新的 64-bit 单次写寄存器：

| Register | 含义 |
| --- | --- |
| `0x0008/0x0009` | RX LO low/high split write |
| `0x000a/0x000b` | TX LO low/high split write |
| `0x0031` | RX LO Hz，64-bit |
| `0x0032` | TX LO Hz，64-bit |

## Aurora 接入

当前 bring-up top 已把 mailbox 接入 Aurora 链路：

```text
Aurora RX 0x5601 CTRL
  -> t510_fnic_aurora_ctrl_parser_256   (aurora_user_clk)
  -> async FIFO                         (aurora_user_clk -> ps_pl_clk40)
  -> axi_peek_poke_v1_0_S00_AXI mailbox (ps_pl_clk40)
  -> async FIFO                         (ps_pl_clk40 -> aurora_user_clk)
  -> t510_fnic_aurora_resp_builder_256  (aurora_user_clk)
  -> Aurora TX 0x5602 RESP
```

`t510_fnic_aurora_bringup_top.v` 中还把 BD 导出的 `axi_peek_poke_*` AXI-Lite master 端口直接接到了这个 mailbox slave。该 AXI-Lite 口的 BD clock domain 是 `pl_clk40`，所以 mailbox 的 `S_AXI_ACLK` 使用 `ps_pl_clk40`，复位使用 `ps_pl_resetn0`。

Aurora 控制包采用 32-byte 单拍格式，沿用 FNIC XDMA control packet 字段，但 magic 使用 Aurora bring-up 中的 `0x56xx` 系列：

| 包 | magic_type | 方向 | 长度 |
| --- | --- | --- | --- |
| CTRL | `0x5601` | Aurora RX -> PS mailbox | 32 bytes |
| RESP | `0x5602` | PS mailbox -> Aurora TX | 32 bytes |

CTRL 包在 256-bit Aurora RX 上一拍完成：

```text
[63:48]   magic_type = 0x5601
[47:32]   seq
[31:24]   sid
[23:0]    length = 32
[127:64]  timestamp，当前 parser 忽略
[143:128] cmd_id
[151:144] flags
[159:152] target
[191:160] arg0
[223:192] arg1
[255:224] arg2
```

parser 写入 mailbox 的映射：

| mailbox 字段 | 来源 |
| --- | --- |
| `CMD_SEQ` | `{8'd0, sid, seq}` |
| `CMD_OP` | `{16'd0, cmd_id}` |
| `CMD_ARG0` | `arg0` |
| `CMD_ARG1` | `arg1` |
| `CMD_ARG2` | `arg2` |
| `CMD_ARG3` | `{cmd_id, target, flags}` |

为了兼容 PS mailbox 里的 32-bit direct op，parser 对部分 16-bit Aurora `cmd_id` 做如下映射：

| Aurora `cmd_id` | Mailbox `CMD_OP` | 说明 |
| --- | --- | --- |
| `0x0000` | `0x00000000` | `NOP` |
| `0x0001` | `0x00000001` | `GET_VERSION` |
| `0x0002` | `0x00000002` | `WRITE_REG` |
| `0x0003` | `0x00000003` | `READ_REG` |
| `0x0100` | `0x00010100` | `SET_RX_FREQ` |
| `0x0101` | `0x00010101` | `GET_RX_FREQ` |
| `0x7f01` | `0x00010001` | `PING`，bring-up/debug 用 |

RESP 包也在 256-bit Aurora TX 上一拍完成：

```text
[63:48]   magic_type = 0x5602
[47:32]   seq，来自 CMD_SEQ[15:0]
[31:24]   sid，来自 CMD_SEQ[23:16]
[23:0]    length = 32
[127:64]  timestamp，当前填 0
[143:128] cmd_id，来自 RESP_DATA3[15:0]
[159:144] status，来自 RESP_STATUS[15:0]
[191:160] value0，来自 RESP_DATA0
[223:192] value1，来自 RESP_DATA1
[255:224] value2，来自 RESP_DATA2
```

PS 程序在 `handle_mailbox_cmd()` 中会把原 Aurora `cmd_id` 写入 `RESP_DATA3[15:0]`，用于 RESP builder 回填 `cmd_id`。如果命令不是从 Aurora parser 进入，PS 会退回使用 `CMD_OP[15:0]`。

Aurora TX mux 中，RESP 包优先级高于 RX IQ 数据包；当 `aurora_resp_tvalid=1` 且 Aurora TX `tready=1` 时先发送响应。这样控制响应不会被长 IQ 包永久挡住，但在控制压力较高时会短暂插入到数据流之间，远端接收端需要按 `magic_type` 分流。

建议 bring-up 顺序：

1. 先读 `MAILBOX_ID`。
2. 用 `cmd_id=0x7f01` 的 `PING` 验证 Aurora 到 PL mailbox 到 PS 再返回 Aurora 的闭环。
3. 用 `GET_VERSION` 验证 PS 程序协议版本。
4. 再接入 `SET_RX_FREQ` / `WRITE_REG` 等 RFDC 控制命令。

## 仿真

仿真目录：

```text
hdl/t510_fnic/sim/axi_peek_poke_mailbox/
```

运行：

```sh
hdl/t510_fnic/sim/axi_peek_poke_mailbox/run_xsim.sh
```

testbench 覆盖：

- reset 和 `MAILBOX_ID`
- PL 命令 capture
- PS 读取 `CMD_*`
- PS `cmd_ack`
- `busy` 状态
- response pending 时禁止接收下一条命令
- overflow sticky bit 和计数
- PS 写响应并 `resp_commit`
- PL 取走响应
- 调试计数器清零
