# T510_AI_DPDK

这个目录现在只保留 `T510-AI` 的 GUI 上位机程序，以及它依赖的 DPDK / 控制面库代码。

当前主程序是：

- `t510_ai_gui`

已经移除的内容：

- 旧的 CLI 示例程序
- IQ payload 仿真小工具

## 目录

- `gui/src/`
  - GUI 主程序
- `src/core/`, `src/device/`, `src/transport/`
  - GUI 依赖的底层库
- `include/`
  - 对应头文件
- `tools/build_release.sh`
  - 常规构建 GUI
- `tools/build_asan_gui.sh`
  - ASan/UBSan 调试构建
- `tools/run_gui_gdb.sh`
  - 用 gdb 启动 GUI

源码清单见 [SOURCE_LAYOUT.md](SOURCE_LAYOUT.md)。

## 功能边界

当前 GUI 负责：

- 连接 FPGA control path 和 100G DPDK data path
- 设置 `channel enable`
- 设置 `RX/TX center freq`
- 设置 `RX/TX gain`
- 设置 / 读取时间戳
- `Capture Once`
- `Start Stream (4MB Loop)`
- `Start Record`
- `Start Drain Test`
- 显示时域、频谱、瀑布图和连续性统计

当前限制：

- 采样率固定为 `245.76 MHz`
- GUI 中不再提供运行时改采样率

## 构建依赖

需要本机已安装：

- `cmake`
- `g++`
- `pkg-config`
- `libdpdk`
- `glfw3`
- `glew`
- `OpenGL`

程序通过 `pkg-config` 查找：

- `libdpdk`
- `glfw3`
- `glew`

## DPDK 运行前准备

### 1. 选择数据口

程序通过环境变量指定 DPDK 口的 PCI BDF：

```bash
export IQ_TAXI_DPDK_PCI_ADDR=0000:01:00.0
```

代码默认值也是这个地址。如果你的网卡不是这个 BDF，必须改成实际值。

### 2. 设置本机 DPDK 侧 IP

```bash
export IQ_TAXI_DPDK_LOCAL_IP=192.168.10.10
```

这是 host 侧 100G 数据面的本机 IP。GUI 连接板端后，板端会向这个 IP 回发 IQ / control 相关数据。

### 3. 选择 DPDK CPU 核

```bash
export IQ_TAXI_DPDK_CORELIST=1-2
```

这是传给 DPDK EAL 的 `-l` 参数。至少给 2 个逻辑核比较稳妥。

### 4. Hugepage

当前程序支持两种模式：

- 推荐：配置 hugepage 后正常跑 DPDK
- 兜底：没配 hugepage 时，程序会自动走 `--no-huge --in-memory`

推荐先配置 hugepage，例如：

```bash
echo 1024 | sudo tee /proc/sys/vm/nr_hugepages
grep Huge /proc/meminfo
```

如果你当前只想先跑通，也可以显式指定：

```bash
export IQ_TAXI_DPDK_NO_HUGE=1
```

### 5. 板端 IP

GUI 默认远端 IP 是：

```text
192.168.10.3
```

如果板端改过地址，在 GUI 里改 `Remote IP` 即可。

### 6. 可选调试环境变量

ARP 调试：

```bash
export IQ_TAXI_DPDK_TRACE_ARP=1
```

RX overflow 调试：

```bash
export IQ_TAXI_DPDK_LOG_RX_OVERFLOW=1
```

## 构建

常规构建：

```bash
cd host_app/T510_AI_DPDK
./tools/build_release.sh
```

构建产物：

```text
build/t510_ai_gui
```

ASan/UBSan 构建：

```bash
cd host_app/T510_AI_DPDK
./tools/build_asan_gui.sh
```

构建产物：

```text
build_asan/t510_ai_gui
```

## 启动

建议直接用 root 跑，避免 DPDK / mlx5 权限问题：

```bash
cd host_app/T510_AI_DPDK
sudo -E ./build/t510_ai_gui
```

如果你前面设置过环境变量，记得用 `sudo -E` 保留下去。

如果要在 gdb 下运行：

```bash
cd host_app/T510_AI_DPDK
sudo -E ./tools/run_gui_gdb.sh ./build/t510_ai_gui
```

## GUI 使用步骤

### 1. Connect

- 启动 GUI
- 确认 `Remote IP`
- 点击 `Connect`

连接成功后，GUI 会：

- 建立 control path
- 建立 / 恢复 IQ data path
- 为 `IQ_CAPTURE_DST_EPID` 做 route advertise

### 2. 设置参数

当前可以修改：

- `Channel Enable`
- `RX Center Freq`
- `TX Center Freq`
- `RX Gain`
- `TX Gain`
- `Set Time`

当前不可修改：

- `Sample Rate`
  - 固定 `245.76 MHz`

### 3. Capture Once

- 根据 `Capture Size (MB)` 抓一块 IQ
- 写到 `Single Capture Output`
- 更新时域、频谱、瀑布图

适合：

- 看单次采样质量
- 检查连续性
- 做离线分析输入

### 4. Start Stream (4MB Loop)

当前 `Stream` 已不是旧的连续 preview 流。

现在的语义是：

- 循环执行 `4MB capture-once`
- 每轮抓满 4MB 后刷新显示
- 瀑布图按整轮 4MB 数据重建

适合：

- 连续观察频谱/瀑布变化
- 保持比旧 preview 模式更一致的显示语义

### 5. Start Record

`Record` 仍然是连续流录制模式：

- 持续接收 IQ 数据
- 持续写 `Record Output`
- 优先保证录制，不走 `4MB capture-once loop`

### 6. Start Drain Test

`Drain Test` 是数据面排空/吞吐观察模式：

- 启动 IQ data path
- 连续接收数据包
- 不做文件写入
- 不做 GUI 波形/频谱/瀑布更新
- 仍然统计包数、字节数、`seq` / `vita_time` 连续性和 `dpdk_drop_delta`

适合：

- 验证当前链路能否稳定持续收包
- 观察 DPDK RX overflow / continuity warning
- 把“链路是否稳定”与“GUI 解码/绘图开销”分开看

### 7. Stop

- `Stop Stream`
- `Stop Record`
- `Stop Drain Test`

停止后 GUI 会：

- 发送 stop
- 做 quiesce / drain
- 释放 IQ data path

## 当前默认值

程序当前默认使用：

- Sample Rate: `245760000`
- GUI 默认 Remote IP: `192.168.10.3`
- DPDK 默认 Local IP: `192.168.10.10`
- DPDK 默认 PCI BDF: `0000:01:00.0`
- DPDK 默认 Corelist: `1-2`

这些默认值分别来自：

- GUI 模型初始化
- `src/core/dpdk_zero_copy.cpp`

## 相关文档

- [IQ_TRANSPORT_LIFECYCLE.md](IQ_TRANSPORT_LIFECYCLE.md)
- [SOURCE_LAYOUT.md](SOURCE_LAYOUT.md)
- [gui/README.md](gui/README.md)
